#ifndef LidarSightXP_h
#define LidarSightXP_h

#include "XPLMPlugin.h"
#include "XPLMDataAccess.h"
#include "XPLMProcessing.h"
#include "XPLMMenus.h"
#include "XPLMDisplay.h"
#include "XPLMUtilities.h"
#include <atomic>
#include <thread>
#include <mutex>
#include <cmath>
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

struct AxisConfig {
    float deadzone;
    float maxInput;
    float maxOutput;
    float curvePower;
    bool enabled;
    bool invert;
    
    AxisConfig() : deadzone(2.0f), maxInput(30.0f), maxOutput(90.0f), 
                   curvePower(2.0f), enabled(true), invert(false) {}
};

struct TrackingConfig {
    AxisConfig yaw;
    AxisConfig pitch;
    AxisConfig roll;
    float filterMinCutoff;
    float filterBeta;
    float filterDCutoff;
    
    TrackingConfig() 
        : filterMinCutoff(1.0f), filterBeta(0.1f), filterDCutoff(1.0f) 
    {
        yaw.deadzone = 2.0f;
        yaw.maxInput = 30.0f;
        yaw.maxOutput = 90.0f;
        yaw.curvePower = 2.0f;
        yaw.enabled = true;
        yaw.invert = false;
        
        pitch.deadzone = 3.0f;
        pitch.maxInput = 20.0f;
        pitch.maxOutput = 25.0f;
        pitch.curvePower = 1.5f;
        pitch.enabled = true;
        pitch.invert = false;
        
        roll.deadzone = 0.0f;
        roll.maxInput = 15.0f;
        roll.maxOutput = 15.0f;
        roll.curvePower = 1.0f;
        roll.enabled = false;
        roll.invert = false;
    }
};

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
    
    void loadConfig();
    void saveConfig();
    float applyCurve(float value, const AxisConfig& config);
    
    static void menuHandler(void* inMenuRef, void* inItemRef);
    
    XPLMDataRef mHeadPitch;
    XPLMDataRef mHeadYaw;
    XPLMDataRef mHeadRoll;
    XPLMDataRef mViewType;
    
    XPLMMenuID mMenu;
    
    std::atomic<bool> mRunning;
    std::thread mNetworkThread;
    
    static constexpr int BUFFER_COUNT = 3;
    HeadPosePacket mPoseBuffers[BUFFER_COUNT];
    std::atomic<int> mWriteBuffer;
    HeadPosePacket mFilteredPose;
    HeadPosePacket mPoseOffset;
    
    OneEuroFilterVector3 mRotationFilter;
    TrackingConfig mConfig;
    
    double mLastFrameTime;
    
    bool mIsEnabled;
    bool mInCockpitView;
    std::atomic<bool> mIsConnected;
    bool mHasInitialPose;
};

extern LidarSightXP* gPlugin;

#endif
