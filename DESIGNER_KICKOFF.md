# LiDARSight - Designer Kickoff

## Project Overview

LiDARSight is a head tracking system for X-Plane 12 flight simulator that uses an iPhone's TrueDepth camera to track pilot head movements and translate them to the in-cockpit view.

## Core Components

### 1. iOS App (LiDARSight)
- **Purpose:** Track face/head using iPhone's TrueDepth camera
- **Platform:** iOS 17+ (iPhone only - requires Face ID hardware)
- **Sensors Used:** ARKit face tracking, LiDAR (if available)

### 2. Desktop Debugger (HeadTrackerDebugger)
- **Purpose:** Debug and visualize head tracking data
- **Platform:** macOS 14+
- **Features:** Real-time data visualization, packet inspection

### 3. X-Plane Plugin (LidarSightXP)
- **Purpose:** Receive head tracking data and apply to X-Plane cockpit view
- **Platform:** macOS (X-Plane 12 plugin)

## Key Screens / Views

### iOS App Screens

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
   - Protocol selector (OpenTrack / LidarSight)
   - Target IP input

3. **Connection Status**
   - Shows connection type: UDP (OpenTrack) or TCP (LidarSight)
   - Local IP display

### Desktop Debugger Screens

1. **Main View**
   - 3D cockpit visualization
   - RAW values display (pitch, yaw, roll)
   - FILTERED values (after One Euro filter)
   - OUTPUT values (after curve mapping to X-Plane)
   - Packet rate display
   - Protocol detection indicator

2. **Settings Panel**
   - Filter parameters (minCutoff, beta, dCutoff)
   - Axis configuration (deadzone, maxInput, maxOutput, curvePower, invert)
   - Enable/disable per axis

## Visual Style

### Current Design Language
- **Framework:** SwiftUI (iOS), SwiftUI for macOS (debugger)
- **Theme:** Dark mode, glassmorphism effects
- **Colors:**
  - Primary: Blue (#007AFF)
  - Success: Green (#34C759)
  - Warning: Yellow (#FFCC00)
  - Error: Red (#FF3B30)
  - Background: Dark with blur effects

### Design Principles
1. **Minimal UI during flight** - Don't distract the pilot
2. **High contrast indicators** - Easy to see at a glance
3. **Dark theme only** - Reduces eye strain in dark cockpit
4. **Large touch targets** - Easy to tap during flight
5. **Glassmorphism** - Modern iOS/macOS look

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

### Data Formats

**OpenTrack Protocol (48 bytes)**
- UDP port 4242
- Standard head tracking protocol
- Used by SmoothTrack, FreeTrack, etc.

**LidarSight Protocol (33 bytes)**
- TCP port 4243
- Custom protocol with additional flags

### Coordinate System
- Pitch: Up/Down (degrees)
- Yaw: Left/Right (degrees)
- Roll: Tilt (degrees)

### Key User Flows

1. **First Launch**
   - Request camera permission
   - Request local network permission (for UDP/TCP)

2. **Start Tracking**
   - Tap Start button
   - App requests permission if needed
   - Face detection indicator turns green
   - Status shows "UDP: <IP>:4242" for OpenTrack mode

3. **Adjust Settings**
   - Open Settings
   - Adjust sensitivity/smoothing
   - Change protocol if needed
   - Settings auto-save

## Assets Needed

### iOS App
- App icon (1024x1024)
- SF Symbols used:
  - `face.smiling` - Face tracking active
  - `face.dashed` - Face not detected
  - `antenna.radiowaves.left.and.right` - Connected
  - `wifi.slash` - Disconnected
  - `gearshape` - Settings

### Desktop Debugger
- App icon (if different from iOS)
- Could reuse iOS app icon

## References

- **OpenTrack Protocol:** https://github.com/amyinorbit/headtrack
- **X-Plane Head Tracking:** Uses X-Plane datarefs for cockpit view

## Contact

For design questions, contact the development team with any clarification needs.
