# LidarSight XP - Project Roadmap

## Overview

A professional-grade, open-source 6DoF head-tracking system for X-Plane 12 using iPhone + MacBook.

**Goal:** Enable free cockpit look-around via head tracking

---

## Hardware Setup

- **iPhone 12+** (front camera with TrueDepth for face tracking)
- **MacBook Pro** (runs X-Plane 12 plugin)
- **Tripod stand** (vertical mount, phone pointing at user like a webcam)

---

## Architecture

```
┌─────────────┐     WiFi UDP     ┌─────────────┐    Datarefs    ┌─────────────┐
│  iPhone     │◄────────────────►│   Mac       │◄──────────────►│  X-Plane 12 │
│  (Face      │   255.255.255.255│  (Plugin)   │  acf_peX/Y/Z   │             │
│  Tracking)  │   port 4242      │  C++/SDK4   │                │             │
└─────────────┘                  └─────────────┘                └─────────────┘
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              iOS APP                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────┐ │
│  │ ARKit        │───►│ FaceAnchor   │───►│ Transform    │───►│ Packet   │ │
│  │ Session      │    │ Extractor    │    │ Converter    │    │ Builder  │ │
│  │ (60fps)     │    │              │    │ (simd→Euler) │    │          │ │
│  └──────────────┘    └──────────────┘    └──────────────┘    └────┬─────┘ │
│                                                                     │        │
│  ┌──────────────────────────────────────────────────────────────┐  │        │
│  │                    CALIBRATION STATE                          │◄─┤        │
│  │  - calibration_offset (x, y, z, pitch, yaw, roll)           │  │        │
│  │  - sensitivity_multiplier                                    │  │        │
│  └──────────────────────────────────────────────────────────────┘  │        │
│                                                                     │        │
└──────────────────────────────────────────────────────────────┬───────┘        │
                                                              │                │
                         ┌──────────────────────────────────────┴────────────┐ │
                         │                   TRANSPORT LAYER                 │ │
                         │                                                       │ │
                         │  ┌─────────────────┐                               │ │
                         │  │   UDP            │      (WiFi only)                │ │
                         │  │   Broadcast     │      ~30-50ms                   │ │
                         │  │   port 4242     │                                 │ │
                         │  └────────┬────────┘                                 │ │
                         │           │                         │              │ │
                         │           └───────────┬─────────────┘              │ │
                         │                       │                           │ │
                         └───────────────────────┼───────────────────────────┘ │
                                                 │                               │
                         ┌───────────────────────┴───────────────────────────┐ │
                         │              macOS PLUGIN                         │ │
                         │                                                    │ │
                         │  ┌──────────────┐    ┌──────────────┐    ┌──────┐ │ │
                         │  │  Receiver    │───►│ One Euro     │───►│ Pose  │ │ │
                         │  │  Thread      │    │ Filter       │    │ Buffer│ │ │
                         │  │  (background)│    │ (smoothing)  │    │       │ │ │
                         │  └──────────────┘    └──────────────┘    └───┬────┘ │ │
                         │                                              │      │ │
                         │  ┌──────────────────────────────────────────┐ │      │ │
                         │  │          ATOMIC POSE SWAP               │◄─┘      │ │
                         │  │  ┌─────┐  ┌─────┐  ┌─────┐              │        │ │
                         │  │  │ A   │  │ B   │  │ C   │  (triple)    │        │ │
                         │  │  └──┬──┘  └──┬──┘  └──┬──┘              │        │ │
                         │  │     │        │        │                 │        │ │
                         │  │     └────────┴────────┘                 │        │ │
                         │  └──────────────────────────────────────────┘        │ │
                         │                                                    │ │
                         └──────────────────────┬─────────────────────────────┘ │
                                                │                                 │
                        ┌────────────────────────┴──────────────────────────────┐ │
                        │              X-PLANE 12                               │ │
                        │                                                      │ │
                        │  ┌────────────────────────────────────────────────┐   │ │
                        │  │              FLIGHT LOOP                      │   │ │
                        │  │  ┌─────────────┐    ┌──────────────────────┐  │   │ │
                        │  │  │ View Check  │───►│  Dataref Writer      │  │   │ │
                        │  │  │ (cockpit?)  │    │  acf_peX/Y/Z         │  │   │ │
                        │  │  └─────────────┘    │  pilots_head_phi    │  │   │ │
                        │  │                      └──────────────────────┘  │   │ │
                        │  └────────────────────────────────────────────────┘   │ │
                        │                                                      │ │
                        └──────────────────────────────────────────────────────┘ │
                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Packet Flow Details

```
iOS Frame (60Hz)          USB Transfer              Mac Plugin              X-Plane (60Hz)
     │                         │                         │                         │
     ▼                         │                         │                         │
 ┌────────┐                   │                         │                         │
 │ Face   │                   │                         │                         │
 │Anchor  │─── extract ───────│                         │                         │
 │data    │    transform       │                         │                         │
 └────────┘                   │                         │                         │
     │                        │                         │                         │
     ▼                        │                         │                         │
 ┌────────┐                   │                         │                         │
 │ Euler  │─── subtract ──────│                         │                         │
 │Angles  │    calibration    │                         │                         │
 └────────┘                   │                         │                         │
     │                        │                         │                         │
     ▼                        │                         │                         │
 ┌────────┐   serialize       │                         │                         │
 │Packet  │───────────────────│─── TCP stream ────────►│                         │
 │(24B)   │                   │                         │                         │
 └────────┘                   │                         │                         │
                              │                         ▼                         │
                              │                   ┌────────────┐                 │
                              │                   │  Receive   │                 │
                              │                   │  Thread    │                 │
                              │                   └─────┬──────┘                 │
                              │                         │                         │
                              │                         ▼                         │
                              │                   ┌────────────┐                 │
                              │                   │ One Euro   │                 │
                              │                   │ Filter     │                 │
                              │                   └─────┬──────┘                 │
                              │                         │                         │
                              │                         ▼                         │
                              │                   ┌────────────┐                 │
                              │                   │ Atomic     │                 │
                              │                   │ Buffer     │                 │
                              │                   └─────┬──────┘                 │
                              │                         │                         │
                              │                         ▼                         │
                              │                   ┌────────────┐                 │
                              │                   │ Flight     │◄── X-Plane         │
                              │                   │ Loop       │    callback        │
                              │                   └─────┬──────┘                 │
                              │                         │                         │
                              │                         ▼                         │
                              │                   ┌────────────┐                 │
                              │                   │ Datarefs   │───► Pilot head │
                              │                   │ written    │    position     │
                              │                   └────────────┘                 │
```

---

## Potential Traps & Solutions

### 1. Gimbal Lock
**Problem:** Euler angles can flip at steep pitch angles
**Solution:** Work with quaternions in ARKit, convert to Euler only for X-Plane output

### 2. Thread Safety
**Problem:** UDP receiver thread != X-Plane main thread
**Solution:** Triple-buffer with atomic swap - writer fills inactive buffer, reader swaps atomically

### 3. Packet Loss (WiFi)
**Problem:** UDP drops cause head "jumping"
**Solution:** 
- Sequence ID for interpolation
- Linear interpolation between last two valid poses
- 100ms timeout → revert to last known position

### 4. X-Plane View Detection
**Problem:** Head tracking active in external views causes weird behavior
**Solution:** 
- Read `sim/graphics/view/view_type` dataref
- Only activate in cockpit view (type 1017)
- Auto-pause when switching to external views

### 5. Face Tracking Loss
**Problem:** Face leaves frame or poor lighting
**Solution:**
- Track `ARFaceAnchor.isTracked`
- Flag in packet indicates valid/invalid
- Hold last known position if lost < 500ms
- Visual indicator in iOS app

### 6. Calibration Drift
**Problem:** Over time, head position "wanders"
**Solution:**
- Recentering command bound to joystick button
- Store calibration in UserDefaults (persist across sessions)
- Auto-recenter on app foreground

### 7. Thermal Throttling
**Problem:** iPhone overheats during long flights
**Solution:**
- Monitor `ProcessInfo.processInfo.thermalState`
- Auto-reduce ARKit frame rate to 30Hz
- Alert user in UI

### 8. Coordinate System Mismatch
**Problem:** ARKit uses different axes than X-Plane
**Solution:** Explicit transform matrix mapping (documented in Coordinate Mapping section)

### 9. USB Cable Disconnect
**Problem:** PeerTalk connection drops mid-flight
**Solution:**
- Auto-fallback to UDP when USB disconnects
- Visual indicator of connection status
- Reconnect automatically when cable re-plugged

### 10. Aircraft-Specific Limits
**Problem:** Some aircraft limit head movement range
**Solution:**
- Document that head movement is aircraft-dependent
- No fix possible - inherent to aircraft 3D model

---

## Key Findings

### 1. ARKit Configuration

**Correct approach:** `ARFaceTrackingConfiguration` (front camera)

For vertical webcam-style mount, the phone tracks the user's face directly via the front camera. This is how commercial apps like SmoothTrack work. No LiDAR required for this approach.

### 2. Transport Layer

| Primary | Fallback |
|---------|----------|
| **PeerTalk** (USB via usbmuxd) | WiFi UDP (port 4242) |

- PeerTalk: Proven in production (Duet Display), MIT license, ~5ms latency
- UDP: Convenience fallback, ~10-30ms latency

### 3. X-Plane Integration

**Recommended:** Direct dataref writes (NOT camera override)

| Dataref | Description |
|---------|-------------|
| `sim/aircraft/view/acf_peX` | Head X position (right/left) |
| `sim/aircraft/view/acf_peY` | Head Y position (up/down) |
| `sim/aircraft/view/acf_peZ` | Head Z position (forward/back) |
| `sim/graphics/view/pilots_head_phi` | Head roll (tilt) |

This approach:
- Is simpler than camera override
- Works with all aircraft
- Doesn't conflict with other plugins
- Is multi-monitor friendly

### 4. Signal Processing

**One Euro Filter** parameters (from Monado VR runtime):
- `fc_min = 30.0 Hz` (minimum cutoff)
- `beta = 0.6` (responsiveness)
- `d_cutoff = 25.0 Hz` (derivative cutoff)

### 5. Thermal Management

- iPhone front camera throttles under sustained use
- Auto-fallback to 30Hz when thermal state elevates

---

## Data Packet Structure

```c
#pragma pack(push, 1)
struct HeadPosePacket {
    uint32_t packet_id;       // Sequence ID for interpolation
    uint8_t  flags;          // Calibrated, tracking status bits
    float    timestamp_us;   // Microseconds for latency monitoring
    float    x, y, z;       // Position (meters, relative to calibration)
    float    pitch, yaw, roll; // Rotation (degrees)
};
#pragma pack(pop)
```

Size: 33 bytes

---

## Implementation Phases

### PHASE 1: iOS App (Swift/SwiftUI) ✅ DONE

- [x] ARFaceTrackingConfiguration setup
- [x] ARFaceAnchor extraction (transform + blend shapes)
- [x] Face transform → 6DoF head pose conversion
- [x] One-tap calibration (store center offset)
- [ ] PeerTalk USB transport (deferred)
- [x] WiFi UDP broadcast (port 4242)
- [x] Liquid Glass UI (SwiftUI `.ultraThinMaterial`)
- [x] Sensitivity settings
- [x] Stealth mode (auto-dim)

### PHASE 2: macOS Plugin (C++/SDK 4.0) ✅ DONE

- [ ] PeerTalk client (deferred)
- [x] Background receive thread
- [x] One Euro Filter implementation
- [x] Triple-buffer atomic pose swap
- [x] Dataref writer (sim/aircraft/view/acf_pe*)
- [x] View detection (only activate in cockpit 1017)
- [x] Buildable on Intel + Apple Silicon

### PHASE 3: Calibration & Polish ✅ DONE

- [x] Auto-detect center on app start
- [x] Manual recenter button
- [ ] Joystick binding support (not available in SDK 4.0)
- [x] Thermal throttling

---

## Coordinate Mapping

| Axis | ARKit Source | X-Plane Target | Transform |
|------|--------------|-----------------|-----------|
| X (Lean) | `columns[3].x` | `acf_peX` | Direct (meters) |
| Y (Height) | `columns[3].y` | `acf_peY` | Direct (meters) |
| Z (Depth) | `columns[3].z` | `acf_peZ` | Direct (meters) |
| Pitch | Euler.x | - | Rad → Deg |
| Yaw | Euler.y | - | Rad → Deg |
| Roll | Euler.z | `pilots_head_phi` | Rad → Deg |

---

## Open-Source Details

| Item | Decision |
|------|----------|
| License | MIT |
| Repository | GitHub |
| iOS Build | Xcode project, CocoaPods/SwiftPM |
| macOS Build | CMake + X-Plane SDK 4.0 |

---

## SDK & Resources

- **X-Plane SDK:** https://developer.x-plane.com/sdk/
- **PeerTalk:** https://github.com/rsms/peertalk
- **One Euro Filter:** https://gery.casiez.net/1euro/
- **Reference Plugin (HeadTrack):** https://github.com/amyinorbit/headtrack

---

## Next Steps

1. Create Xcode project for iOS app
2. Set up C++ project for macOS plugin
3. Implement face tracking → pose extraction
4. Implement PeerTalk transport
5. Implement One Euro Filter
6. Implement dataref writer
7. Test integration with X-Plane 12
