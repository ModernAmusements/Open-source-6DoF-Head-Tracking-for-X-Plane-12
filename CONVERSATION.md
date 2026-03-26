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

*Conversation logged: March 26, 2026*
*Author: Shady Tawfik*
