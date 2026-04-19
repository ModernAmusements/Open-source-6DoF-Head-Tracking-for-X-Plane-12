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
#define FLIGHT_DATA_SIZE 36

struct HeadPosePacket {
    uint32_t packet_id;
    uint8_t  flags;
    float    timestamp_us;
    float    x, y, z;
    float    pitch, yaw, roll;
};

#define FLAG_CALIBRATED    0x01
#define FLAG_TRACKING_VALID 0x02
#define FLAG_RECENTER      0x04

struct FlightDataPacket {
    char     header[4];
    double   airspeed;
    double   altitude;
    double   heading;
    double   pitch;
    double   roll;
    double   verticalSpeed;
};
#pragma pack(pop)

#define OPENTRACK_PACKET_SIZE 48

#pragma pack(push, 1)
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
    
    AxisConfig() : deadzone(0.5f), maxInput(90.0f), maxOutput(90.0f), 
                   curvePower(1.0f), enabled(true), invert(false) {}
    
    void reset() {
        deadzone = 0.0f;
        maxInput = 90.0f;
        maxOutput = 90.0f;
        curvePower = 1.0f;
        enabled = true;
        invert = false;
    }
};

struct TrackingConfig {
    AxisConfig yaw;
    AxisConfig pitch;
    AxisConfig roll;
    float filterMinCutoff;
    float filterBeta;
    float filterDCutoff;
    
    TrackingConfig() 
        : filterMinCutoff(0.5f), filterBeta(0.7f), filterDCutoff(1.0f) 
    {
        yaw.deadzone = 0.2f;
        yaw.maxInput = 45.0f;
        yaw.maxOutput = 120.0f;
        yaw.curvePower = 1.0f;
        yaw.enabled = true;
        yaw.invert = false;
        
        pitch.deadzone = 0.2f;
        pitch.maxInput = 45.0f;
        pitch.maxOutput = 120.0f;
        pitch.curvePower = 1.0f;
        pitch.enabled = true;
        pitch.invert = false;
        
        roll.deadzone = 0.2f;
        roll.maxInput = 45.0f;
        roll.maxOutput = 60.0f;
        roll.curvePower = 1.0f;
        roll.enabled = true;
        roll.invert = true;
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
    void startUdpListener();
    void stopUdpListener();
    void startFlightData();
    void stopFlightData();
    
    void checkViewType();
    void applyOneEuroFilter();
    void recenter();
    
    void loadConfig();
    void saveConfig();
    float applyCurve(float value, const AxisConfig& config);
    
    static void menuHandler(void* inMenuRef, void* inItemRef);
    
    void sendFlightData();
    
    XPLMDataRef mHeadPitch;
    XPLMDataRef mHeadYaw;
    XPLMDataRef mHeadRoll;
    XPLMDataRef mViewType;
    
    XPLMDataRef mAirspeed;
    XPLMDataRef mAltitude;
    XPLMDataRef mHeading;
    XPLMDataRef mPitch;
    XPLMDataRef mRoll;
    XPLMDataRef mVerticalSpeed;
    
    XPLMMenuID mMenu;
    
    std::atomic<bool> mRunning;
    std::thread mNetworkThread;
    std::thread mUdpThread;
    std::thread mFlightDataThread;
    int mFlightDataSock;
    int mUdpForwardSock;
    int mUdpListenSock;
    
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
