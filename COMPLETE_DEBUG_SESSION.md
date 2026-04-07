# X-Plane 12 HeadTracking - Complete Debug Session

## Critical Issues Found & Fixed

### 1. PACKET PARSING ORDER BUG (CRITICAL)
**Location:** `macos/HeadTrackerDebugger/HeadTrackerDebugger/Processing/PacketParser.swift`

**Problem:** Parser checked LidarSight (33 bytes) BEFORE OpenTrack (48 bytes). Since 48 >= 33, 48-byte OpenTrack packets were incorrectly parsed as LidarSight protocol.

**Fix:** Check OpenTrack FIRST:
```swift
static func parse(_ data: Data) -> ParsedPacket? {
    // OpenTrack (48 bytes) FIRST
    if data.count >= OpenTrackPacket.size {
        return parseOpenTrack(data)
    } else if data.count >= LidarSightPacket.size {
        return parseLidarSight(data)
    }
    return nil
}
```

### 2. iOS Protocol Display
**Location:** `ios/LidarSightXP/LidarSightXP/Sources/UI/ContentView.swift`

**Problem:** Status showed "TCP" even when OpenTrack was selected.

**Fix:** Updated statusText to check protocolMode:
```swift
if transportManager.settings.protocolMode == .openTrack {
    return "UDP: \(targetIP):4242"
} else {
    return "TCP: \(targetIP):\(transportManager.tcpPort)"
}
```

### 3. Debugger Deadzone Too High
**Location:** `macos/HeadTrackerDebugger/HeadTrackerDebugger/Models/Shared.swift`

**Problem:** Default deadzone 2.0-3.0 filtered out all input → OUTPUT always 0

**Fix:** Reduced deadzone to 0.5 for all axes, enabled roll axis

### 4. Debugger Xcode Build Error
**Location:** `macos/HeadTrackerDebugger/project.yml`

**Problem:** "doesn't contain executable" error

**Fix:** 
- Set CFBundleExecutable to "HeadTrackerDebugger" (not LiDARSight)
- Use Release configuration (NOT Debug)
- Code signing: CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

### 5. Missing Xcode Scheme
**Location:** `macos/HeadTrackerDebugger/HeadTrackerDebugger.xcodeproj`

**Problem:** No xcscheme file existed

**Fix:** Created xcscheme with Release configuration

## Build Instructions

### Debugger (ALWAYS USE RELEASE)
```bash
cd /Users/modernamusmenet/Desktop/xplane12-headtracking/macos/HeadTrackerDebugger

# Generate project (after any project.yml changes)
xcodegen generate

# Build with Release
xcodebuild -project HeadTrackerDebugger.xcodeproj -scheme HeadTrackerDebugger \
  -configuration Release build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### iOS App
```bash
cd /Users/modernamusmenet/Desktop/xplane12-headtracking/ios/LidarSightXP
xcodebuild -workspace LidarSightXP.xcworkspace -scheme LidarSightXP -configuration Debug build
```

### X-Plane Plugin
```bash
cd /Users/modernamusmenet/Desktop/xplane12-headtracking/macos/LidarSightXP/build
cmake --build . --config Debug
cp dist/LidarSightXP.xpl ~/Library/Application\ Support/X-Plane\ 12/Plugins/LidarSightXP/mac_x64/
```

## Usage

### iOS App
1. Open app → Settings
2. Set Protocol to **OpenTrack**
3. Tap Save
4. Go back → Tap Start Tracking
5. Status should show: `UDP: <IP>:4242`

### Desktop Debugger
1. Launch HeadTrackerDebugger.app
2. iOS sends data → auto-connects
3. Protocol shows **OpenTrack**
4. RAW/FILTERED/OUTPUT show valid values

### X-Plane Plugin
1. Ensure plugin at: `~/Library/Application Support/X-Plane 12/Plugins/LidarSightXP/mac_x64/LidarSightXP.xpl`
2. Launch X-Plane 12
3. Use iOS in OpenTrack mode

## Key Technical Details

- **OpenTrack:** 48 bytes, UDP port 4242
- **LidarSight:** 33 bytes, TCP port 4243
- **Byte order:** iOS sends little-endian doubles
- **Filter:** One Euro Filter with configurable minCutoff/beta

## Files Changed

- `macos/HeadTrackerDebugger/HeadTrackerDebugger/Processing/PacketParser.swift`
- `macos/HeadTrackerDebugger/HeadTrackerDebugger/Models/Shared.swift`
- `macos/HeadTrackerDebugger/project.yml`
- `ios/LidarSightXP/LidarSightXP/Sources/UI/ContentView.swift`
- `macos/LidarSightXP/Sources/LidarSightXP.cpp` (UDP listener)

## Lessons Learned

1. **Packet size matters:** Check larger packets first
2. **Release, not Debug:** macOS 26 has issues with Debug builds
3. **CFBundleExecutable:** Must match actual binary name
4. **Code signing:** Use manual signing for local builds
