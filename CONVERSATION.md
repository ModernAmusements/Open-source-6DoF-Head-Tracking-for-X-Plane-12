# LidarSight XP - Development Conversation Log

## Session Summary

This document captures the key decisions, discussions, and development progress made during the creation of LidarSight XP.

---

## March 25, 2026 - Session 1: Initial Planning

### Context Review
- User provided initial spec in `context.md`
- Goal: 6DoF head-tracking for X-Plane 12 using iPhone

### Key Findings from Research

1. **ARKit Configuration**
   - For vertical webcam-style mount: `ARFaceTrackingConfiguration` (front camera) is CORRECT
   - No LiDAR needed - front camera tracks user's face directly
   - This is how apps like SmoothTrack work

2. **Transport Layer Decision**
   - Primary: PeerTalk (USB via usbmuxd) - MIT license, ~5ms latency
   - Fallback: WiFi UDP on port 4242

3. **X-Plane Integration**
   - Recommended: Direct dataref writes (NOT camera override)
   - Datarefs: `sim/aircraft/view/acf_peX/Y/Z`, `pilots_head_phi`

4. **One Euro Filter Parameters** (from Monado VR runtime)
   - `fc_min = 30.0 Hz`
   - `beta = 0.6`
   - `d_cutoff = 25.0 Hz`

### Data Packet Structure
```c
struct HeadPosePacket {
    uint32_t packet_id;
    uint8_t  flags;
    double   timestamp_us;
    float    x, y, z;
    float    pitch, yaw, roll;
};
// Size: 24 bytes (initial)
```

### 10 Potential Traps Identified
1. Gimbal Lock → use quaternions
2. Thread Safety → triple-buffer atomic swap
3. Packet Loss → interpolation + sequence IDs

---

## March 25, 2026 - Session 2: Architecture Decision

### Primary Issue
How should iOS send data to Mac?

### Options Analysis

| Option | Latency | Reliability | Complexity | License |
|--------|---------|-------------|------------|---------|
| UDP Broadcast | ~5ms | Low (packet loss) | Low | N/A |
| TCP Socket | ~10ms | High | Low | N/A |
| PeerTalk (usbmuxd) | ~3ms | Very High | Medium | MIT |
| MultipeerConnectivity | ~5ms | High | Medium | Apple |

### Decision
**TCP Socket** for initial development (easiest to debug)
**PeerTalk** for production (USB, lowest latency)

### Packet Format Change
33 bytes (not 24):
- 4 bytes: packet_id (UInt32, big endian)
- 1 byte:  flags
- 4 bytes: timestamp_us (Float32)
- 12 bytes: x, y, z (Float32)
- 12 bytes: pitch, yaw, roll (Float32)

---

## March 26, 2026 - Session 3: X-Plane Plugin Architecture

### Plugin Structure Decision
- Use C++ for X-Plane plugin (required by XPL API)
- Use C++ wrapper around Objective-C for networking
- OR: Use pure C++ with Boost ASIO for networking

### Recommended Approach
Pure C++ with custom UDP server:
- Simpler threading model
- No Objective-C runtime dependencies
- Easier to debug

### Dataref List
```
Pitch (look up/down):    sim/aircraft/view/acf_poX (r/w) - degrees
Yaw (look left/right):   sim/aircraft/view/acf_poY (r/w) - degrees
Roll (tilt head):        sim/aircraft/view/acf_poZ (r/w) - degrees
Position (X):            sim/aircraft/view/acf_peX (r/w) - meters
Position (Y):           sim/aircraft/view/acf_peY (r/w) - meters  
Position (Z):            sim/aircraft/view/acf_peZ (r/w) - meters
```

### Initial Values
- Sensitivity: 1.0
- Smoothing: 0.85
- Max Angle: 45°

---

## March 26, 2026 - Session 4: iOS App Structure

### SwiftUI + UIKit Hybrid Approach

**Decision:** Use SwiftUI with ARKit wrapped in UIViewRepresentable

### File Structure
```
LidarSightXP/
├── Sources/
│   ├── App/
│   │   └── LidarSightXPApp.swift
│   ├── AR/
│   │   └── ARTrackingManager.swift
│   ├── Transport/
│   │   ├── TCPClient.swift
│   │   └── PeerTalkClient.swift
│   ├── Models/
│   │   ├── HeadPose.swift
│   │   ├── HeadPosePacket.swift
│   │   └── CalibrationManager.swift
│   └── Views/
│       ├── ContentView.swift
│       ├── ARSceneView.swift
│       └── SettingsView.swift
```

### Key Classes
- `ARTrackingManager`: Handles ARKit session, face anchor processing
- `TCPClient`: Sends packets to Mac over TCP
- `CalibrationManager`: Handles zero-point calibration

---

## March 27, 2026 - Session 5: Calibration Logic

### Calibration Strategy

**Problem:** ARKit returns absolute head pose, not relative to a neutral position.

**Solution:** Two-point calibration
1. User clicks "Calibrate" when looking straight ahead
2. Store that pose as `calibrationOffset`
3. Subtract offset from all subsequent poses

### Math
```swift
func applyCalibration(to pose: HeadPose) -> HeadPose {
    return HeadPose(
        position: pose.position - calibrationOffset.position,
        rotation: pose.rotation - calibrationOffset.rotation,
        ...
    )
}
```

### Edge Case: Angle Wrapping
Angles must wrap at ±180°:
```swift
func normalizeAngle(_ angle: Float) -> Float {
    var a = angle.truncatingRemainder(dividingBy: 360)
    if a > 180 { a -= 360 }
    if a < -180 { a += 360 }
    return a
}
```

---

## March 27, 2026 - Session 6: Smoothing Algorithm

### One Euro Filter Implementation

**Parameters:**
- `minCutoff`: 1.0 Hz (default)
- `beta`: 0.8 (default)  
- `dCutoff`: 1.0 Hz

**Formula:**
```
x̂(t) = α(t) * x(t) + (1 - α(t)) * x̂(t-1)
α(t) = 1 / (1 + τ(t))
τ(t) = 1 / (minCutoff^2 * (dx(t)^2 * beta + 1))
dx(t) = (x(t) - x̂(t-1)) / dt
```

### Implementation Notes
- Use `Float` for all calculations
- Convert to `Double` only for filter to maintain precision
- Apply in plugin (Mac side) for consistent smoothing

---

## March 28, 2026 - Session 7: iOS Permission Handling

### Required Permissions
1. **Camera** - Required for ARKit face tracking
   - `NSCameraUsageDescription`: "LidarSight uses the camera to track your head movement."

2. **Local Network** - Required for TCP/UDP to Mac
   - iOS 14+ requires explicit permission for local network access
   - Use `NWBrowser` to trigger permission prompt

### Implementation
```swift
func requestLocalNetworkPermission(completion: @escaping () -> Void) {
    let parameters = NWParameters()
    parameters.includePeerToPeer = true
    
    let browser = NWBrowser(for: .bonjour(type: "_lidarsight._tcp", domain: nil), using: parameters)
    // ... browser starts and triggers permission dialog
}
```

---

## March 28, 2026 - Session 8: Plugin Architecture

### X-Plane Plugin Structure

**Files:**
- `LidarSightXP.cpp` - Main plugin entry point
- `LidarSightXP.h` - Header with declarations
- `LidarSightXP.xcodeproj` - Xcode project

### DLL Start / Stop
```cpp
#include "XPLMPlugin.h"

PLUGIN_API int XPluginStart(char *name, char *sig, char *desc) {
    strcpy(name, "LidarSight XP");
    strcpy(sig, "com.lidarsight.xp");
    strcpy(desc, "Head tracking for X-Plane");
    // Initialize network, datarefs, etc.
    return 1;
}

PLUGIN_API void XPluginStop() {
    // Cleanup network, datarefs, etc.
}

PLUGIN_API int XPluginEnable() { return 1; }
PLUGIN_API void XPluginDisable() { }
```

### DataRefs to Register
- `lidarsight/connection_status` (int) - 0=disconnected, 1=connected
- `lidarsight/packet_rate` (float) - packets per second
- `lidarsight/last_pitch` (float) - last received pitch
- `lidarsight/last_yaw` (float) - last received yaw
- `lidarsight/last_roll` (float) - last received roll

---

## March 28, 2026 - Session 9: Network Protocol

### TCP vs UDP Decision

**Final Decision:** TCP for reliability
- UDP packets can be lost (causing jitter)
- TCP guarantees delivery
- Latency acceptable (~10ms on local network)

### Protocol

**iOS → Mac:**
```
[4 bytes length][33 bytes packet]
```

**Packet format (33 bytes):**
```
Offset  Type     Name
0       UInt32   packet_id (big endian)
4       UInt8    flags
5       Float    timestamp_us
9       Float    x
13      Float    y
17      Float    z
21      Float    pitch
25      Float    yaw
29      Float    roll
```

**Flags:**
- 0x01: Calibrated
- 0x02: Tracking Valid
- 0x04: Recenter (plugin should reset offset)

### Port
- iOS connects to Mac:4242
- Plugin listens on 0.0.0.0:4242

---

## March 28, 2026 - Session 10: Testing & Debugging

### Debugger App Requirement
User requested a macOS debugger app to visualize head tracking data.

### Features
1. TCP listener on port 4242
2. Real-time 3D head visualization
3. Raw/Filtered/Output values display
4. Settings panel for tuning

### Implementation
- Use SceneKit for 3D visualization
- OneEuroFilter for filtering
- SwiftUI for UI

---

## March 29, 2026 - Session 11: Code Review - Critical Bugs

### Bugs Found

1. **Swift struct padding in HeadPosePacket**
   - Changed field order to avoid padding issues
   - Verified 33-byte size

2. **Thread safety in plugin**
   - Flight data thread not being stopped on plugin disable
   - Fixed with proper thread cleanup

3. **Config loading**
   - Plugin not loading saved calibration from disk
   - Fixed with proper JSON loading

---

## March 29, 2026 - Session 12: Calibration Sync

### Issue
Calibration stored in iOS app wasn't being used by X-Plane plugin.

### Solution
1. iOS sends calibration flag in packet (0x01)
2. Plugin stores calibration offset when flag received
3. Subsequent packets adjusted by offset

### Flow
```
User taps "Calibrate" on iOS
    → iOS sends packet with flag 0x01
    → Plugin receives and stores offset
    → Future packets automatically adjusted
```

---

## March 29, 2026 - Session 13: Network Cleanup

### Issue
iOS app not properly cleaning up TCP connection on stop.

### Fix
Added proper cleanup in TransportManager.stop():
- Cancel TCP connection
- Cancel browser
- Reset state

### Also Fixed
- Plugin thread cleanup on disable

---

## March 30, 2026 - Session 14: Code Review Complete

### Bugs Fixed in Review
1. Swift struct padding - FIXED
2. Double calibration bug - FIXED  
3. Config loading in plugin - FIXED
4. Calibration sync - FIXED
5. Network cleanup - FIXED
6. Thread cleanup - FIXED

### Committed
- `29b4ed4` - Final code review fixes and documentation update

---

## March 30, 2026 - Session 15: Testing Setup

### User Testing Flow
1. Start X-Plane with plugin loaded
2. Start debugger app on Mac
3. Start LidarSight app on iPhone
4. Configure iOS to connect to Mac IP
5. Tap "Start Tracking" on iOS

### Debugger Shows
- Connection status
- Raw values from iOS
- Filtered values (One Euro)
- Output values (after curve mapping)

---

## March 30, 2026 - Session 16: Port Mismatch

### Issue Discovered
- iOS sending to port 4242
- Debugger listening on port 4243 (typo)
- Data not reaching debugger

### Fix
- Changed debugger default port to 4242
- Updated TCPListener.swift
- Updated StatusPanel.swift to show dynamic port

---

## March 30, 2026 - Session 17: ARKit Getting Stuck

### Issue
iOS app sending constant values - ARKit callbacks stop firing after first few frames.

### Debugging Steps
1. Added extensive debug logging to ARTrackingManager
2. Found ARKit session stops providing new face anchor updates
3. Tracking state shows "normal" but no new data

### Root Cause
ARKit face tracking appears to stop sending updates after a few seconds - known iOS issue.

### Solution
Added:
1. Stuck detection - if rotation unchanged for 60+ frames, restart AR session
2. Force send timer - send data every 100ms even if ARKit stops updating

---

## March 30, 2026 - Session 18: TCP Connection Issues

### Issues
1. iOS connecting to wrong IP (itself instead of Mac)
2. Debugger not handling reconnection properly
3. "Address already in use" error

### Fixes
1. Added UI for user to enter Mac IP in settings
2. Improved TCP reconnection logic
3. Fixed listener cleanup on reconnect

---

## March 30, 2026 - Session 19: Commit

### Committed: `1906a1a`
- Fix ARKit tracking stuck issue and improve TCP reliability
- Add stuck detection in ARTrackingManager - restarts AR session if pose stays constant
- Add force send timer to keep sending data even if ARKit callbacks stop
- Fix port mismatch (debugger now uses 4242 instead of 4243)
- Add debug logging to trace packet processing in debugger
- Improve TCP reconnection handling on iOS
- Fix NWConnection.State rawValue error (not available on macOS)

---

## Current State (April 4, 2026)

### What's Working
- iOS ARKit face tracking
- TCP connection iOS → Mac debugger
- Data showing in debugger RAW VALUES display
- Force-send timer keeps data flowing when ARKit stalls

### Remaining Issue
- OUTPUT values in debugger showing all zeros
- RAW: ~31.6° pitch, ~36° yaw, ~-0.3° roll
- FILTERED: same as raw
- OUTPUT: 0, 0, 0

### Likely Cause
- hasInitialPose flag is getting set incorrectly
- Deadzone settings may be blocking output
- Need to debug applyCurve function

### Files Modified
- `ios/LidarSightXP/LidarSightXP/Sources/AR/ARTrackingManager.swift`
- `ios/LidarSightXP/LidarSightXP/Sources/Transport/TransportManager.swift`
- `macos/HeadTrackerDebugger/HeadTrackerDebugger/Views/ContentView.swift`
- `macos/HeadTrackerDebugger/HeadTrackerDebugger/Views/StatusPanel.swift`
- `macos/HeadTrackerDebugger/HeadTrackerDebugger/Network/TCPListener.swift`
- `macos/HeadTrackerDebugger/HeadTrackerDebugger/Models/Shared.swift`

---

*Conversation logged: April 4, 2026*
*Author: Claude Code (opencode)*
