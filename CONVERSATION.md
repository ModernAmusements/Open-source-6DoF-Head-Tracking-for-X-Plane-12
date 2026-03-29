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
4. View Detection → only activate in cockpit (1017)
5. Face Tracking Loss → isTracked flag + hold position
6. Calibration Drift → recenter command + persistence
7. Thermal Throttling → auto-reduce to 30Hz
8. Coordinate Mismatch → explicit transform mapping
9. USB Cable Disconnect → auto-fallback to UDP
10. Aircraft-Specific Limits → document (no fix)

---

## Session 2: Implementation Started

### Project Structure Created
```
xplane12-headtracking/
├── ios/LidarSightXP/
│   ├── LidarSightXP/
│   │   ├── Sources/
│   │   │   ├── App/LidarSightXPApp.swift
│   │   │   ├── AR/ARTrackingManager.swift
│   │   │   ├── Models/
│   │   │   │   ├── HeadPose.swift
│   │   │   │   ├── HeadPosePacket.swift
│   │   │   │   └── CalibrationManager.swift
│   │   │   ├── Transport/TransportManager.swift
│   │   │   └── UI/
│   │   │       ├── ContentView.swift
│   │   │       └── ARSceneView.swift
│   │   └── Resources/Info.plist
│   ├── project.yml
│   └── Podfile
├── macos/LidarSightXP/
│   ├── Sources/
│   │   ├── LidarSightXP.cpp
│   │   ├── LidarSightXP.h
│   │   └── Processing/OneEuroFilter.h
│   └── CMakeLists.txt
├── SDK/ (X-Plane SDK 4.0)
├── README.md
├── ROADMAP.md
└── DEVELOPMENT.md
```

### Documentation Created
- `ROADMAP.md` - Full project roadmap with data flow diagrams
- `README.md` - User-facing documentation
- `DEVELOPMENT.md` - Technical development guide

---

## Session 3: Build Issues & Fixes

### Issue 1: X-Plane SDK Platform Definition
**Problem:** CMake couldn't find platform definition
**Fix:** Added `-DAPL=1` to CMakeLists.txt

### Issue 2: SDK Header Files Not Found
**Problem:** Headers were in `SDK/CHeaders/XPLM/` not `SDK/CHeaders/`
**Fix:** Updated include paths in CMakeLists.txt

### Issue 3: SDK Function Signatures
**Problem:** `XPLMRegisterFlightLoopCallback` signature changed in SDK 4.0
**Fix:** Changed from 4 arguments to 3 arguments

### Issue 4: XPLMCreateCommand Not Available
**Problem:** Command API not available in this SDK version
**Fix:** Removed command registration, using menu only

### Issue 5: Packet Size Mismatch
**Problem:** C++ struct was 24 bytes but Swift was 37 bytes
**Fix:** 
- Changed timestamp from `double` to `float` in Swift
- Added `#pragma pack(push, 1)` to C++
- Final size: 33 bytes

---

## Session 4: iOS Build Issues

### Issue 1: iOS Deployment Target
**Problem:** `.ultraThinMaterial` requires iOS 15+
**Fix:** Changed deployment target from 14.0 to 15.0

### Issue 2: Private Access Control
**Problem:** `settings` and `calibrationOffset` were private
**Fix:** Made public in TransportManager

### Issue 3: PeerTalk Sandbox Errors
**Problem:** CocoaPods PeerTalk caused code signing/sandbox errors
**Fix:** Removed PeerTalk, using WiFi UDP only

### Issue 4: ARFaceLandmarks Semantic
**Problem:** `.faceLandmarks` not available on all devices
**Fix:** Removed frame semantics, using basic face tracking

### Issue 5: Stealth Mode Capture Bug
**Problem:** Closure captured stale settings value
**Fix:** Captured `self` properly in Timer closure

### Issue 6: UDP Broadcast Error
**Problem:** NWConnection invalid argument error
**Fix:** Added state handler and connection start before send

---

## Session 5: Final Review & Documentation

### Code Review Findings
1. **ARSceneView Bug** - Created duplicate AR session
2. **Stealth Mode Bug** - Used captured variable instead of @State
3. **UDP Broadcast Bug** - Sent to own IP instead of broadcast address

### Final Architecture
```
┌─────────────┐     WiFi UDP     ┌─────────────┐    Datarefs    ┌─────────────┐
│  iPhone     │◄────────────────►│   Mac       │◄──────────────►│  X-Plane 12 │
│  (Face      │   255.255.255.255│  (Plugin)   │  acf_peX/Y/Z   │             │
│  Tracking)  │   port 4242      │  C++/SDK4   │                │             │
└─────────────┘                  └─────────────┘                └─────────────┘
```

### Packet Structure (Final)
```c
#pragma pack(push, 1)
struct HeadPosePacket {
    uint32_t packet_id;       // Sequence ID
    uint8_t  flags;          // Bit 0: calibrated, Bit 1: tracking valid
    float    timestamp_us;   // Microseconds (Float)
    float    x, y, z;        // Position in meters
    float    pitch, yaw, roll; // Rotation in degrees
};
#pragma pack(pop)
// Size: 33 bytes
```

### Implementation Status

| Component | Status |
|-----------|--------|
| iOS ARKit Face Tracking | ✅ Done |
| iOS Calibration | ✅ Done |
| iOS Transport (UDP) | ✅ Done |
| iOS UI (Glass) | ✅ Done |
| macOS Plugin | ✅ Done |
| One Euro Filter | ✅ Done |
| View Detection | ✅ Done |
| PeerTalk USB | ⏸ Deferred |

### Files Created/Modified
- `README.md` - Project documentation
- `ROADMAP.md` - Technical roadmap
- `DEVELOPMENT.md` - Developer guide
- `TESTING.md` - Testing checklist
- `ios/LidarSightXP/` - iOS app source
- `macos/LidarSightXP/` - Plugin source

---

## Key Decisions Made

1. **Vertical Tripod Setup** → Use ARFaceTrackingConfiguration (front camera)
2. **WiFi over USB** → UDP broadcast for initial release
3. **Datarefs over Camera** → Direct dataref writes for compatibility
4. **iOS 15+** → Required for glass materials
5. **No CocoaPods** → Avoiding complexity, using UDP only

---

## Open Items / Future Work

1. Add PeerTalk USB transport
2. Implement joystick binding for recenter
3. Add multi-display support
4. Test with various aircraft
5. Performance optimization

---

## Session 6: UDP Fix & Face Visualization

### Issue: UDP Error 22
**Problem:** "Invalid argument" NWError 22 when broadcasting packets
**Fix:** Changed from creating new NWConnection per-packet to persistent connection

### Issue: Duplicate AR Sessions
**Problem:** ARSCNView warning about duplicate sessions, camera errors
**Fix:** ARSceneView now uses session from ARTrackingManager instead of creating its own

### Issue: Face Visualization
**Problem:** No visual representation of head movement
**Fix:** Added ARSCNFaceGeometry wireframe mesh that tracks face

### Issue: LiDAR Support
**Problem:** User wanted LiDAR mode (only on Pro models)
**Fix:** Added TrackingMode enum with Face/LiDAR options in settings

### Issue: Interface Orientations
**Problem:** Warning about missing orientations
**Fix:** Added all orientations to Info.plist and project.yml

### Issue: Slider Descriptions
**Problem:** Settings sliders had no descriptions
**Fix:** Added labels, values, and explanatory text

### Commits Made
- `7cf28df` - Add LiDAR tracking mode and fix UDP broadcast error
- `8529453` - Add .gitignore for Xcode and build files
- `6342080` - Remove Xcode project files from git
- `edaf03f` - Fix ARSession sharing between ARSceneView and ARTrackingManager

---

## Session 7: NWError 22 Fix & Eye Tracking

### Issue: UDP Broadcast Error 22
**Problem:** "Invalid argument" NWError 22 when broadcasting packets
**Root Cause:** iOS Local Network Privacy requirements (iOS 14+)
**Fix:**
- Added `NSLocalNetworkUsageDescription` to Info.plist
- Added `NSBonjourServices` with `_lidarsight._udp`
- Modified TransportManager to trigger permission via NWBrowser
- Added completion handler to wait for permission before starting UDP

### Issue: Eye Tracking Request
**Problem:** User wanted eye tracking as an option to reduce head movement needed
**Solution:** Added three new tracking modes:
- **Head Only** (default) - Original face tracking
- **Eyes Only** - Eye direction controls view
- **Head + Eyes** - Eyes add 30% fine control on top of head

### Files Modified
1. **HeadPose.swift**
   - Changed TrackingMode enum to include headOnly, eyesOnly, headAndEyes
   - Added `eyeRotation` to HeadPose struct
   - Added `eyeSensitivity` to TrackingSettings

2. **ARTrackingManager.swift**
   - Added `isEyeTrackingEnabled = true` in config for eye modes
   - Added `extractEyeRotation()` to get eye transforms from ARFaceAnchor

3. **TransportManager.swift**
   - Modified `sendPose()` to handle three modes
   - EyesOnly uses eye rotation with higher sensitivity
   - HeadAndEyes combines head (70%) + eyes (30%)

4. **ContentView.swift**
   - Updated picker with 4 options
   - Added Eye Sensitivity slider in settings
   - Updated Start button icons per mode

5. **Info.plist**
   - Added NSLocalNetworkUsageDescription
   - Added NSBonjourServices

### Issue: LSP Errors
**Problem:** Language server showing false positive errors
**Solution:** Regenerated Xcode project with xcodegen - errors were due to missing project context, not actual code issues

---

## Session 8: macOS Plugin Build

### Plugin Build Steps
1. Verified SDK at `../../SDK`
2. Updated CMakeLists.txt with:
   - `-DAPL=1` (Apple platform flag)
   - `-arch arm64 -arch x86_64` (universal binary)
3. Built successfully with `cmake .. && make`
4. Output: `dist/LidarSightXP.xpl` (138KB, universal binary)

### Installation
- Copy to `~/Library/Application Support/X-Plane 12/Resources/plugins/LidarSightXP/MacOS/`

---

## Session 9: Documentation Update

### README.md Updated
- Added detailed iOS build guide
- Added detailed macOS plugin build guide with troubleshooting table
- Updated build output section

### Conversation Log Updated
- Documented all Session 7-9 changes

---

## Session 10: Plugin Loading Issues & Fix

### Issue: Plugin Not Visible in X-Plane
**Problem:** Plugin file existed but X-Plane couldn't load it
**Root Cause:** Missing X-Plane SDK entry point functions
**Solution:** Added required plugin callbacks

### Missing Entry Points
The plugin was missing these required functions:
- `XPluginStart()` - Called when X-Plane loads the plugin
- `XPluginStop()` - Called when X-Plane unloads the plugin
- `XPluginEnable()` - Called when plugin is enabled
- `XPluginDisable()` - Called when plugin is disabled
- `XPluginReceiveMessage()` - Handles inter-plugin messages

### Fix Applied
Added entry point functions to `LidarSightXP.cpp`:
```cpp
PLUGIN_API int XPluginStart(char* outName, char* outSignature, char* outDescription)
PLUGIN_API void XPluginStop()
PLUGIN_API int XPluginEnable()
PLUGIN_API void XPluginDisable()
PLUGIN_API void XPluginReceiveMessage(XPLMPluginID inFromWho, long inMessage, void* inParam)
```

### Plugin Folder Structure
Updated to match AviTab format:
```
LidarSightXP/
├── LICENSE
├── config.json
├── readme.txt
└── mac_x64/
    └── LidarSightXP.xpl
```

### Commits Made
- `bc85f3c` - Add X-Plane SDK entry point functions
- `55c218a` - Rebuild plugin with entry point functions
- `244f50c` - Add plugin distribution files (LICENSE, config.json, readme.txt)
- `e636e66` - Remove build artifacts from git tracking

---

## Session 11: UDP Broadcast Fix

### Issue: NWError 22 - Invalid Argument
**Problem:** UDP broadcast packets failing with "Invalid argument" error
**Root Cause:** Using hardcoded `255.255.255.255` broadcast address on iOS 14+
**Solution:** Dynamically compute broadcast address from local IP

### Fix Applied
Modified `TransportManager.swift`:
- Added `getBroadcastAddress()` function that computes broadcast from local IP
- Example: IP `192.168.1.100` → broadcast `192.168.1.255`

### Commit Made
- `80d1923` - Fix NWError 22 by using dynamic broadcast address

---

## Session 12: ARKit Eye Tracking Fixes

### Issue: isEyeTrackingEnabled Not Available
**Problem:** `ARFaceTrackingConfiguration` has no member `isEyeTrackingEnabled`
**Fix:** Removed unavailable property, eye tracking enabled by default on supported devices

### Issue: Optional Binding Error
**Problem:** `leftEyeTransform` and `rightEyeTransform` are non-optional
**Fix:** Changed from optional binding to direct assignment

### Issue: SwiftUI View Closure Error
**Problem:** `[weak self]` applied to SwiftUI struct (value type, not class)
**Fix:** Changed to `[self]` capture

### Commits Made
- `2427f81` - Fix ARKit eye tracking and SwiftUI closure issues

---

---

## Session 13: OpenTrack UDP Protocol Support

### Discussion: Why Use OpenTrack Protocol?
- OpenTrack is a well-established head tracking application with ~4.7k GitHub stars
- Uses standard UDP format on port 4242
- Has existing X-Plane plugin support
- Better ecosystem compatibility (FreePIE scripts, other tools)

### OpenTrack UDP Packet Format
- 48 bytes total (6 little-endian doubles)
- Order: `x, y, z, yaw, pitch, roll` (position in meters, rotation in radians)
- Offset 0-7: position x
- Offset 8-15: position y
- Offset 16-23: position z
- Offset 24-31: rotation x (pitch) in radians
- Offset 32-39: rotation y (yaw) in radians
- Offset 40-47: rotation z (roll) in radians

### Implementation Changes

1. **HeadPose.swift** - Added `ProtocolMode` enum:
   - `.custom` - LidarSight protocol (33 bytes)
   - `.openTrack` - OpenTrack UDP format (48 bytes)
   - Added `protocolMode` to `TrackingSettings`

2. **HeadPosePacket.swift** - Added `OpenTrackPacket` struct:
   - 48-byte packet with position (x, y, z) and rotation (pitch, yaw, roll)
   - Auto-converts degrees to radians for rotation
   - Includes range mapping and angle clamping

3. **TransportManager.swift** - Updated `sendPose()`:
   - Checks `settings.protocolMode` to choose packet format
   - Sends OpenTrack format when protocol is `.openTrack`

4. **ContentView.swift** - Updated Settings UI:
   - Added protocol picker in Connection section (segmented control)
   - Defaults to OpenTrack protocol for new users

### OpenTrack macOS Setup
- User installed MacOpentrack from matatata fork
- Found X-Plane plugin at `/Volumes/install/xplane/opentrack_arm64.xpl`
- Wine not needed - plugin works directly with X-Plane

### Commit Made
- `36c6154` - Add OpenTrack UDP protocol support to iOS app

---

---

## Session 14: X-Plane Plugin Fixes & OpenTrack Integration

### Issue: LidarSight Plugin Not Recognized by X-Plane
**Problem:** Plugin wasn't being loaded by X-Plane 12
**Solution:** Rebuilt plugin with proper SDK path and copied to correct location

### Plugin Rebuild Process
```bash
# Rebuilt with correct SDK path
rm -rf build && mkdir build && cd build
cmake -DSDK:PATH=/Users/modernamusmenet/Desktop/xplane12-headtracking/SDK ..
make

# Copied to X-Plane plugins folder
cp dist/LidarSightXP.xpl ~/Library/Application\ Support/X-Plane\ 12/Plugins/
```

### OpenTrack Integration
- User installed MacOpentrack from matatata fork
- Found X-Plane plugin at `/Volumes/install/xplane/opentrack_arm64.xpl`
- Wine not available via Homebrew - needed alternative approach

### Plugin Update: Dual Protocol Support
Updated the X-Plane plugin to support both packet formats:

1. **LidarSight protocol** (33 bytes) - custom format
2. **OpenTrack protocol** (48 bytes) - automatically detected

Added OpenTrackPacket struct and auto-detection in network code:
```cpp
if (n == PACKET_SIZE) {
    // LidarSight format
} else if (n == OPENTRACK_PACKET_SIZE) {
    // OpenTrack format - convert radians to degrees
    packet.pitch = otPacket.pitch * 180.0 / M_PI;
    packet.yaw = otPacket.yaw * 180.0 / M_PI;
    packet.roll = otPacket.roll * 180.0 / M_PI;
}
```

### Setup for Testing
**Option A: LidarSight Protocol**
- iOS: Settings → Protocol → LidarSight

**Option B: OpenTrack Protocol**
- iOS: Settings → Protocol → OpenTrack
- OpenTrack: Input = UDP (receives from iPhone)
- OpenTrack: Output = disabled (plugin receives directly)

### Commit Made
- `4897cb0` - Add OpenTrack packet format support to X-Plane plugin

---

---

## Session 15: X-Plane Plugin Loading Issue Resolved

### Problem
Plugin was not showing in X-Plane Plugin Manager despite being in the correct location.

### Solution
1. Created proper plugin folder structure: `Plugins/LidarSightXP/mac_x64/LidarSightXP.xpl`
2. Copied built plugin to: `~/X-Plane 12/Resources/plugins/LidarSightXP/mac_x64/`
3. Signed the plugin with ad-hoc signature

### Verification
Plugin now loads successfully - confirmed in Log.txt:
```
Loaded: /Users/modernamusmenet/X-Plane 12/Resources/plugins/LidarSightXP/mac_x64/LidarSightXP.xpl (com.lidarsight.xp).
```

### Testing
- OpenTrack integration working with dual protocol support
- iOS app sends OpenTrack UDP format on port 4242
- X-Plane plugin receives and applies head pose to cockpit view

---

---

## Session 16: Network & UI Fixes

### Fixed: NWError 22 Invalid Argument
- Simplified UDP broadcasting - creates new connection per packet
- Added required newConnectionHandler to NWListener
- Fixed port validation and error handling
- Removed force unwraps (!) for safer code
- Changed broadcast address to simple 255.255.255.255

### Fixed: X-Plane Plugin Menu
- Added menu with "Recenter Head" and "Enable/Disable Tracking" options
- Added debug logging via XPLMDebugString
- Plugin now shows as "Running" in Plugin Manager

### Fixed: iOS App Errors
- Removed iOS 16.4+ requirement for error codes
- Fixed Swift 6 language mode issues

### Current Status
- iOS app sends UDP packets on port 4242
- X-Plane plugin listens on port 4242
- Both LidarSight and OpenTrack protocols supported
- Head tracking should work when iOS app is connected

---

## Session 17: Bug Fixes & Code Review

### Issue 1: View Rotates Clockwise on Detection
**Problem:** As soon as head was detected, view started rotating clockwise continuously.
**Root Cause:** Plugin was applying raw yaw values without zeroing to initial position.
**Fix:** Added automatic zeroing on first valid pose detection:
- Added `mPoseOffset` to store initial pose
- Added `mHasInitialPose` flag to track calibration state
- On first packet, capture current pose as offset
- Subtract offset from all subsequent values

### Issue 2: X-Plane Crashes When Changing iOS Settings
**Problem:** Changing sensitivity in iOS app caused X-Plane to crash.
**Root Cause:** Large value changes could cause sudden jumps.
**Fix:** Added multiple defensive measures:
- Value validation (rejects NaN/Inf, clamps to ±10000)
- Delta clamping (max 30° change per frame)
- Angle normalization (±180° boundary handling)

### Issue 3: Only Rotation Wanted
**Problem:** User only wants to look up/down/left/right - no position movement in cockpit.
**Fix:** Removed all position (x, y, z) processing:
- Removed `mPositionFilter` and related code
- Removed unused datarefs (mHeadPosX/Y/Z)
- Only rotation (pitch/yaw/roll) is tracked and applied

### Issue 4: Edge Cases
**Problem:** Various edge cases not handled.
**Fixes:**
- Added frame timeout (re-zero after 2 seconds/120 frames of no data)
- Fixed `mLastFrameTime` to track actual elapsed time between callbacks
- Added angle normalization to prevent ±180° wrap-around spinning

### Code Review Findings & Fixes
1. **Dead code removed:**
   - `mPositionFilter` - unused after removing position tracking
   - `mHeadPosX/Y/Z` - position datarefs not used
   - `mRecenterCommand` - command registration unused
   - `mReadBuffer` - atomic counter unused
   - `<iostream>`, `<chrono>` - unused includes

2. **Fixed indentation typo** on line 66 (mLastFrameTime)

3. **Fixed constructor** - removed references to deleted members

### Files Modified
1. **LidarSightXP.cpp**
   - Added auto-zero on first pose detection
   - Added value validation and delta clamping
   - Added angle normalization
   - Added frame timeout for re-zeroing
   - Removed position filtering
   - Fixed mLastFrameTime to use actual elapsed time

2. **LidarSightXP.h**
   - Added `mPoseOffset` (HeadPosePacket)
   - Added `mHasInitialPose` (bool)
   - Added `mFramesSinceLastPacket` (int)
   - Removed `mHeadPosX/Y/Z`, `mRecenterCommand`, `mReadBuffer`
   - Removed `mPositionFilter`, `recenterCommandHandler`
   - Removed unused includes

### Plugin Rebuild
```bash
cd macos/LidarSightXP/build
cmake .. && make
cp dist/LidarSightXP.xpl ~/X-Plane\ 12/Resources/plugins/LidarSightXP/mac_x64/
codesign --force --sign - ~/X-Plane\ 12/Resources/plugins/LidarSightXP/mac_x64/LidarSightXP.xpl
```

---

---

## Session 18: VR-Like Head Tracking System

### Deep Dive: What Makes VR Tracking Work

Research into OpenTrack and professional head tracking solutions revealed key techniques:

1. **Non-linear curve mapping** - Deadzone for center stability, quadratic acceleration for range
2. **Per-axis configuration** - Yaw/Pitch/Roll need different settings
3. **Filter tuning** - One Euro Filter parameters need to match use case
4. **Configurable defaults** - Users need to tweak for their setup

### Implementation

#### 1. Configuration System (AxisConfig per axis)
```cpp
struct AxisConfig {
    float deadzone;      // Ignore small movements
    float maxInput;     // Max head rotation
    float maxOutput;    // Max view rotation
    float curvePower;   // 1.0=linear, 2.0=quadratic
    bool enabled;       // Enable/disable axis
    bool invert;        // Reverse direction
};

struct TrackingConfig {
    AxisConfig yaw;     // Left/Right
    AxisConfig pitch;  // Up/Down
    AxisConfig roll;   // Tilt
    float filterMinCutoff;
    float filterBeta;
    float filterDCutoff;
};
```

#### 2. Default Settings
| Axis | Deadzone | Max Input | Max Output | Curve | Enabled |
|------|----------|-----------|------------|-------|---------|
| Yaw | 2° | 30° | 90° | 2.0 | Yes |
| Pitch | 3° | 20° | 25° | 1.5 | Yes |
| Roll | 0° | 15° | 15° | 1.0 | No |

Filter: minCutoff=1.0Hz, beta=0.1, dCutoff=1.0Hz

#### 3. Curve Application Function
```cpp
float applyCurve(float value, const AxisConfig& config) {
    if (!config.enabled || abs(value) < config.deadzone) {
        return 0.0f;
    }
    // Non-linear mapping with deadzone
    float t = (absVal - deadzone) / (maxInput - deadzone);
    float curved = deadzone + (maxOutput - deadzone) * t^curvePower;
    return sign * curved;
}
```

#### 4. Config File I/O
- Location: `~/Library/Application Support/X-Plane 12/LidarSightXP/config.txt`
- Load on plugin start
- Save via menu

#### 5. Menu System
```
LidarSight XP
├── Recenter Head (R)
├── Enable/Disable Tracking (T)
├── Yaw Settings
│   ├── Enable/Disable Yaw
│   ├── Invert Yaw
│   ├── Increase/Decrease Deadzone
│   └── Increase/Decrease Sensitivity
├── Pitch Settings
│   ├── Enable/Disable Pitch
│   ├── Invert Pitch
│   └── Increase/Decrease Deadzone
├── Filter Settings
│   ├── Smoother
│   └── More Responsive
├── Load Config (L)
├── Save Config (S)
└── Reset to Defaults
```

### Files Modified
1. **LidarSightXP.h** - Added AxisConfig, TrackingConfig structs
2. **LidarSightXP.cpp** - Added applyCurve, loadConfig, saveConfig, menu system

### Testing Notes
- Deadzone keeps center stable (like VR)
- Curve power determines acceleration curve
- Filter smoothing affects lag vs stability tradeoff

---

## Session 19: Jitter Fixes & Code Review

### Issue: Jitter Not Acceptable
**Problem:** Numbers flip between after decimal - visible jitter when holding head still
**Root Causes:**
1. ARKit provides noisy data (60Hz updates)
2. iOS smoothing was too low (0.3)
3. Plugin One Euro filter had high cutoff (15Hz)

### Fixes Applied

1. **iOS Smoothing**: Increased from 0.3 to 0.85
   - Aggressive EMA filter before sending
   - Alpha = 0.15 (15% new data, 85% old)

2. **Plugin One Euro Filter**:
   - Cutoff: 15Hz → 1Hz
   - Beta: 0.5 → 0.8
   - Deadzone: 0° → 0.5°

3. **Face Tracking Loss**:
   - Reset EMA filter when tracking lost
   - No more drift after face disappears

4. **Memory Leaks Fixed**:
   - NWBrowser now cancelled on stop

5. **Dead Code Removed**:
   - Removed applyAngleClamp(), applyRangeMapping()

6. **View Detection Fixed**:
   - Now accepts views 1000-1035 (was only 1026)

### Code Review Findings

**Critical Issues Fixed:**
- Stealth mode timer captured `self` incorrectly
- Tracking lost → kept sending old values

**Edge Cases Covered:**
- NaN/Inf validation on plugin
- Angle wrapping (±180°)
- Triple-buffer for packet loss

---

## Session 20: UI Options Discussion

### User Request
- Don't want to see 3D face mesh
- Options discussed:
  1. Black screen
  2. Head icon overlay (recommended)
  3. Flight data display

### Decision
Pending - user to choose option

---

*Conversation logged: March 29, 2026*
*Author: Shady Tawfik*
