#include "LidarSightXP.h"
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <iostream>
#include <chrono>

LidarSightXP* gPlugin = nullptr;

static const int UDP_PORT = 4242;
static const int COCKPIT_VIEW_TYPE = 1017;
static const double DEFAULT_DT = 1.0 / 60.0;

LidarSightXP::LidarSightXP()
    : mHeadPosX(nullptr)
    , mHeadPosY(nullptr)
    , mHeadPosZ(nullptr)
    , mHeadRoll(nullptr)
    , mViewType(nullptr)
    , mRecenterCommand(nullptr)
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
        this,
        flightLoopCallbackStub,
        -1.0f,
        this
    );
    
    std::cout << "LidarSight XP started" << std::endl;
}

void LidarSightXP::stop()
{
    mRunning = false;
    
    XPLMUnregisterFlightLoopCallback(this, flightLoopCallbackStub, this);
    stopNetwork();
    
    if (mRecenterCommand) {
        XPLMUnregisterCommandHandler(mRecenterCommand, recenterCommandHandler, 0, this);
    }
    
    std::cout << "LidarSight XP stopped" << std::endl;
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
    mRecenterCommand = XPLMCreateCommand("LidarSight/Recenter", "Recenter head tracking");
    XPLMRegisterCommandHandler(
        mRecenterCommand,
        recenterCommandHandler,
        1,
        this
    );
}

void LidarSightXP::recenterCommandHandler(
    XPLMCommandRef inCommand,
    XPLMCommandPhase inPhase,
    void* inRefcon)
{
    if (inPhase == xplm_CommandBegin) {
        LidarSightXP* plugin = static_cast<LidarSightXP*>(inRefcon);
        if (plugin) {
            plugin->recenter();
        }
    }
}

void LidarSightXP::startNetwork()
{
    mNetworkThread = std::thread([this]() {
        int sock = socket(AF_INET, SOCK_DGRAM, 0);
        if (sock < 0) {
            std::cerr << "Failed to create socket" << std::endl;
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
            std::cerr << "Failed to bind socket on port " << UDP_PORT << std::endl;
            close(sock);
            return;
        }
        
        std::cout << "Listening on UDP port " << UDP_PORT << std::endl;
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
