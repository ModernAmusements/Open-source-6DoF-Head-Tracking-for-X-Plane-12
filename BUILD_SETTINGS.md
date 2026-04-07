# Build Settings for Xcode Projects

## macOS Debugger App (HeadTrackerDebugger)

### Required Settings to Prevent Code Signing Errors

In `project.yml`, use these settings:

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
        CFBundleExecutable: HeadTrackerDebugger  # Must match actual binary name
```

### Building in Xcode

If you get "doesn't contain an executable" errors:
1. Use **Release** configuration instead of Debug, OR
2. Ensure CFBundleExecutable matches the actual binary name

Build command:
```bash
xcodebuild -project HeadTrackerDebugger.xcodeproj -scheme HeadTrackerDebugger \
  -configuration Release build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## iOS App

Build normally in Xcode. No special settings needed.

## Plugin

Build via CMake:
```bash
cd macos/LidarSightXP/build
cmake --build . --config Debug
```
