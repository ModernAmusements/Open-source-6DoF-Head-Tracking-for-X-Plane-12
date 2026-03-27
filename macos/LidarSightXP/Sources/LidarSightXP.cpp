#include "LidarSightXP.h"
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <iostream>
#include <chrono>

#define DEBUG_LOG(msg) { char _buf[512]; snprintf(_buf, sizeof(_buf), "[LidarSightXP] %s\n", msg); XPLMDebugString(_buf); }

LidarSightXP* gPlugin = nullptr;

static const int UDP_PORT = 4242;
static const int COCKPIT_VIEW_TYPE = 1017;
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
    : mHeadPosX(nullptr)
    , mHeadPosY(nullptr)
    , mHeadPosZ(nullptr)
    , mHeadRoll(nullptr)
    , mViewType(nullptr)
    , mRecenterCommand(0)
    , mMenu(nullptr)
    , mRunning(false)
    , mWriteBuffer(0)
    , mReadBuffer(0)
    , mLastFrameTime(0.0)
    , mIsEnabled(true)
    , mInCockpitView(false)
    , mIsConnected(false)
{
    memset(mPoseBuffers, 0, sizeof(mPoseBuffers));
    memset(&mFilteredPose, 0, sizeof(HeadPosePacket));
    
    mPositionFilter.setParameters(30.0, 0.6, 25.0);
    mRotationFilter.setParameters(30.0, 0.6, 25.0);
}

LidarSightXP::~LidarSightXP()
{
    stop();
}

void LidarSightXP::start()
{
    mRunning = true;
    mLastFrameTime = DEFAULT_DT;
    
    registerDatarefs();
    registerCommands();
    startNetwork();
    
    XPLMRegisterFlightLoopCallback(
        flightLoopCallbackStub,
        -1.0f,
        this
    );
    
    DEBUG_LOG("Plugin started successfully");
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
        plugin->flightLoopCallback();
    }
    return -1.0f;
}

void LidarSightXP::flightLoopCallback()
{
    checkViewType();
    
    if (!mIsEnabled || !mInCockpitView || !mIsConnected) {
        return;
    }
    
    applyOneEuroFilter();
    
    XPLMSetDataf(mHeadPosX, mFilteredPose.x);
    XPLMSetDataf(mHeadPosY, mFilteredPose.y);
    XPLMSetDataf(mHeadPosZ, mFilteredPose.z);
    XPLMSetDataf(mHeadRoll, mFilteredPose.roll);
}

void LidarSightXP::checkViewType()
{
    if (mViewType != nullptr) {
        int viewType = XPLMGetDatai(mViewType);
        mInCockpitView = (viewType == COCKPIT_VIEW_TYPE);
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
    
    double x = pose.x, y = pose.y, z = pose.z;
    double pitch = pose.pitch, yaw = pose.yaw, roll = pose.roll;
    
    mPositionFilter.filter(x, y, z, dt);
    mRotationFilter.filter(pitch, yaw, roll, dt);
    
    mFilteredPose.x = static_cast<float>(x);
    mFilteredPose.y = static_cast<float>(y);
    mFilteredPose.z = static_cast<float>(z);
    mFilteredPose.pitch = static_cast<float>(pitch);
    mFilteredPose.yaw = static_cast<float>(yaw);
    mFilteredPose.roll = static_cast<float>(roll);
    mFilteredPose.flags = pose.flags;
}

void LidarSightXP::recenter()
{
    for (int i = 0; i < BUFFER_COUNT; i++) {
        mPoseBuffers[i].x = 0.0f;
        mPoseBuffers[i].y = 0.0f;
        mPoseBuffers[i].z = 0.0f;
        mPoseBuffers[i].pitch = 0.0f;
        mPoseBuffers[i].yaw = 0.0f;
        mPoseBuffers[i].roll = 0.0f;
    }
    
    mFilteredPose.x = 0.0f;
    mFilteredPose.y = 0.0f;
    mFilteredPose.z = 0.0f;
    mFilteredPose.pitch = 0.0f;
    mFilteredPose.yaw = 0.0f;
    mFilteredPose.roll = 0.0f;
}

void LidarSightXP::registerDatarefs()
{
    mHeadPosX = XPLMFindDataRef("sim/aircraft/view/acf_peX");
    mHeadPosY = XPLMFindDataRef("sim/aircraft/view/acf_peY");
    mHeadPosZ = XPLMFindDataRef("sim/aircraft/view/acf_peZ");
    mHeadRoll = XPLMFindDataRef("sim/graphics/view/pilots_head_phi");
    mViewType = XPLMFindDataRef("sim/graphics/view/view_type");
}

void LidarSightXP::registerCommands()
{
    mMenu = XPLMCreateMenu("LidarSight XP", NULL, 0, menuHandler, this);
    
    XPLMAppendMenuItem(mMenu, "Recenter Head", (void*)1, 0);
    XPLMAppendMenuItem(mMenu, mIsEnabled ? "Disable Tracking" : "Enable Tracking", (void*)2, 0);
}

void LidarSightXP::menuHandler(void* inMenuRef, void* inItemRef)
{
    LidarSightXP* plugin = static_cast<LidarSightXP*>(inMenuRef);
    int item = reinterpret_cast<intptr_t>(inItemRef);
    
    if (item == 1) {
        plugin->recenter();
    } else if (item == 2) {
        plugin->mIsEnabled = !plugin->mIsEnabled;
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
        mIsConnected = true;
        
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
                
                int writeIdx = mWriteBuffer.load();
                mPoseBuffers[writeIdx] = packet;
                
                int nextBuffer = (writeIdx + 1) % BUFFER_COUNT;
                mWriteBuffer.store(nextBuffer);
            }
        }
        
        close(sock);
    });
}

void LidarSightXP::stopNetwork()
{
    if (mNetworkThread.joinable()) {
        mNetworkThread.join();
    }
    mIsConnected = false;
}
