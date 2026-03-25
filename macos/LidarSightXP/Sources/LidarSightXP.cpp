#include "LidarSightXP.h"
#include "OneEuroFilter.h"
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <iostream>

LidarSightXP* gPlugin = nullptr;

static const int UDP_PORT = 4242;
static const int COCKPIT_VIEW_TYPE = 1017;

LidarSightXP::LidarSightXP()
    : mHeadPosX(nullptr)
    , mHeadPosY(nullptr)
    , mHeadPosZ(nullptr)
    , mHeadRoll(nullptr)
    , mViewType(nullptr)
    , mRecenterCommand(nullptr)
    , mMenu(nullptr)
    , mRunning(false)
    , mIsEnabled(true)
    , mInCockpitView(false)
    , mIsConnected(false)
{
    memset(&mCurrentPose, 0, sizeof(HeadPosePacket));
    memset(&mFilteredPose, 0, sizeof(HeadPosePacket));
}

LidarSightXP::~LidarSightXP()
{
    stop();
}

void LidarSightXP::start()
{
    mRunning = true;
    
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
    if (!mIsEnabled || !mInCockpitView || !mIsConnected) {
        return;
    }
    
    {
        std::lock_guard<std::mutex> lock(mPoseMutex);
        mFilteredPose = mCurrentPose;
    }
    
    XPLMSetDataf(mHeadPosX, mFilteredPose.x);
    XPLMSetDataf(mHeadPosY, mFilteredPose.y);
    XPLMSetDataf(mHeadPosZ, mFilteredPose.z);
    XPLMSetDataf(mHeadRoll, mFilteredPose.roll);
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
            std::lock_guard<std::mutex> lock(plugin->mPoseMutex);
            plugin->mCurrentPose.x = 0.0f;
            plugin->mCurrentPose.y = 0.0f;
            plugin->mCurrentPose.z = 0.0f;
            plugin->mCurrentPose.pitch = 0.0f;
            plugin->mCurrentPose.yaw = 0.0f;
            plugin->mCurrentPose.roll = 0.0f;
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
        
        sockaddr_in serverAddr;
        memset(&serverAddr, 0, sizeof(serverAddr));
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        serverAddr.sin_port = htons(UDP_PORT);
        
        if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) < 0) {
            std::cerr << "Failed to bind socket" << std::endl;
            close(sock);
            return;
        }
        
        std::cout << "Listening on port " << UDP_PORT << std::endl;
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
            timeout.tv_usec = 100000;
            
            int ready = select(sock + 1, &readfds, nullptr, nullptr, &timeout);
            if (ready < 0) break;
            if (ready == 0) continue;
            
            ssize_t n = recvfrom(sock, buffer, sizeof(buffer), 0, 
                                 (sockaddr*)&clientAddr, &clientLen);
            
            if (n == PACKET_SIZE) {
                HeadPosePacket packet;
                memcpy(&packet, buffer, PACKET_SIZE);
                
                {
                    std::lock_guard<std::mutex> lock(mPoseMutex);
                    mCurrentPose = packet;
                }
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
