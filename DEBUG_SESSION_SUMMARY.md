# X-Plane 12 HeadTracking - Debug Session Summary

## Issues Found and Fixed

### 1. iOS App - Protocol Display
**Problem:** Status always showed TCP even when OpenTrack was selected
**Fix:** Updated `statusText` in ContentView.swift to check `protocolMode` and show UDP for OpenTrack

### 2. iOS App - Protocol Change Not Applied
**Problem:** Changing Protocol setting didn't restart the connection with new protocol
**Fix:** (Not fully implemented) Settings need to trigger connection restart when protocol changes

### 3. Debugger - Packet Parsing Order (CRITICAL BUG)
**Problem:** Parser checked LidarSight (33 bytes) BEFORE OpenTrack (48 bytes). Since 48 >= 33, 48-byte OpenTrack packets were incorrectly parsed as LidarSight protocol. This caused:
- Protocol showing as "LidarSight" instead of "OpenTrack"
- Garbage values in RAW/FILTERED/OUTPUT fields

**Fix:** Changed order in `PacketParser.parse()` to check OpenTrack (48 bytes) FIRST:
```swift
// BEFORE (WRONG):
if data.count >= LidarSightPacket.size {
    return parseLidarSight(data)
} else if data.count >= OpenTrackPacket.size {
    return parseOpenTrack(data)
}

// AFTER (CORRECT):
if data.count >= OpenTrackPacket.size {
    return parseOpenTrack(data)
} else if data.count >= LidarSightPacket.size {
    return parseLidarSight(data)
}
```

### 4. Debugger - Xcode Build Errors
**Problem:** Code signing failed with "doesn't contain an executable"
**Fix:** Updated `project.yml`:
- Set `CFBundleExecutable: HeadTrackerDebugger` (not LiDARSight)
- Set code signing to Manual with CODE_SIGN_IDENTITY="-"
- Disable hardened runtime

### 5. Debugger - Deadzone Too High
**Problem:** Default deadzone of 2.0-3.0 degrees filtered out all input, causing OUTPUT to show 0
**Fix:** Reduced deadzone to 0.5 for all axes in Shared.swift:
```swift
var yaw: AxisConfig = AxisConfig(deadzone: 0.5, ...)
var pitch: AxisConfig = AxisConfig(deadzone: 0.5, ...)
var roll: AxisConfig = AxisConfig(deadzone: 0.5, ...)
```

### 6. Debugger - Roll Axis Disabled
**Problem:** Roll was disabled by default
**Fix:** Enabled roll axis in Shared.swift

### 7. OpenTrack Byte Order
**Problem:** iOS sends little-endian doubles, parser needed to read them correctly
**Fix:** Parser now reads doubles directly (native little-endian on Mac/iOS)

## Build Instructions

### iOS App
```bash
cd ios/LidarSightXP
xcodebuild -workspace LidarSightXP.xcworkspace -scheme LidarSightXP -configuration Debug build
```

### Debugger (macOS)
```bash
cd macos/HeadTrackerDebugger
xcodebuild -project HeadTrackerDebugger.xcodeproj -scheme HeadTrackerDebugger \
  -configuration Release build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### X-Plane Plugin
```bash
cd macos/LidarSightXP/build
cmake --build . --config Debug
cp dist/LidarSightXP.xpl ~/Library/Application\ Support/X-Plane\ 12/Plugins/LidarSightXP/mac_x64/
```

## How to Use

### iOS App
1. Open app → Settings
2. Set **Protocol** to **OpenTrack**
3. Tap **Save** 
4. Go back → Tap **Start Tracking**
5. Status should show: `UDP: <IP>:4242`

### Desktop Debugger
1. Launch HeadTrackerDebugger.app
2. Wait for iOS to send data
3. Protocol should show **OpenTrack**
4. RAW/FILTERED/OUTPUT values should be valid

### X-Plane Plugin
1. Ensure plugin is in: `~/Library/Application Support/X-Plane 12/Plugins/LidarSightXP/mac_x64/LidarSightXP.xpl`
2. Launch X-Plane 12
3. Enable head tracking in X-Plane settings
4. Use iOS app in OpenTrack mode

## Key Files Changed

- `ios/LidarSightXP/LidarSightXP/Sources/UI/ContentView.swift` - Protocol display fix
- `macos/HeadTrackerDebugger/HeadTrackerDebugger/Processing/PacketParser.swift` - Parse order fix
- `macos/HeadTrackerDebugger/HeadTrackerDebugger/Models/Shared.swift` - Deadzone/roll axis fix
- `macos/HeadTrackerDebugger/project.yml` - Code signing fix
- `macos/LidarSightXP/Sources/LidarSightXP.cpp` - Added UDP listener

## Notes

- OpenTrack protocol uses UDP port 4242
- LidarSight protocol uses TCP port 4243
- Packet size: OpenTrack = 48 bytes, LidarSight = 33 bytes
- iOS sends little-endian doubles (standard on ARM)
