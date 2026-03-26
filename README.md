# LidarSight XP

<p align="center">
  <strong>Professional-grade open-source 6DoF head-tracking for X-Plane 12</strong>
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#features">Features</a> •
  <a href="#hardware-requirements">Hardware</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#building-from-source">Build</a> •
  <a href="#license">License</a>
</p>

---

## Overview

LidarSight XP enables immersive cockpit exploration in X-Plane 12 using your iPhone as a head-tracking device. Simply mount your iPhone on a tripod facing you, and your head movements translate into real-time cockpit view changes.

This project provides:
- **iOS App** - Face tracking via ARKit, sends pose data over WiFi UDP
- **macOS Plugin** - Receives tracking data, applies smoothing, writes to X-Plane datarefs

**Author:** Shady Tawfik

---

## Features

- **6DoF Head Tracking** - Full position (X, Y, Z) and rotation (pitch, yaw, roll)
- **Eye Tracking** - Three modes: Head Only, Eyes Only, Head + Eyes (30% eye fine control)
- **WiFi UDP** - UDP broadcast on port 4242
- **One Euro Filter** - Smooth motion with adaptive cutoff for jitter-free tracking
- **Liquid Glass UI** - Native iOS glassmorphism interface
- **Auto-Calibration** - One-tap center alignment
- **View Detection** - Only activates in cockpit view (1017)
- **Thermal Management** - Auto throttles to 30Hz on overheating

---

## Hardware Requirements

### Required
- **iPhone X or later** (TrueDepth camera required for face tracking)
- **Mac** (running X-Plane 12)
- **Tripod stand** - Vertical mount, phone facing user (webcam style)
- **WiFi network** - iPhone and Mac on same network

### Recommended
- iPhone 12 or newer (better tracking performance)

---

## Installation

### iOS App

1. Clone this repository
2. Open `ios/LidarSightXP/LidarSightXP.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Select your iPhone as the device
5. Build and run (Cmd+R)

### macOS Plugin

**Quick Install (pre-built):**

The plugin is included in this repo at `macos/LidarSightXP/dist/LidarSightXP.xpl`.

Copy to X-Plane plugins folder:
```bash
mkdir -p "/Users/modernamusmenet/X-Plane 12/Resources/plugins/LidarSightXP/mac_x64"
cp macos/LidarSightXP/dist/LidarSightXP.xpl "/Users/modernamusmenet/X-Plane 12/Resources/plugins/LidarSightXP/mac_x64/"
```

**Or build from source:**
```bash
cd macos/LidarSightXP
mkdir build && cd build
cmake -DXPLANE_SDK=../../SDK ..
make
```

---

## Usage

### Starting Head Tracking

1. **iOS App:**
   - Launch LidarSightXP on your iPhone
   - Mount iPhone on tripod, facing you
   - Tap "Start Tracking"
   - Wait for face detection (green indicator)

2. **X-Plane Plugin:**
   - X-Plane 12 loads plugin automatically on startup
   - Plugin appears in `Plugins > LidarSight XP`

3. **Connect:**
   - Ensure iPhone and Mac on same WiFi network
   - App broadcasts on port 4242

### Calibration

1. Sit in your normal flying position
2. Look straight ahead at the center of your monitor
3. Tap "Calibrate" on iOS app
4. This sets your current position as neutral

### Recenter

If head tracking drifts over time:
- Tap "Recenter" button in iOS app

### Settings

| Setting | Description |
|---------|-------------|
| Sensitivity | Multiplier for head movement range (0.5 - 2.0) |
| Smoothing | One Euro filter strength |
| Eye Sensitivity | Multiplier for eye movement (higher = more eye control) |
| Stealth Mode | Auto-dim display after 10s of stable tracking |
| Tracking Mode | Head Only, Eyes Only, Head + Eyes |

### Tracking Modes

- **Head Only** - Original face tracking, head movement controls view
- **Eyes Only** - Eye direction controls view (minimal head movement needed)
- **Head + Eyes** - Eyes add 30% fine control on top of head movement

---

## Architecture

### Data Flow

```
┌─────────────┐     WiFi UDP     ┌─────────────┐    Datarefs    ┌─────────────┐
│  iPhone     │◄────────────────►│   Mac        │◄──────────────►│  X-Plane 12 │
│  (Face      │   255.255.255.255│  (Plugin)   │  acf_peX/Y/Z   │             │
│  Tracking)  │   port 4242      │  C++/SDK4   │                │             │
└─────────────┘                  └─────────────┘                └─────────────┘
```

### Components

#### iOS App
- **ARKit Session** - `ARFaceTrackingConfiguration` at 60fps
- **Face Anchor Extractor** - Gets transform matrix from face
- **Transform Converter** - Converts simd_float4x4 to Euler angles
- **Calibration Manager** - Stores/manages center offset
- **Transport Layer** - UDP broadcast on port 4242

#### macOS Plugin
- **UDP Server** - Listens on port 4242
- **One Euro Filter** - Signal smoothing (fc_min=30Hz, beta=0.6)
- **Atomic Triple-Buffer** - Thread-safe pose exchange
- **Dataref Writer** - Writes to X-Plane head position datarefs

### X-Plane Datarefs

| Dataref | Description |
|---------|-------------|
| `sim/aircraft/view/acf_peX` | Head X position (right/left) in meters |
| `sim/aircraft/view/acf_peY` | Head Y position (up/down) in meters |
| `sim/aircraft/view/acf_peZ` | Head Z position (forward/back) in meters |
| `sim/graphics/view/pilots_head_phi` | Head roll (tilt) in degrees |

---

## Data Packet Structure

```c
#pragma pack(push, 1)
struct HeadPosePacket {
    uint32_t packet_id;       // Sequence ID for interpolation
    uint8_t  flags;          // Bit 0: calibrated, Bit 1: tracking valid
    float    timestamp_us;   // Timestamp in microseconds
    float    x, y, z;        // Position in meters (relative to calibration)
    float    pitch, yaw, roll; // Rotation in degrees
};
#pragma pack(pop)
// Size: 33 bytes
```

---

## Potential Issues & Solutions

| Issue | Solution |
|-------|----------|
| Face not detected | Ensure good lighting, face within frame |
| Tracking jitter | Increase smoothing in settings |
| Head position drifts | Tap "Recenter" to reset |
| Plugin not visible in X-Plane | Ensure X-Plane 12.0.3 or later, check Log.txt for errors |
| WiFi not connecting | Ensure iPhone and Mac on same network |
| UDP Error 22 | App will request local network permission - allow it |
| Works in external view | Normal - only affects cockpit view 1017 |

---

## Building from Source

### Prerequisites

- **Xcode 15+** (for iOS app)
- **XcodeGen** (`brew install xcodegen`)
- **CMake 3.20+** (for macOS plugin)
- **X-Plane SDK 4.0** (included in repo as `SDK/`)

### iOS App Build Guide

```bash
# 1. Navigate to iOS project
cd ios/LidarSightXP

# 2. Generate Xcode project
xcodegen generate

# 3. Open in Xcode
open LidarSightXP.xcodeproj

# 4. Select your device and click Run (Cmd+R)
```

**Build Settings:**
- Deployment Target: iOS 15.0+
- Required Device: iPhone X or later (TrueDepth camera required)

### macOS Plugin Build Guide

**Option 1: Using pre-configured build (recommended)**

```bash
# Navigate to plugin directory
cd macos/LidarSightXP

# Clean and rebuild
cd build
make clean
cmake ..
make
```

**Option 2: Manual configuration**

```bash
# Navigate to plugin directory
cd macos/LidarSightXP

# Create and enter build directory
mkdir build
cd build

# Configure with CMake (specify SDK path)
cmake -DXPLANE_SDK=../../SDK ..

# Build the plugin
make
```

**Build Output:**
- Plugin location: `dist/LidarSightXP.xpl`
- File type: Mach-O universal binary (x86_64 + arm64)
- Size: ~138KB

**Troubleshooting Build:**

| Issue | Solution |
|-------|----------|
| CMake can't find SDK | Ensure SDK folder is at repo root |
| Missing XPLM.framework | Verify SDK/Libraries/Mac/XPLM.framework exists |
| Symbol not found | Ensure X-Plane SDK headers are in CHeaders/XPLM/ |
| Wrong architecture | Build includes -arch arm64 -arch x86_64 for universal binary |

**Installing the Plugin:**

```bash
# Create X-Plane plugins directory (X-Plane 12 format)
mkdir -p "/Users/[YOUR_USERNAME]/X-Plane 12/Resources/plugins/LidarSightXP/mac_x64"

# Copy plugin
cp dist/LidarSightXP.xpl "/Users/[YOUR_USERNAME]/X-Plane 12/Resources/plugins/LidarSightXP/mac_x64/"
```

Restart X-Plane after installation. The plugin will appear under `Plugins → LidarSightXP`.

---

## Coordinate Mapping

| Axis | ARKit | X-Plane | Transform |
|------|-------|---------|-----------|
| X | columns[3].x | acf_peX | Direct (meters) |
| Y | columns[3].y | acf_peY | Direct (meters) |
| Z | columns[3].z | acf_peZ | Direct (meters) |
| Pitch | Euler.x | - | Radians → Degrees |
| Yaw | Euler.y | - | Radians → Degrees |
| Roll | Euler.z | pilots_head_phi | Radians → Degrees |

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Latency (WiFi) | ~30-50ms |
| Jitter | < 0.05mm (filtered) |
| Frame Rate | 60Hz (30Hz thermal throttle) |

---

## Known Limitations

- WiFi UDP may have latency spikes
- Only works in cockpit view (view type 1017)
- Range limited by aircraft 3D model
- USB (PeerTalk) transport not yet implemented

---

## Contributing

Contributions are welcome! Please open an issue to discuss before submitting PRs.

---

## Acknowledgments

- [One Euro Filter](https://gery.casiez.net/1euro/) - Signal smoothing algorithm
- [HeadTrack](https://github.com/amyinorbit/headtrack) - Reference X-Plane plugin
- [X-Plane SDK](https://developer.x-plane.com/sdk/) - Plugin development

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Support

- **Issues:** https://github.com/shadytawfik/LidarSightXP/issues

---

<p align="center">
  Made with  by Shady Tawfik
</p>
