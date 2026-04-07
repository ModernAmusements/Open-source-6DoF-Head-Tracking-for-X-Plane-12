# LiDARSight - Complete UI/UX Specification

## Overview

This document outlines all screens needed for the complete LiDARSight application suite:
1. **iOS App** - Main tracking application
2. **macOS Debugger** - Development/debugging tool
3. **X-Plane Plugin** - No UI required (works invisibly)

---

# Part 1: iOS App Screens

## 1.1 Onboarding Flow

### Screen: Welcome / Permissions
**Purpose:** First-time setup, request necessary permissions

**Layout:**
- App logo/icon (centered, large)
- Title: "LiDARSight"
- Subtitle: "Head Tracking for X-Plane"
- Feature highlights (3-4 bullet points with icons):
  - "Face tracking with iPhone TrueDepth camera"
  - "Works with X-Plane 12"
  - "Smooth, responsive head tracking"
- "Get Started" button (primary, large)
- Skip option (text button)

**Permissions Requested:**
- Camera (for ARKit face tracking)
- Local Network (for UDP/TCP communication)

### Screen: Camera Permission
**Purpose:** Request camera access for face tracking

**Layout:**
- Icon: camera viewfinder
- Title: "Camera Access Required"
- Description: "LiDARSight uses your iPhone's camera to track your face for head tracking. Your camera feed is never stored or transmitted."
- "Allow Camera" button
- "Not Now" option

### Screen: Local Network Permission  
**Purpose:** Request local network access for communication with Mac

**Layout:**
- Icon: WiFi / network
- Title: "Local Network Access"
- Description: "LiDARSight needs to communicate with your Mac over your local network to send head tracking data to X-Plane or the debugger app."
- "Allow Local Network" button
- Learn more link (expandable)

---

## 1.2 Main Tracking Screen

### Screen: Main (Home)
**Purpose:** Primary interface for starting/stopping tracking

**Layout:**
- **Top Section:**
  - Connection status pill (shows IP:port or "Disconnected")
  - Status dot (green/yellow/red)
  
- **Center Section:**
  - Large circular button:
    - Default: Play icon + "Start Tracking"
    - Active: Stop icon + "Stop Tracking" (red tint)
  - Face detection indicator (large, below button):
    - Green dot + "Face Detected" when tracking
    - Red dot + "No Face" when not detected

- **Bottom Section:**
  - Tracking mode label (e.g., "Head Only" / "Head + Eyes")
  - Quick settings gear icon (takes to Settings)

### Screen: Tracking Active Overlay
**Purpose:** Minimal HUD shown during active tracking

**Layout (appears over main screen during tracking):**
- Semi-transparent background
- Current rotation values (optional, can be hidden)
- Face status dot (smaller)
- Stop button (smaller, for quick access)

---

## 1.3 Settings Screens

### Screen: Settings List
**Purpose:** Main settings hub

**Layout:**
- Navigation title: "Settings"
- Grouped list sections:

**Tracking Section:**
- Tracking Mode (picker: Head Only / Head + Eyes / LiDAR)
- Sensitivity (slider: 0.5x - 3.0x)
- Smoothing (slider: 0.0 - 0.9)
- Max Angle (slider: 15° - 90°)
- Range Curve (slider: Linear / Non-linear)

**Eye Tracking Section (if Head + Eyes mode):**
- Eye Sensitivity (slider: 1.0x - 5.0x)

**Connection Section:**
- Protocol (segmented: OpenTrack / LidarSight)
- Target IP (text field for Mac's IP address)
- Auto-connect toggle

**Info Section:**
- Local IP address display
- App version
- Reset to Defaults button

### Screen: Protocol Settings Detail
**Purpose:** Deep dive into protocol configuration

**Layout:**
- Header: Protocol explanation
- Visual diagram showing data flow
- Port information:
  - OpenTrack: UDP 4242
  - LidarSight: TCP 4243
- Recommended setting (OpenTrack)
- Test connection button

### Screen: Calibration
**Purpose:** Recenter/reset head position

**Layout:**
- Title: "Recenter"
- Description: "Set current head position as neutral (center)"
- Large "Recenter" button
- Or tap anywhere on screen to recenter (quick action)

---

## 1.4 Support Screens

### Screen: About
**Purpose:** App information

**Layout:**
- App icon
- App name and version
- Developer info
- Links:
  - GitHub repository
  - Documentation
  - Report an issue

### Screen: Help / FAQ
**Purpose:** Troubleshooting and help

**Layout:**
- Search bar
- Common questions (expandable):
  - "Why isn't my face being detected?"
  - "How do I find my Mac's IP address?"
  - "Why is the tracking laggy?"
  - "Which protocol should I use?"
  - "How do I enable head tracking in X-Plane?"

### Screen: Settings - Calibration Offset Display
**Purpose:** Show current calibration values

**Layout:**
- Current offset display (pitch, yaw, roll)
- "Reset Calibration" button
- Last calibration time

---

# Part 2: macOS Debugger Screens

## 2.1 Main Debugger Screen

### Screen: Main Debug View
**Purpose:** Real-time data visualization and debugging

**Layout (full window, dark theme):**

**Top Bar:**
- Window title: "LiDARSight Debugger"
- Connection status (Connected/Disconnected)
- Packet rate: "60.2 pkt/s"
- Protocol detected: "OpenTrack" / "LidarSight"
- Local IP:Port

**Left Panel - 3D Visualization:**
- Windshield / cockpit view representation
- Head position indicator (shows current pitch/yaw/roll)
- Optional: wireframe cockpit overlay

**Right Panel - Data Values:**

*RAW Values (from iOS directly):*
- Pitch: +33.2°
- Yaw: +3.1°
- Roll: -5.6°
- Timestamp

*FILTERED Values (after One Euro filter):*
- Pitch: +33.0°
- Yaw: +3.0°
- Roll: -5.5°

*OUTPUT Values (to X-Plane):*
- Pitch: +25.0°
- Yaw: +90.0°
- Roll: 0.0°

**Bottom Bar:**
- Recent packets log (scrollable, last 10)
- Clear log button

### Screen: Packet Inspector
**Purpose:** Deep dive into individual packets

**Layout:**
- Packet list (timestamp, size, protocol)
- Selected packet detail view:
  - Hex dump
  - Parsed values
  - Raw bytes with labels

---

## 2.2 Settings Screens

### Screen: Filter Settings
**Purpose:** Configure One Euro Filter parameters

**Layout:**
- Title: "Filter Settings"
- **Parameters:**
  - Min Cutoff (slider: 0.1 - 10.0 Hz)
  - Beta (slider: 0.0 - 2.0)
  - Derivative Cutoff (slider: 0.1 - 10.0 Hz)
- Visual: Shows filter response curve
- Presets:
  - "Responsive" (low smoothing)
  - "Balanced" (default)
  - "Smooth" (high smoothing)
- Reset button

### Screen: Axis Configuration
**Purpose:** Configure each axis (pitch, yaw, roll)

**Layout (tabbed or segmented control):**
- Axis selector: Pitch / Yaw / Roll

For each axis:
- Enable toggle
- Deadzone (slider: 0° - 10°)
- Max Input (slider: 10° - 90°)
- Max Output (slider: 10° - 180°)
- Curve Power (slider: 0.5 - 3.0)
- Invert toggle
- Visual: Input/output curve graph

### Screen: Connection Settings
**Purpose:** Configure receiving parameters

**Layout:**
- Listen Port (default: 4242)
- Auto-connect toggle
- Forward to X-Plane toggle
- Forward port (if enabled)

---

## 2.3 Utility Screens

### Screen: Log Viewer
**Purpose:** Application logs

**Layout:**
- Log level filter (Debug / Info / Warning / Error)
- Searchable log list
- Clear logs button
- Export logs button

### Screen: About Debugger
**Purpose:** App information

**Layout:**
- App icon and name
- Version
- GitHub link
- Build info (date, branch)

---

# Part 3: X-Plane Plugin

## No UI Required

The X-Plane plugin works **completely invisibly**. It:

1. Loads automatically when X-Plane starts
2. Listens on UDP port 4242 for head tracking data
3. Applies data to X-Plane's cockpit view datarefs
4. No configuration UI needed in X-Plane

**User Setup in X-Plane:**
- Enable head tracking input in X-Plane Settings → Input Devices
- That's it!

---

# Part 4: User Flows

## Flow 1: First Time Setup (iOS)
```
Welcome → Camera Permission → Local Network Permission → Main (prompted to start)
```

## Flow 2: Start Tracking with Debugger (Development)
```
Main → Settings → Protocol: OpenTrack → Target IP: Mac IP → Save → Start → (Debugger shows data)
```

## Flow 3: Start Tracking with X-Plane (Flight)
```
Main → Settings → Protocol: OpenTrack → Target IP: Mac IP → Save → Start → X-Plane receives data
```

## Flow 4: Recenter During Flight
```
(Tap screen anywhere) → Position reset to neutral
```

## Flow 5: Debug Issue
```
Start tracking → Open Debugger → Check RAW/FILTERED/OUTPUT → Adjust filter settings → Test again
```

---

# Part 5: Design Assets Required

## Icons Needed
- App icons (iOS: 1024x1024, macOS: 512x512 @1x and @2x)
- Menu bar icon for macOS (if applicable)

## SF Symbols Used
### iOS
- `face.smiling` - Face detected
- `face.dashed` - No face
- `antenna.radiowaves.left.and.right` - Connected
- `wifi.slash` - Disconnected
- `gearshape` - Settings
- `play.fill` - Start
- `stop.fill` - Stop
- `arrow.counterclockwise` - Recenter
- `info.circle` - About
- `questionmark.circle` - Help
- `camera` - Camera permission
- `network` - Network permission

### macOS
- `antenna.radiowaves.left.and.right`
- `wifi.slash`
- `gearshape`
- `arrow.triangle.2.circlepath`
- `chart.bar` - Statistics
- `doc.text` - Logs

## Color Palette (CSS/Swift)
```swift
// Primary Colors
Color.primary = Color(hex: "#007AFF")  // Blue
Color.success = Color(hex: "#34C759")  // Green
Color.warning = Color(hex: "#FFCC00")  // Yellow
Color.error = Color(hex: "#FF3B30")    // Red

// Backgrounds
Color.backgroundDark = Color(black: 0.1)
Color.surfaceDark = Color(black: 0.15)
Color.cardDark = Color(black: 0.2)

// Text
Color.textPrimary = Color.white
Color.textSecondary = Color.gray
```

---

# Summary: Screen Count

## iOS App
1. Welcome / Onboarding (3-4 screens)
2. Main Tracking Screen (1 screen + overlay)
3. Settings List (1 screen)
4. Protocol Detail (1 screen)
5. Calibration (1 screen)
6. About (1 screen)
7. Help/FAQ (1 screen)

**Total iOS: ~10 screens**

## macOS Debugger
1. Main Debug View (1 screen)
2. Packet Inspector (1 screen)
3. Filter Settings (1 screen)
4. Axis Configuration (1 screen)
5. Connection Settings (1 screen)
6. Log Viewer (1 screen)
7. About (1 screen)

**Total macOS: ~7 screens**

## X-Plane Plugin
0 screens (no UI)

**Grand Total: ~17 screens**

---

*Document Version: 1.0*
*Last Updated: April 2026*
