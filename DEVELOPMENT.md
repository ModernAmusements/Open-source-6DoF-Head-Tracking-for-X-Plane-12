# LidarSight XP - Development Guide

## Project Overview

LidarSight XP is a 6DoF head-tracking system for X-Plane 12 that uses an iPhone mounted on a tripod to track the user's face and translate head movements into cockpit view changes.

## Architecture

```
┌─────────────┐     WiFi UDP      ┌─────────────┐    Datarefs    ┌─────────────┐
│  iPhone     │◄────────────────►│   Mac       │◄──────────────►│  X-Plane 12 │
│  (Face      │  255.255.255.255 │  (Plugin)   │  acf_peX/Y/Z   │             │
│  Tracking)  │    port 4242      │  C++/SDK4   │                │             │
└─────────────┘                  └─────────────┘                └─────────────┘
```

**Current Status:** WiFi UDP only. USB (PeerTalk) transport deferred.

## Development Setup

### Prerequisites

- **macOS** (development machine)
- **Xcode 15+** (for iOS app)
- **CMake 3.20+** (for plugin)
- **X-Plane 12** (with SDK 4.0)
- **iPhone X or later** (TrueDepth camera required)
- **Apple Developer Account** (for iOS deployment)

### SDK Setup

The X-Plane SDK should be placed in the project root:
```
xplane12-headtracking/
├── SDK/                    # X-Plane SDK 4.0
│   ├── CHeaders/
│   ├── Libraries/Mac/
│   └── ...
├── ios/
├── macos/
└── ...
```

## Building

### iOS App

```bash
cd ios/LidarSightXP

# Generate Xcode project
xcodegen generate

# Install dependencies (PeerTalk for USB)
pod install

# Open workspace
open LidarSightXP.xcworkspace
```

In Xcode:
1. Select your development team in Signing & Capabilities
2. Select target device (iPhone)
3. Build and run (Cmd+B)

### macOS Plugin

```bash
cd macos/LidarSightXP

# Create build directory
mkdir build && cd build

# Configure with CMake
cmake ..

# Build
make

# The plugin will be in dist/LidarSightXP.xpl
```

### Installing the Plugin

Copy to X-Plane plugins folder:
```bash
mkdir -p ~/Library/Application\ Support/X-Plane\ 12/Plugins/LidarSightXP.xpl/
cp dist/LidarSightXP.xpl ~/Library/Application\ Support/X-Plane\ 12/Plugins/LidarSightXP.xpl/
```

## Code Structure

### iOS App (`ios/LidarSightXP/`)

```
LidarSightXP/
├── Sources/
│   ├── App/
│   │   └── LidarSightXPApp.swift      # App entry point
│   ├── AR/
│   │   └── ARTrackingManager.swift   # ARKit face tracking
│   ├── Models/
│   │   ├── HeadPose.swift            # Pose data structures
│   │   ├── HeadPosePacket.swift       # Network packet (24 bytes)
│   │   └── CalibrationManager.swift   # Calibration state
│   ├── Transport/
│   │   └── TransportManager.swift    # UDP/USB transport
│   └── UI/
│       ├── ContentView.swift          # Main UI
│       └── ARSceneView.swift          # AR camera view
└── Resources/
    └── Info.plist
```

### macOS Plugin (`macos/LidarSightXP/`)

```
macos/LidarSightXP/
├── Sources/
│   ├── LidarSightXP.cpp              # Main plugin
│   ├── LidarSightXP.h                # Header
│   └── Processing/
│       └── OneEuroFilter.h           # Signal smoothing
├── CMakeLists.txt
└── dist/
    └── LidarSightXP.xpl              # Built plugin
```

## Key Components

### HeadPosePacket (24 bytes)

```c
struct HeadPosePacket {
    uint32_t packet_id;       // Sequence ID
    uint8_t  flags;           // Bit 0: calibrated, Bit 1: tracking valid
    double   timestamp_us;    // Microseconds
    float    x, y, z;         // Position (meters)
    float    pitch, yaw, roll; // Rotation (degrees)
};
```

### One Euro Filter

Parameters (from Monado VR runtime):
- `fc_min = 30.0 Hz` (minimum cutoff)
- `beta = 0.6` (responsiveness)
- `d_cutoff = 25.0 Hz` (derivative cutoff)

### X-Plane Datarefs

| Dataref | Description |
|---------|-------------|
| `sim/aircraft/view/acf_peX` | Head X position |
| `sim/aircraft/view/acf_peY` | Head Y position |
| `sim/aircraft/view/acf_peZ` | Head Z position |
| `sim/graphics/view/pilots_head_phi` | Head roll |

### View Detection

The plugin only activates in cockpit view (type 1017).

## Testing

### iOS App Testing

1. Mount iPhone on tripod facing you
2. Launch app on iPhone
3. Tap "Start Tracking"
4. Ensure face is detected (green indicator)
5. Check connection status shows IP:port

### Plugin Testing

1. Launch X-Plane 12
2. Load any aircraft
3. Enter cockpit view
4. Check X-Plane's plugin menu for "LidarSight XP"
5. Verify no errors in Console.app

### End-to-End Testing

1. Ensure iPhone and Mac are on same WiFi
2. Start iOS app, begin tracking
3. Start X-Plane, enter cockpit
4. Move your head - should see cockpit view follow

## Troubleshooting

### iOS App

- **Face not detected**: Ensure good lighting, face within frame
- **Connection issues**: Check firewall settings on Mac
- **Build errors**: Ensure you opened `.xcworkspace` not `.xcodeproj`

### Plugin

- **Not loading**: Check Console.app for errors
- **No head movement**: Verify UDP port 4242 is not blocked
- **Works in external view**: This is normal - plugin only activates in cockpit

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## License

MIT License - see LICENSE file
