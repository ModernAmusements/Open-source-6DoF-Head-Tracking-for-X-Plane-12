# LiDARSight - Designer Kickoff

## Project Overview

LiDARSight is a head tracking system for X-Plane 12 flight simulator that uses an iPhone's TrueDepth camera to track pilot head movements and translate them to the in-cockpit view.

## Core Components

### 1. iOS App (LiDARSight) - STANDALONE
- **Purpose:** Track face/head using iPhone's TrueDepth camera
- **Platform:** iOS 17+ (iPhone only - requires Face ID hardware)
- **Sensors Used:** ARKit face tracking, LiDAR (if available)
- **Connection:** Sends data via UDP (OpenTrack) or TCP (LidarSight) to Mac
- **Standalone:** Works independently, sends to either debugger app OR X-Plane plugin

### 2. macOS App (HeadTrackerDebugger) - STANDALONE
- **Purpose:** Debug and visualize head tracking data for development/testing
- **Platform:** macOS 14+
- **Features:** Real-time data visualization, packet inspection, filter tuning
- **Standalone:** Can receive data from iOS app without X-Plane running

### 3. X-Plane Plugin (LidarSightXP) - STANDALONE
- **Purpose:** Receive head tracking data and apply to X-Plane cockpit view
- **Platform:** macOS (X-Plane 12 plugin)
- **Standalone:** Works without debugger - iOS app sends directly to plugin

## System Architecture

```
┌─────────────────┐      UDP 4242 / TCP 4243      ┌─────────────────┐
│                 │ ───────────────────────────► │                 │
│   iOS App       │                              │  macOS Debugger │  (Standalone)
│ (LiDARSight)    │      OR                       │                 │
│                 │ ───────────────────────────► │                 │
└─────────────────┘      UDP 4242                └─────────────────┘
                                                          │
                                                          │ OR
                                                          ▼
                                                 ┌─────────────────┐
                                                 │                 │
                                                 │ X-Plane Plugin  │  (Standalone)
                                                 │  (LidarSightXP)  │
                                                 │                 │
                                                 └─────────────────┘
```

**Three standalone apps that can work independently or together:**

1. **iOS App** → **macOS Debugger** (for development/testing)
2. **iOS App** → **X-Plane Plugin** (for flight simulation)
3. Any combination works!

## Key Screens / Views

### iOS App (STANDALONE)

1. **Main Tracking Screen**
   - Large "Start/Stop Tracking" button
   - Face detection indicator (green/red dot)
   - Current status (Connected/Disconnected)
   - Minimal HUD overlay showing current pose

2. **Settings Screen**
   - Tracking Mode selector (Head Only / Head + Eyes / LiDAR)
   - Sensitivity slider
   - Smoothing slider
   - Max Angle slider
   - Protocol selector (OpenTrack UDP / LidarSight TCP)
   - Target IP address input (Mac's IP address)

3. **Connection Status**
   - Shows connection type: "UDP: 192.168.x.x:4242" (OpenTrack) or "TCP: 192.168.x.x:4243" (LidarSight)
   - Local IP display

### macOS Debugger App (STANDALONE)

1. **Main View**
   - 3D cockpit/windshield visualization
   - RAW values display (pitch, yaw, roll) - direct from iOS
   - FILTERED values (after One Euro filter) - smoothed data
   - OUTPUT values (after curve mapping) - final values to X-Plane
   - Packet rate display (should be ~60 pkt/s)
   - Protocol detection indicator (shows OpenTrack or LidarSight)

2. **Settings Panel**
   - Filter parameters (minCutoff, beta, dCutoff)
   - Axis configuration (deadzone, maxInput, maxOutput, curvePower, invert)
   - Enable/disable per axis (pitch, yaw, roll)

### X-Plane Plugin (STANDALONE)

The plugin has NO UI - it works invisibly in X-Plane:

1. **In X-Plane Settings**
   - Enable head tracking input
   - Plugin automatically applies tracking to cockpit view

## Visual Style

### Current Design Language
- **Framework:** SwiftUI (iOS), SwiftUI for macOS (debugger)
- **Theme:** Dark mode, glassmorphism effects
- **Platform-Specific:**
  - iOS: Native SwiftUI with iOS 17+ styling
  - macOS: Native SwiftUI with macOS styling
- **Colors:**
  - Primary: Blue (#007AFF)
  - Success/Connected: Green (#34C759)
  - Warning: Yellow (#FFCC00)
  - Error/No Face: Red (#FF3B30)
  - Background: Dark with blur effects (.ultraThinMaterial)

### Design Principles
1. **Standalone operation** - Each app works independently
2. **Minimal UI during flight** - Don't distract the pilot
3. **High contrast indicators** - Easy to see at a glance
4. **Dark theme only** - Reduces eye strain in dark cockpit
5. **Large touch targets** - Easy to tap during flight
6. **Glassmorphism** - Modern iOS/macOS look (using .ultraThinMaterial)

## UI/UX Requirements

### iOS App
- Must work in portrait orientation
- Large, easy-to-tap buttons for flight use
- Clear visual feedback for connection status
- Face detection indicator visible at all times

### Desktop Debugger
- Clear real-time visualization of tracking data
- Easy access to filter and axis settings
- Protocol detection display

## Technical Notes for Design

### Data Flow Options

**Option 1: Development/Testing**
```
iOS App → macOS Debugger (UDP 4242)
```
- Use debugger to visualize and tune tracking
- No X-Plane required
- Great for testing without launching simulator

**Option 2: Flight Simulation**
```
iOS App → X-Plane Plugin (UDP 4242)
```
- Direct to X-Plane for actual flight
- Plugin handles all view manipulation
- No debugger needed

### Data Formats

**OpenTrack Protocol (48 bytes) - RECOMMENDED**
- UDP port 4242
- Standard head tracking protocol
- Used by SmoothTrack, FreeTrack, etc.
- Simpler, more compatible

**LidarSight Protocol (33 bytes) - LEGACY**
- TCP port 4243
- Custom protocol with additional flags
- Backward compatibility only

### Connection Setup

**For Debugger:**
1. Open debugger app on Mac
2. In iOS Settings → Protocol: OpenTrack
3. In iOS Settings → Target IP: Mac's IP address
4. Tap Start Tracking
5. Status shows: "UDP: <Mac-IP>:4242"

**For X-Plane:**
1. Ensure plugin is installed in X-Plane 12
2. In iOS Settings → Protocol: OpenTrack
3. In iOS Settings → Target IP: Mac's IP (same Mac running X-Plane)
4. Tap Start Tracking
5. Enable head tracking in X-Plane settings

## Assets Needed

### iOS App
- App icon (1024x1024)
- SF Symbols used:
  - `face.smiling` - Face tracking active
  - `face.dashed` - Face not detected
  - `antenna.radiowaves.left.and.right` - Connected
  - `wifi.slash` - Disconnected
  - `gearshape` - Settings
  - `play.fill` - Start tracking
  - `stop.fill` - Stop tracking

### macOS Debugger App
- App icon (can use same as iOS)
- SF Symbols used:
  - `antenna.radiowaves.left.and.right` - Connected
  - `wifi.slash` - Disconnected
  - `gearshape` - Settings
  - `arrow.triangle.2.circlepath` - Recenter

### X-Plane Plugin
- No UI - no assets needed

## References

- **OpenTrack Protocol:** https://github.com/amyinorbit/headtrack
- **X-Plane Head Tracking:** Uses X-Plane datarefs for cockpit view

## Contact

For design questions, contact the development team with any clarification needs.
