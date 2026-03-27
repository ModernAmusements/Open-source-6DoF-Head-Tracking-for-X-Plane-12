#ifndef LidarSightXP_h
#define LidarSightXP_h

#include "XPLMPlugin.h"
#include "XPLMDataAccess.h"
#include "XPLMProcessing.h"
#include "XPLMMenus.h"
#include <atomic>
#include <thread>
#include <mutex>
#include "Processing/OneEuroFilter.h"

#pragma pack(push, 1)
#define PACKET_SIZE 33

struct HeadPosePacket {
    uint32_t packet_id;
    uint8_t  flags;
    float    timestamp_us;
    float    x, y, z;
    float    pitch, yaw, roll;
};

#define OPENTRACK_PACKET_SIZE 48

struct OpenTrackPacket {
    double x, y, z;
    double pitch, yaw, roll;
};
#pragma pack(pop)

class LidarSightXP {
public:
    LidarSightXP();
    ~LidarSightXP();
    
    void start();
    void stop();
    void receiveMessage(XPLMPluginID inFromWho, long inMessage, void* inParam);
    
private:
    void flightLoopCallback();
    static float flightLoopCallbackStub(float inElapsedTime, float inElapsedTimeSinceLastCall, 
                                        int inCounter, void* inRefcon);
    
    void registerDatarefs();
    void registerCommands();
    void startNetwork();
    void stopNetwork();
    
    void checkViewType();
    void applyOneEuroFilter();
    void recenter();
    
    static void recenterCommandHandler(void* inRefcon);
    
    XPLMDataRef mHeadPosX;
    XPLMDataRef mHeadPosY;
    XPLMDataRef mHeadPosZ;
    XPLMDataRef mHeadRoll;
    XPLMDataRef mViewType;
    
    int mRecenterCommand;
    XPLMMenuID mMenu;
    
    std::atomic<bool> mRunning;
    std::thread mNetworkThread;
    std::mutex mPoseMutex;
    
    static constexpr int BUFFER_COUNT = 3;
    HeadPosePacket mPoseBuffers[BUFFER_COUNT];
    std::atomic<int> mWriteBuffer;
    std::atomic<int> mReadBuffer;
    HeadPosePacket mFilteredPose;
    
    OneEuroFilterVector3 mPositionFilter;
    OneEuroFilterVector3 mRotationFilter;
    
    double mLastFrameTime;
    
    bool mIsEnabled;
    bool mInCockpitView;
    bool mIsConnected;
};

extern LidarSightXP* gPlugin;

#endif
