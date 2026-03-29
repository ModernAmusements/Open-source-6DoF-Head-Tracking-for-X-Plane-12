#include "LidarSightXP.h"
#include <cstring>
#include <cmath>
#include <algorithm>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sys/stat.h>

#define DEBUG_LOG(msg) { char _buf[512]; snprintf(_buf, sizeof(_buf), "[LidarSightXP] %s\n", msg); XPLMDebugString(_buf); }

LidarSightXP* gPlugin = nullptr;
static char gConfigPath[512] = {0};

static const int UDP_PORT = 4242;
static const int COCKPIT_VIEW_MIN = 1000;
static const int COCKPIT_VIEW_MAX = 1035;
static const double DEFAULT_DT = 1.0 / 60.0;

PLUGIN_API int XPluginStart(char* outName, char* outSignature, char* outDescription)
{
    strcpy(outName, "LidarSight XP");
    strcpy(outSignature, "com.lidarsight.xp");
    strcpy(outDescription, "6DoF head tracking for X-Plane 12 using iPhone ARKit");
    
    gPlugin = new LidarSightXP();
    gPlugin->start();
    
    return 1;
}

PLUGIN_API void XPluginStop()
{
    if (gPlugin) {
        gPlugin->stop();
        delete gPlugin;
        gPlugin = nullptr;
    }
}

PLUGIN_API int XPluginEnable()
{
    return 1;
}

PLUGIN_API void XPluginDisable()
{
}

PLUGIN_API void XPluginReceiveMessage(XPLMPluginID inFromWho, long inMessage, void* inParam)
{
    if (gPlugin) {
        gPlugin->receiveMessage(inFromWho, inMessage, inParam);
    }
}

LidarSightXP::LidarSightXP()
    : mHeadPitch(nullptr)
    , mHeadYaw(nullptr)
    , mHeadRoll(nullptr)
    , mViewType(nullptr)
    , mMenu(nullptr)
    , mRunning(false)
    , mWriteBuffer(0)
    , mLastFrameTime(0.0)
    , mIsEnabled(true)
    , mInCockpitView(false)
    , mIsConnected(false)
    , mHasInitialPose(false)
{
    memset(mPoseBuffers, 0, sizeof(mPoseBuffers));
    memset(&mFilteredPose, 0, sizeof(HeadPosePacket));
    memset(&mPoseOffset, 0, sizeof(HeadPosePacket));
}

LidarSightXP::~LidarSightXP()
{
    stop();
}

void LidarSightXP::start()
{
    char sysPath[512];
    XPLMGetSystemPath(sysPath);
    snprintf(gConfigPath, sizeof(gConfigPath), "%sLidarSightXP/config.txt", sysPath);
    
    char dirPath[512];
    snprintf(dirPath, sizeof(dirPath), "%sLidarSightXP", sysPath);
    mkdir(dirPath, 0755);
    
    mRunning = true;
    mLastFrameTime = DEFAULT_DT;
    
    loadConfig();
    mRotationFilter.setParameters(mConfig.filterMinCutoff, mConfig.filterBeta, mConfig.filterDCutoff);
    
    registerDatarefs();
    registerCommands();
    startNetwork();
    startFlightData();
    
    XPLMRegisterFlightLoopCallback(
        flightLoopCallbackStub,
        -1.0f,
        this
    );
    
    char buf[256];
    snprintf(buf, sizeof(buf), "Plugin started. Config: yaw_deadzone=%.1f yaw_curve=%.1f pitch_deadzone=%.1f filter=%.1f",
             mConfig.yaw.deadzone, mConfig.yaw.curvePower, mConfig.pitch.deadzone, mConfig.filterMinCutoff);
    DEBUG_LOG(buf);
    
    snprintf(buf, sizeof(buf), "Datarefs: pitch=%p yaw=%p roll=%p view=%p",
             (void*)mHeadPitch, (void*)mHeadYaw, (void*)mHeadRoll, (void*)mViewType);
    DEBUG_LOG(buf);
}

void LidarSightXP::stop()
{
    mRunning = false;
    
    XPLMUnregisterFlightLoopCallback(flightLoopCallbackStub, this);
    stopNetwork();
    
    DEBUG_LOG("Plugin stopped");
}

void LidarSightXP::receiveMessage(XPLMPluginID inFromWho, long inMessage, void* inParam)
{
}

float LidarSightXP::flightLoopCallbackStub(
    float inElapsedTime,
    float inElapsedTimeSinceLastCall,
    int inCounter,
    void* inRefcon)
{
    LidarSightXP* plugin = static_cast<LidarSightXP*>(inRefcon);
    if (plugin) {
        plugin->mLastFrameTime = inElapsedTimeSinceLastCall;
        plugin->flightLoopCallback();
    }
    return -1.0f;
}

void LidarSightXP::flightLoopCallback()
{
    checkViewType();
    
    if (!mIsEnabled || !mInCockpitView) {
        return;
    }
    
    if (!mIsConnected.load()) {
        return;
    }
    
    if (!mHeadPitch || !mHeadYaw || !mHeadRoll) {
        return;
    }
    
    applyOneEuroFilter();
    
    if (!mHasInitialPose) {
        return;
    }
    
    float offsetPitch = mFilteredPose.pitch - mPoseOffset.pitch;
    float offsetYaw = mFilteredPose.yaw - mPoseOffset.yaw;
    float offsetRoll = mFilteredPose.roll - mPoseOffset.roll;
    
    offsetPitch = applyCurve(offsetPitch, mConfig.pitch);
    offsetYaw = applyCurve(offsetYaw, mConfig.yaw);
    offsetRoll = applyCurve(offsetRoll, mConfig.roll);
    
    XPLMSetDataf(mHeadPitch, -offsetPitch);
    XPLMSetDataf(mHeadYaw, offsetYaw);
    XPLMSetDataf(mHeadRoll, offsetRoll);
    
    static int frameCount = 0;
    frameCount++;
    if (frameCount % 60 == 0) {
        char buf[128];
        snprintf(buf, sizeof(buf), "SET: pitch=%.1f yaw=%.1f roll=%.1f", 
                 -offsetPitch, offsetYaw, offsetRoll);
        DEBUG_LOG(buf);
    }
}

void LidarSightXP::checkViewType()
{
    if (mViewType != nullptr) {
        int viewType = XPLMGetDatai(mViewType);
        mInCockpitView = (viewType >= COCKPIT_VIEW_MIN && viewType <= COCKPIT_VIEW_MAX);
        
        static int lastViewType = -1;
        if (viewType != lastViewType) {
            char buf[64];
            snprintf(buf, sizeof(buf), "View type: %d (cockpit=%d)", viewType, mInCockpitView);
            DEBUG_LOG(buf);
            lastViewType = viewType;
        }
    }
}

void LidarSightXP::applyOneEuroFilter()
{
    int writeIdx = mWriteBuffer.load();
    HeadPosePacket& pose = mPoseBuffers[writeIdx];
    
    if ((pose.flags & 0x02) == 0) {
        return;
    }
    
    double dt = mLastFrameTime;
    if (dt <= 0.0 || dt > 0.1) {
        dt = DEFAULT_DT;
    }
    
    double pitch = pose.pitch, yaw = pose.yaw, roll = pose.roll;
    
    auto isValid = [](double v) { return std::isfinite(v) && std::abs(v) < 10000.0; };
    if (!isValid(pitch) || !isValid(yaw) || !isValid(roll)) {
        return;
    }
    
    mRotationFilter.filter(pitch, yaw, roll, dt);
    
    mFilteredPose.pitch = static_cast<float>(pitch);
    mFilteredPose.yaw = static_cast<float>(yaw);
    mFilteredPose.roll = static_cast<float>(roll);
    mFilteredPose.flags = pose.flags;
    
    if (!mHasInitialPose) {
        mHasInitialPose = true;
        mPoseOffset = mFilteredPose;
        DEBUG_LOG("Auto-zeroed on first pose");
    }
}

void LidarSightXP::recenter()
{
    mHasInitialPose = true;
    mPoseOffset.pitch = mFilteredPose.pitch;
    mPoseOffset.yaw = mFilteredPose.yaw;
    mPoseOffset.roll = mFilteredPose.roll;
    mRotationFilter.setParameters(mConfig.filterMinCutoff, mConfig.filterBeta, mConfig.filterDCutoff);
}

float LidarSightXP::applyCurve(float value, const AxisConfig& config)
{
    if (!config.enabled || std::abs(value) < config.deadzone) {
        return 0.0f;
    }
    
    float sign = (value > 0) ? 1.0f : -1.0f;
    float absVal = std::abs(value);
    
    float effectiveMaxInput = std::max(config.maxInput, config.deadzone + 0.1f);
    float t = (absVal - config.deadzone) / (effectiveMaxInput - config.deadzone);
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;
    
    float curvePower = config.curvePower;
    if (curvePower < 0.1f) curvePower = 0.1f;
    
    float tPowered = t;
    for (int i = 1; i < (int)(curvePower * 10); i++) {
        tPowered *= t;
    }
    
    float curved = config.deadzone + (config.maxOutput - config.deadzone) * tPowered;
    
    return sign * curved * (config.invert ? -1.0f : 1.0f);
}

void LidarSightXP::loadConfig()
{
    if (gConfigPath[0] == 0) {
        DEBUG_LOG("Config path not initialized");
        return;
    }
    
    FILE* f = fopen(gConfigPath, "r");
    if (!f) {
        DEBUG_LOG("No config file, using defaults");
        return;
    }
    
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        char key[64];
        float value;
        if (sscanf(line, "%63[^=]=%f", key, &value) == 2) {
            if (strcmp(key, "yaw.deadzone") == 0) mConfig.yaw.deadzone = value;
            else if (strcmp(key, "yaw.maxInput") == 0) mConfig.yaw.maxInput = value;
            else if (strcmp(key, "yaw.maxOutput") == 0) mConfig.yaw.maxOutput = value;
            else if (strcmp(key, "yaw.curvePower") == 0) mConfig.yaw.curvePower = value;
            else if (strcmp(key, "yaw.enabled") == 0) mConfig.yaw.enabled = (value != 0);
            else if (strcmp(key, "yaw.invert") == 0) mConfig.yaw.invert = (value != 0);
            else if (strcmp(key, "pitch.deadzone") == 0) mConfig.pitch.deadzone = value;
            else if (strcmp(key, "pitch.maxInput") == 0) mConfig.pitch.maxInput = value;
            else if (strcmp(key, "pitch.maxOutput") == 0) mConfig.pitch.maxOutput = value;
            else if (strcmp(key, "pitch.curvePower") == 0) mConfig.pitch.curvePower = value;
            else if (strcmp(key, "pitch.enabled") == 0) mConfig.pitch.enabled = (value != 0);
            else if (strcmp(key, "pitch.invert") == 0) mConfig.pitch.invert = (value != 0);
            else if (strcmp(key, "roll.deadzone") == 0) mConfig.roll.deadzone = value;
            else if (strcmp(key, "roll.maxInput") == 0) mConfig.roll.maxInput = value;
            else if (strcmp(key, "roll.maxOutput") == 0) mConfig.roll.maxOutput = value;
            else if (strcmp(key, "roll.curvePower") == 0) mConfig.roll.curvePower = value;
            else if (strcmp(key, "roll.enabled") == 0) mConfig.roll.enabled = (value != 0);
            else if (strcmp(key, "roll.invert") == 0) mConfig.roll.invert = (value != 0);
            else if (strcmp(key, "filter.minCutoff") == 0) mConfig.filterMinCutoff = value;
            else if (strcmp(key, "filter.beta") == 0) mConfig.filterBeta = value;
            else if (strcmp(key, "filter.dCutoff") == 0) mConfig.filterDCutoff = value;
        }
    }
    
    fclose(f);
    DEBUG_LOG("Config loaded");
}

void LidarSightXP::saveConfig()
{
    if (gConfigPath[0] == 0) {
        DEBUG_LOG("Config path not initialized");
        return;
    }
    
    FILE* f = fopen(gConfigPath, "w");
    if (!f) {
        DEBUG_LOG("Failed to save config");
        return;
    }
    
    fprintf(f, "yaw.deadzone=%f\n", mConfig.yaw.deadzone);
    fprintf(f, "yaw.maxInput=%f\n", mConfig.yaw.maxInput);
    fprintf(f, "yaw.maxOutput=%f\n", mConfig.yaw.maxOutput);
    fprintf(f, "yaw.curvePower=%f\n", mConfig.yaw.curvePower);
    fprintf(f, "yaw.enabled=%d\n", mConfig.yaw.enabled);
    fprintf(f, "yaw.invert=%d\n", mConfig.yaw.invert);
    
    fprintf(f, "pitch.deadzone=%f\n", mConfig.pitch.deadzone);
    fprintf(f, "pitch.maxInput=%f\n", mConfig.pitch.maxInput);
    fprintf(f, "pitch.maxOutput=%f\n", mConfig.pitch.maxOutput);
    fprintf(f, "pitch.curvePower=%f\n", mConfig.pitch.curvePower);
    fprintf(f, "pitch.enabled=%d\n", mConfig.pitch.enabled);
    fprintf(f, "pitch.invert=%d\n", mConfig.pitch.invert);
    
    fprintf(f, "roll.deadzone=%f\n", mConfig.roll.deadzone);
    fprintf(f, "roll.maxInput=%f\n", mConfig.roll.maxInput);
    fprintf(f, "roll.maxOutput=%f\n", mConfig.roll.maxOutput);
    fprintf(f, "roll.curvePower=%f\n", mConfig.roll.curvePower);
    fprintf(f, "roll.enabled=%d\n", mConfig.roll.enabled);
    fprintf(f, "roll.invert=%d\n", mConfig.roll.invert);
    
    fprintf(f, "filter.minCutoff=%f\n", mConfig.filterMinCutoff);
    fprintf(f, "filter.beta=%f\n", mConfig.filterBeta);
    fprintf(f, "filter.dCutoff=%f\n", mConfig.filterDCutoff);
    
    fclose(f);
    DEBUG_LOG("Config saved");
}

void LidarSightXP::registerDatarefs()
{
    mHeadPitch = XPLMFindDataRef("sim/graphics/view/pilots_head_the");
    mHeadYaw = XPLMFindDataRef("sim/graphics/view/pilots_head_psi");
    mHeadRoll = XPLMFindDataRef("sim/graphics/view/pilots_head_phi");
    mViewType = XPLMFindDataRef("sim/graphics/view/view_type");
    
    mAirspeed = XPLMFindDataRef("sim/flightmodel/position/indicated_airspeed");
    mAltitude = XPLMFindDataRef("sim/flightmodel/position/elevation");
    mHeading = XPLMFindDataRef("sim/flightmodel/position/psi");
    mPitch = XPLMFindDataRef("sim/flightmodel/position/theta");
    mRoll = XPLMFindDataRef("sim/flightmodel/position/phi");
    mVerticalSpeed = XPLMFindDataRef("sim/flightmodel/position/vsi");
}

void LidarSightXP::registerCommands()
{
    mMenu = XPLMCreateMenu("LidarSight XP", NULL, 0, menuHandler, this);
    
    XPLMAppendMenuItem(mMenu, "Recenter Head (R)", (void*)1, 0);
    XPLMAppendMenuItem(mMenu, mIsEnabled ? "Disable Tracking (T)" : "Enable Tracking (T)", (void*)2, 0);
    
    XPLMMenuID yawMenu = XPLMCreateMenu("Yaw Settings", mMenu, 0, menuHandler, this);
    XPLMAppendMenuItem(yawMenu, mConfig.yaw.enabled ? "Disable Yaw" : "Enable Yaw", (void*)10, 0);
    XPLMAppendMenuItem(yawMenu, mConfig.yaw.invert ? "Un-Invert Yaw" : "Invert Yaw", (void*)11, 0);
    XPLMAppendMenuItem(yawMenu, "Yaw: Increase Deadzone (+)", (void*)12, 0);
    XPLMAppendMenuItem(yawMenu, "Yaw: Decrease Deadzone (-)", (void*)13, 0);
    XPLMAppendMenuItem(yawMenu, "Yaw: More Curve (*)   (less linear)", (void*)14, 0);
    XPLMAppendMenuItem(yawMenu, "Yaw: Less Curve (/)  (more linear)", (void*)15, 0);
    XPLMAppendMenuItem(yawMenu, "Yaw: More Range (])", (void*)16, 0);
    XPLMAppendMenuItem(yawMenu, "Yaw: Less Range ([)", (void*)17, 0);
    
    XPLMMenuID pitchMenu = XPLMCreateMenu("Pitch Settings", mMenu, 0, menuHandler, this);
    XPLMAppendMenuItem(pitchMenu, mConfig.pitch.enabled ? "Disable Pitch" : "Enable Pitch", (void*)20, 0);
    XPLMAppendMenuItem(pitchMenu, mConfig.pitch.invert ? "Un-Invert Pitch" : "Invert Pitch", (void*)21, 0);
    XPLMAppendMenuItem(pitchMenu, "Pitch: Increase Deadzone (Shift+=)", (void*)22, 0);
    XPLMAppendMenuItem(pitchMenu, "Pitch: Decrease Deadzone (Shift+-)", (void*)23, 0);
    
    XPLMMenuID filterMenu = XPLMCreateMenu("Filter Settings", mMenu, 0, menuHandler, this);
    XPLMAppendMenuItem(filterMenu, "Smoother (]", (void*)30, 0);
    XPLMAppendMenuItem(filterMenu, "More Responsive ([)", (void*)31, 0);
    
    XPLMAppendMenuItem(mMenu, "Load Config (L)", (void*)40, 0);
    XPLMAppendMenuItem(mMenu, "Save Config (S)", (void*)41, 0);
    XPLMAppendMenuItem(mMenu, "Reset to Defaults", (void*)42, 0);
}

void LidarSightXP::menuHandler(void* inMenuRef, void* inItemRef)
{
    LidarSightXP* plugin = static_cast<LidarSightXP*>(inMenuRef);
    int item = reinterpret_cast<intptr_t>(inItemRef);
    
    if (item == 1) {
        plugin->recenter();
    } else if (item == 2) {
        plugin->mIsEnabled = !plugin->mIsEnabled;
    } else if (item == 10) {
        plugin->mConfig.yaw.enabled = !plugin->mConfig.yaw.enabled;
    } else if (item == 11) {
        plugin->mConfig.yaw.invert = !plugin->mConfig.yaw.invert;
    } else if (item == 12) {
        plugin->mConfig.yaw.deadzone = std::min(plugin->mConfig.yaw.deadzone + 1.0f, 10.0f);
    } else if (item == 13) {
        plugin->mConfig.yaw.deadzone = std::max(plugin->mConfig.yaw.deadzone - 1.0f, 0.0f);
    } else if (item == 14) {
        plugin->mConfig.yaw.curvePower = std::min(plugin->mConfig.yaw.curvePower + 0.2f, 4.0f);
    } else if (item == 15) {
        plugin->mConfig.yaw.curvePower = std::max(plugin->mConfig.yaw.curvePower - 0.2f, 0.5f);
    } else if (item == 16) {
        plugin->mConfig.yaw.maxOutput = std::min(plugin->mConfig.yaw.maxOutput + 10.0f, 180.0f);
    } else if (item == 17) {
        plugin->mConfig.yaw.maxOutput = std::max(plugin->mConfig.yaw.maxOutput - 10.0f, 30.0f);
    } else if (item == 20) {
        plugin->mConfig.pitch.enabled = !plugin->mConfig.pitch.enabled;
    } else if (item == 21) {
        plugin->mConfig.pitch.invert = !plugin->mConfig.pitch.invert;
    } else if (item == 22) {
        plugin->mConfig.pitch.deadzone = std::min(plugin->mConfig.pitch.deadzone + 1.0f, 15.0f);
    } else if (item == 23) {
        plugin->mConfig.pitch.deadzone = std::max(plugin->mConfig.pitch.deadzone - 1.0f, 0.0f);
    } else if (item == 30) {
        plugin->mConfig.filterMinCutoff = std::max(plugin->mConfig.filterMinCutoff - 0.2f, 0.1f);
        plugin->mRotationFilter.setParameters(plugin->mConfig.filterMinCutoff, plugin->mConfig.filterBeta, plugin->mConfig.filterDCutoff);
    } else if (item == 31) {
        plugin->mConfig.filterMinCutoff = std::min(plugin->mConfig.filterMinCutoff + 0.2f, 10.0f);
        plugin->mRotationFilter.setParameters(plugin->mConfig.filterMinCutoff, plugin->mConfig.filterBeta, plugin->mConfig.filterDCutoff);
    } else if (item == 40) {
        plugin->loadConfig();
        plugin->mRotationFilter.setParameters(plugin->mConfig.filterMinCutoff, plugin->mConfig.filterBeta, plugin->mConfig.filterDCutoff);
    } else if (item == 41) {
        plugin->saveConfig();
    } else if (item == 42) {
        plugin->mConfig = TrackingConfig();
        plugin->mRotationFilter.setParameters(plugin->mConfig.filterMinCutoff, plugin->mConfig.filterBeta, plugin->mConfig.filterDCutoff);
    }
}

void LidarSightXP::startNetwork()
{
    mNetworkThread = std::thread([this]() {
        int sock = socket(AF_INET, SOCK_DGRAM, 0);
        if (sock < 0) {
            DEBUG_LOG("Failed to create socket");
            return;
        }
        
        int reuse = 1;
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
        
        // Allow broadcast
        int broadcast = 1;
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));
        
        sockaddr_in serverAddr;
        memset(&serverAddr, 0, sizeof(serverAddr));
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        serverAddr.sin_port = htons(UDP_PORT);
        
        if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) < 0) {
            DEBUG_LOG("Failed to bind socket");
            close(sock);
            return;
        }
        
        DEBUG_LOG("Listening on UDP port 4242");
        mIsConnected.store(true);
        
        char buffer[1024];
        sockaddr_in clientAddr;
        socklen_t clientLen = sizeof(clientAddr);
        
        while (mRunning) {
            fd_set readfds;
            FD_ZERO(&readfds);
            FD_SET(sock, &readfds);
            
            timeval timeout;
            timeout.tv_sec = 0;
            timeout.tv_usec = 50000;
            
            int ready = select(sock + 1, &readfds, nullptr, nullptr, &timeout);
            if (ready < 0) break;
            if (ready == 0) continue;
            
            ssize_t n = recvfrom(sock, buffer, sizeof(buffer), 0, 
                                 (sockaddr*)&clientAddr, &clientLen);
            
            if (n == PACKET_SIZE) {
                HeadPosePacket packet;
                memcpy(&packet, buffer, PACKET_SIZE);
                
                static int packetCount = 0;
                packetCount++;
                if (packetCount % 60 == 0) {
                    char buf[128];
                    snprintf(buf, sizeof(buf), "RX: LidarSight pkt=%u p=%.1f y=%.1f r=%.1f", 
                             packet.packet_id, packet.pitch, packet.yaw, packet.roll);
                    DEBUG_LOG(buf);
                }
                
                int writeIdx = mWriteBuffer.load();
                mPoseBuffers[writeIdx] = packet;
                
                int nextBuffer = (writeIdx + 1) % BUFFER_COUNT;
                mWriteBuffer.store(nextBuffer);
            }
            else if (n == OPENTRACK_PACKET_SIZE) {
                OpenTrackPacket otPacket;
                memcpy(&otPacket, buffer, OPENTRACK_PACKET_SIZE);
                
                HeadPosePacket packet;
                packet.packet_id = 0;
                packet.flags = 0x02;
                packet.timestamp_us = 0;
                packet.x = static_cast<float>(otPacket.x);
                packet.y = static_cast<float>(otPacket.y);
                packet.z = static_cast<float>(otPacket.z);
                packet.pitch = static_cast<float>(otPacket.pitch * 180.0 / M_PI);
                packet.yaw = static_cast<float>(otPacket.yaw * 180.0 / M_PI);
                packet.roll = static_cast<float>(otPacket.roll * 180.0 / M_PI);
                
                static int packetCount = 0;
                packetCount++;
                if (packetCount % 60 == 0) {
                    char buf[128];
                    snprintf(buf, sizeof(buf), "RX: OpenTrack p=%.1f y=%.1f r=%.1f", 
                             packet.pitch, packet.yaw, packet.roll);
                    DEBUG_LOG(buf);
                }
                
                int writeIdx = mWriteBuffer.load();
                mPoseBuffers[writeIdx] = packet;
                
                int nextBuffer = (writeIdx + 1) % BUFFER_COUNT;
                mWriteBuffer.store(nextBuffer);
            }
        }
        
        DEBUG_LOG("Network thread exiting");
        mIsConnected.store(false);
        
        close(sock);
    });
}

void LidarSightXP::stopNetwork()
{
    if (mNetworkThread.joinable()) {
        mNetworkThread.join();
    }
    mIsConnected.store(false);
}

void LidarSightXP::startFlightData()
{
    mFlightDataSock = socket(AF_INET, SOCK_DGRAM, 0);
    if (mFlightDataSock < 0) {
        DEBUG_LOG("Failed to create flight data socket");
        return;
    }
    
    int broadcast = 1;
    setsockopt(mFlightDataSock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));
    
    mFlightDataThread = std::thread([this]() {
        while (mRunning) {
            sendFlightData();
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        
        if (mFlightDataSock >= 0) {
            close(mFlightDataSock);
            mFlightDataSock = -1;
        }
        
        DEBUG_LOG("Flight data thread exiting");
    });
    
    DEBUG_LOG("Flight data thread started");
}

void LidarSightXP::sendFlightData()
{
    if (mFlightDataSock < 0) return;
    
    FlightDataPacket packet;
    memset(&packet, 0, sizeof(packet));
    memcpy(packet.header, "DATA", 4);
    
    auto readValid = [](XPLMDataRef ref, double fallback) -> double {
        if (!ref) return fallback;
        float val = XPLMGetDataf(ref);
        if (!std::isfinite(val)) return fallback;
        return val;
    };
    
    packet.airspeed = readValid(mAirspeed, 0.0);
    packet.altitude = readValid(mAltitude, 0.0) * 3.28084;
    packet.heading = readValid(mHeading, 0.0);
    packet.pitch = readValid(mPitch, 0.0);
    packet.roll = readValid(mRoll, 0.0);
    packet.verticalSpeed = readValid(mVerticalSpeed, 0.0) * 196.85;
    
    sockaddr_in destAddr;
    memset(&destAddr, 0, sizeof(destAddr));
    destAddr.sin_family = AF_INET;
    destAddr.sin_port = htons(49000);
    destAddr.sin_addr.s_addr = htonl(INADDR_BROADCAST);
    
    sendto(mFlightDataSock, &packet, sizeof(packet), 0, 
           (sockaddr*)&destAddr, sizeof(destAddr));
}
