# LidarSight XP - iOS User Flow

## Overview
The LidarSight XP iOS app is designed for single-handed use while seated in front of a flight simulator. The interface prioritizes glanceability and minimal interaction during flight.

---

## Primary User Flow

### 1. App Launch
```
┌─────────────────────────────────────┐
│                                     │
│         [App Icon]                  │
│         LidarSight XP               │
│                                     │
│    ┌─────────────────────────┐      │
│    │    Face Camera View    │      │
│    │    (40% opacity)       │      │
│    │                        │      │
│    │  ┌───┐                 │      │
│    │  │ ● │ No Face         │      │
│    │  └───┘                 │      │
│    │                        │      │
│    │   [ Start Tracking ]  │      │
│    │      Head Only        │      │
│    │                        │      │
│    │  [Calibrate] [Reset] [⚙] │      │
│    └─────────────────────────┘      │
└─────────────────────────────────────┘
```

### 2. First-Time Setup (Auto on First Launch)
1. App requests Local Network permission
2. User taps permission prompt → iOS shows permission dialog
3. App discovers X-Plane plugin via Bonjour
4. Ready indicator turns green

### 3. Start Tracking Flow
```
Tap "Start Tracking" → 
  → Check face detection → 
    → Begin ARKit session → 
      → Send UDP packets to X-Plane
```

### 4. In-Flight Usage
```
During Flight:
┌─────────────────────────────────────┐
│ [Tracking]      UDP: 192.168.1.x  │ ← Status bar
│                                     │
│    X: 0.00  Y: 0.00  Z: 0.00      │ ← Live data overlay
│    Pitch: 0°  Yaw: 0°  Roll: 0°   │   (toggleable)
│                                     │
│                                     │
│                                     │
│  [Calibrate] [Recenter] [Settings] │ ← Glass tray (always visible)
└─────────────────────────────────────┘
```

---

## Screens

### Screen 1: Main View (Default)
**Components:**
- AR camera background (40% opacity, full screen)
- Top-left: Face detection status pill (green/red dot + text)
- Top-right: Connection status pill (IP:Port or error)
- Center: Start button (when idle)
- Bottom: Glass tray with 3 action buttons

**States:**
| State | Start Button | Status | Tray |
|-------|-------------|--------|------|
| Idle | Visible | No Face (red) | Active |
| Tracking | Hidden | Tracking (green) | Active |
| No Face Lost | Hidden | No Face (red) | Active |
| Stealth Mode | Hidden | Tracking (green) | Dimmed to 30% |

---

### Screen 2: Settings Sheet
**Trigger:** Tap gear icon in glass tray

**Sections:**
1. **Tracking Mode** (segmented picker)
   - Head Only (default)
   - Eyes Only
   - Head + Eyes
   - LiDAR Mode (Pro devices)

2. **Parameters**
   - Sensitivity slider (0.5x - 2.0x)
   - Smoothing slider (0.1 - 1.0)
   - Max Angle slider (15° - 90°)
   - Range Curve slider (Linear - 1.0)

3. **Eye Tracking**
   - Eye Sensitivity slider (1.0x - 5.0x)

4. **Connection**
   - Stealth Mode toggle
   - IP Address display
   - Port display

5. **Info**
   - Current tracking status

---

## Action Flows

### Calibrate Flow
```
Tap "Calibrate" → 
  → Capture current head position as neutral → 
    → Save to UserDefaults → 
      → Send to X-Plane plugin → 
        → Apply offset to all future packets
```

### Recenter Flow
```
Tap "Recenter" → 
  → Reset calibration to origin (0,0,0) → 
    → Clear UserDefaults calibration → 
      → Notify X-Plane plugin
```

### Stealth Mode Flow
```
Idle for 10 seconds while tracking steady → 
  → UI dims to 30% opacity → 
    → Movement detected → 
      → UI returns to 100% opacity
```

---

## Error States

### Face Not Detected
- Status pill: Red "No Face"
- Packet transmission: Continues (last known position)
- User action: Position face in camera frame

### Network Permission Denied
- Status pill: Yellow "Tap to enable"
- Tap triggers permission request again

### Connection Failed
- Status pill: Red "Error: [message]"
- Auto-retry every 5 seconds
- Manual: Tap to force retry

---

## Quick Reference Card

| Action | Trigger | Result |
|--------|---------|--------|
| Start | Tap center button | Begin face tracking |
| Stop | (not available) | App runs continuously |
| Calibrate | Tap scope icon | Set current position as neutral |
| Recenter | Tap arrow icon | Reset to origin |
| Settings | Tap gear icon | Open settings sheet |
| Stealth | Auto | Dim after 10s idle |

---

## Edge Cases

1. **App backgrounded**: Tracking pauses, resumes on foreground
2. **USB cable disconnect**: Falls back to WiFi automatically
3. **Face lost**: Holds last position for 2 seconds, then centers
4. **Multiple iPhones**: Each broadcasts on same port (X-Plane accepts first)
5. **iOS crash**: Auto-reconnect on relaunch, restore calibration from UserDefaults
