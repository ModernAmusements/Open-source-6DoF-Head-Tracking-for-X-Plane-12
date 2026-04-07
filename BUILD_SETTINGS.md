# Build Settings for Xcode Projects

## IMPORTANT: Always Use Release Configuration for Debugger

**The Debug build fails on macOS 26 with "doesn't contain an executable" error.**

### Solution 1: Change Scheme to Release (RECOMMENDED)
1. **Product → Scheme → Edit Scheme**
2. Select **Run** (left sidebar)
3. Change **Build Configuration** from Debug to **Release**
4. Click OK
5. Build and Run with Cmd+R

### Solution 2: Build from Terminal (ALWAYS WORKS)
```bash
cd /Users/modernamusmenet/Desktop/xplane12-headtracking/macos/HeadTrackerDebugger
xcodebuild -project HeadTrackerDebugger.xcodeproj -scheme HeadTrackerDebugger \
  -configuration Release build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

After building, the app is at:
```
~/Library/Developer/Xcode/DerivedData/HeadTrackerDebugger-*/Build/Products/Release/HeadTrackerDebugger.app
```

Copy to Desktop:
```bash
cp -R ~/Library/Developer/Xcode/DerivedData/HeadTrackerDebugger-govshdnkhvemljgbwugconmrqkgn/Build/Products/Release/HeadTrackerDebugger.app ~/Desktop/
```

## macOS Debugger App (HeadTrackerDebugger)

### Required Settings in project.yml

```yaml
settings:
  base:
    SWIFT_VERSION: "5.9"
    DEVELOPMENT_TEAM: ""
    CODE_SIGN_STYLE: Manual
    CODE_SIGN_IDENTITY: "-"
    ENABLE_HARDENED_RUNTIME: NO
    CODE_SIGNING_REQUIRED: NO
    CODE_SIGNING_ALLOWED: NO

targets:
  HeadTrackerDebugger:
    info:
      properties:
        CFBundleExecutable: HeadTrackerDebugger  # Must match actual binary name!
```

## iOS App

Build normally in Xcode or:
```bash
cd ios/LidarSightXP
xcodebuild -workspace LidarSightXP.xcworkspace -scheme LidarSightXP -configuration Debug build
```

## X-Plane Plugin

Build via CMake:
```bash
cd macos/LidarSightXP/build
cmake --build . --config Debug
```

Install:
```bash
cp dist/LidarSightXP.xpl ~/Library/Application\ Support/X-Plane\ 12/Plugins/LidarSightXP/mac_x64/
```

## Key Lessons Learned

1. **Always use Release configuration** for macOS debugger - Debug has issues on newer macOS
2. **CFBundleExecutable must match actual binary name** - was "LiDARSight" but binary is "HeadTrackerDebugger"
3. **Code signing**: Use CODE_SIGN_IDENTITY="-" and CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
4. **Packet parsing order**: Check OpenTrack (48 bytes) BEFORE LidarSight (33 bytes)
