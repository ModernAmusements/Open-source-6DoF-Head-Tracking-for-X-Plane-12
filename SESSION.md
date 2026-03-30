# Session Summary - March 30, 2026

## Problem
iOS was blocking UDP packets to local network IPs - getting "No route to host" and "Host is down" errors.

## Solution
Switched from UDP to TCP for iOS→Mac communication.

## Changes Made

### 1. iOS TransportManager (TCP Client)
- Changed from UDP broadcast to TCP connection
- Port changed from 4242 to 4243
- Added `tcpPort` property
- Renamed methods: `startUDPServer()` → `startTCPServer()`, `stopUDPServer()` → `stopTCPServer()`
- Added TCP connection handling with reconnection logic

### 2. macOS Debugger (TCP Listener)
- Renamed `UDPListerner.swift` → `TCPListener.swift`
- Changed from UDP to TCP server
- Port changed from 4242 to 4243
- Added length-prefixed packet parsing (4-byte length header)
- Updated `ContentView.swift` to use `TCPListener`

### 3. X-Plane Plugin
- Changed from UDP to TCP server on port 4243
- Added UDP forwarding to port 4242 (for X-Plane native head tracking / OpenTrack)
- Updated `LidarSightXP.cpp` with TCP accept loop and UDP broadcast
- Updated `LidarSightXP.h` with `mUdpForwardSock` member
- Updated `config.json` and `readme.txt`

### 4. UI Updates
- Changed port display in StatusPanel.swift: 4242 → 4243
- Changed iOS ContentView: `udpPort` → `tcpPort`, "UDP:" → "TCP:"
- Updated launch screens: removed subtitle, simplified font

### 5. Documentation
- Updated README.md with new architecture diagram
- Added macOS Debugger to features and architecture
- Updated network flow description
- Updated troubleshooting section

## Port Summary
| Component | Protocol | Port |
|-----------|----------|------|
| iOS → Mac | TCP | 4243 |
| Plugin → X-Plane | Datarefs | - |
| Plugin → Other apps | UDP | 4242 |

## Files Modified
- `ios/LidarSightXP/.../TransportManager.swift`
- `ios/LidarSightXP/.../ContentView.swift`
- `macos/HeadTrackerDebugger/.../TCPListener.swift` (renamed)
- `macos/HeadTrackerDebugger/.../ContentView.swift`
- `macos/HeadTrackerDebugger/.../StatusPanel.swift`
- `macos/HeadTrackerDebugger/.../Shared.swift`
- `macos/HeadTrackerDebugger/project.yml` (regenerated)
- `macos/LidarSightXP/Sources/LidarSightXP.cpp`
- `macos/LidarSightXP/Sources/LidarSightXP.h`
- `macos/LidarSightXP/dist/config.json`
- `macos/LidarSightXP/dist/readme.txt`
- `README.md`
