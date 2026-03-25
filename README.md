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
- **iOS App** - Face tracking via ARKit, sends pose data over USB/WiFi
- **macOS Plugin** - Receives tracking data, applies smoothing, writes to X-Plane datarefs

**Author:** Shady Tawfik

---

## Features

- **6DoF Head Tracking** - Full position (X, Y, Z) and rotation (pitch, yaw, roll)
- **USB Low-Latency** - PeerTalk protocol for ~5ms latency over Lightning cable
- **WiFi Fallback** - UDP broadcast for convenient wireless operation
- **One Euro Filter** - Smooth motion with adaptive cutoff for jitter-free tracking
- **Liquid Glass UI** - Native iOS glassmorphism interface
- **Auto-Calibration** - One-tap center alignment
- **View Detection** - Only activates in cockpit view
- **Thermal Management** - Auto throttles to 30Hz on overheating

---

## Hardware Requirements

### Required
- **iPhone X or later** (TrueDepth camera required for face tracking)
- **MacBook Pro** (or any Mac running X-Plane 12)
- **Tripod stand** - Vertical mount, phone facing user (webcam style)
- **Lightning cable** (for USB mode)

### Recommended
- iPhone 12 or newer (better tracking performance)
- Dedicated USB port on Mac (reduces latency)

---

## Installation

### iOS App (Beta)

> **Note:** The iOS app requires building from source for now.

1. Clone this repository
2. Open `ios/LidarSightXP/LidarSightXP.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and deploy to your iPhone

### macOS Plugin

1. Download the latest release from [Releases](https://github.com/shadytawfik/LidarSightXP/releases)
2. Extract `LidarSightXP.xpl` to:
   ```
   ~/Library/Application Support/X-Plane 12/Plugins/
   ```
3. Create folder structure if needed:
   ```
   X-Plane 12/Plugins/LidarSightXP.xpl/
   ```

---

## Usage

### Starting Head Tracking

1. **iOS App:**
   - Launch LidarSightXP on your iPhone
   - Mount iPhone on tripod, facing you
   - Tap "Start Tracking"
   - Wait for face detection (green indicator)

2. **macOS Plugin:**
   - X-Plane 12 loads plugin automatically on startup
   - Plugin appears in `Plugins > LidarSight XP`

3. **Connect:**
   - **USB:** Plug in Lightning cable - auto-connects
   - **WiFi:** Ensure iPhone and Mac on same network, app shows IP:port

### Calibration

1. Sit in your normal flying position
2. Look straight ahead at the center of your monitor
3. Tap "Calibrate" on iOS app (or press joystick button)
4. This sets your current position as neutral

### Recenter

If head tracking drifts over time:
- Tap "Recenter" button in iOS app
- Or bind joystick button to `LidarSight/Recenter` command

### Settings

| Setting | Description |
|---------|-------------|
| Sensitivity | Multiplier for head movement range (0.5 - 2.0) |
| Smoothing | One Euro filter strength |
| Transport | USB (PeerTalk) or WiFi (UDP) |
| Stealth Mode | Auto-dim display after 10s of stable tracking |

---

## Architecture

### Data Flow

```
┌─────────────┐     USB      ┌─────────────┐    Datarefs    ┌─────────────┐
│  iPhone     │◄────────────►│   MacBook   │◄──────────────►│  X-Plane 12 │
│  (Face      │   PeerTalk   │  (Plugin)   │  acf_peX/Y/Z   │             │
│  Tracking)  │              │  C++/SDK4   │                │             │
└─────────────┘              └─────────────┘                └─────────────┘
```

### Components

#### iOS App
- **ARKit Session** - `ARFaceTrackingConfiguration` at 60fps
- **Face Anchor Extractor** - Gets transform matrix from face
- **Transform Converter** - Converts simd_float4x4 to Euler angles
- **Calibration Manager** - Stores/manages center offset
- **Transport Layer** - PeerTalk (USB) + UDP (WiFi)

#### macOS Plugin
- **PeerTalk Client** - USB device detection and connection
- **UDP Server** - WiFi fallback receiver
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
    double   timestamp_us;   // Timestamp in microseconds
    float    x, y, z;       // Position in meters (relative to calibration)
    float    pitch, yaw, roll; // Rotation in degrees
};
#pragma pack(pop)
// Size: 24 bytes
```

---

## Potential Issues & Solutions

| Issue | Solution |
|-------|----------|
| Face not detected | Ensure good lighting, face within frame |
| Tracking jitter | Increase smoothing in settings |
| Head position drifts | Tap "Recenter" to reset |
| Plugin not loading | Check Console.app for X-Plane errors |
| USB connection fails | Try different Lightning cable/port |
| Works in external view | Normal - only affects cockpit |

---

## Building from Source

### Prerequisites

- **Xcode 15+** (for iOS app)
- **XcodeGen** (`brew install xcodegen`)
- **CocoaPods** (`sudo gem install cocoapods`)
- **CMake 3.20+** (for macOS plugin)
- **X-Plane SDK 4.0** (download from developer.x-plane.com)

### iOS App

```bash
# Generate Xcode project
cd ios/LidarSightXP
xcodegen generate

# Install dependencies (PeerTalk for USB)
pod install

# Open workspace (not project!)
open LidarSightXP.xcworkspace

# Build in Xcode (Cmd+B)
# Or from command line:
xcodebuild -workspace LidarSightXP.xcworkspace -scheme LidarSightXP -configuration Debug -destination 'generic platform=iOS' build
```

### macOS Plugin

```bash
cd macos/LidarSightXP
mkdir build && cd build
cmake -DXPLANE_SDK=/path/to/XPLANE_SDK ..
make
```

The built plugin will be in `build/LidarSightXP.xpl`

Copy to X-Plane plugins folder:
```bash
cp build/LidarSightXP.xpl ~/Library/Application\ Support/X-Plane\ 12/Plugins/LidarSightXP.xpl/
```

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
| Latency (USB) | < 10ms |
| Latency (WiFi) | < 30ms |
| Jitter | < 0.05mm (filtered) |
| Frame Rate | 60Hz (30Hz thermal throttle) |

---

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## Acknowledgments

- [PeerTalk](https://github.com/rsms/peertalk) - USB communication library
- [One Euro Filter](https://gery.casiez.net/1euro/) - Signal smoothing algorithm
- [HeadTrack](https://github.com/amyinorbit/headtrack) - Reference X-Plane plugin
- [X-Plane SDK](https://developer.x-plane.com/sdk/) - Plugin development

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Support

- **Issues:** https://github.com/shadytawfik/LidarSightXP/issues
- **Discussions:** https://github.com/shadytawfik/LidarSightXP/discussions

---

<p align="center">
  Made with  by Shady Tawfik
</p>
