# LidarSight XP - Design Briefing

## Project Overview

**Project Name:** LidarSight XP  
**Type:** iOS App + macOS X-Plane Plugin  
**Core Functionality:** 6DoF head-tracking for X-Plane 12 flight simulator using iPhone front camera  
**Target Users:** Flight sim enthusiasts who want immersive cockpit head tracking without expensive VR hardware

---

## Design Philosophy

### Primary Design Goals

1. **Glanceability** - Information readable at a glance during flight
2. **Minimal Interaction** - Single-hand operation, buttons within thumb reach
3. **Non-Intrusive** - UI fades away when not needed (stealth mode)
4. **Glassmorphism** - Modern iOS aesthetic that feels native

### Secondary Goals

- Professional appearance suitable for screenshots/streams
- Low cognitive load - no complex menus during flight
- Fast setup - be tracking within 30 seconds

---

## Visual Design

### Color Palette

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Background | Camera feed | - | AR scene passthrough |
| Primary | System White | #FFFFFF | Text, icons |
| Accent | System Green | #34C759 | Tracking active |
| Warning | System Red | #FF3B30 | No face detected |
| Caution | System Yellow | #FFCC00 | Permission needed |
| Surface | Blur + 20% white | - | Glass buttons, pills |

### Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Status Text | SF Pro | 12pt | Regular |
| Button Label | SF Pro | 10pt | Medium |
| Data Overlay | SF Mono | 11pt | Regular |
| Section Header | SF Pro | 13pt | Semibold |
| Settings Title | SF Pro | 17pt | Semibold |

### Spacing System (8pt Grid)

- Screen edge padding: 16pt
- Element spacing: 8pt
- Button internal padding: 12pt horizontal, 8pt vertical
- Glass tray height: 88pt
- Status pill padding: 12pt × 6pt

### Visual Effects

- **Glassmorphism:** `.ultraThinMaterial` blur background on all UI elements
- **Shadows:** None (blur provides depth)
- **Corner Radius:**
  - Pills/Capsules: Fully rounded (height/2)
  - Buttons: 12pt
  - Large cards: 20pt
  - Sheet: System default
- **Animations:**
  - Stealth dim: 500ms ease-in-out
  - Wake from stealth: 300ms ease-in-out
  - Button press: System default spring

---

## Layout

### Main Screen Layout

```
┌────────────────────────────────────────┐  ← 0pt (safe area top)
│  ○ Tracking        ● UDP: 192.168.1.5  │  ← 16pt
├────────────────────────────────────────┤
│                                        │
│                                        │
│           [AR Camera View]             │  ← 40% opacity
│                                        │
│                                        │
│              ┌──────────┐              │
│              │  Start   │              │  ← Center
│              │ Tracking │              │
│              └──────────┘              │
│                                        │
├────────────────────────────────────────┤  ← Screen height - 100pt
│  [Calibrate] [Recenter] [Settings]     │  ← Glass tray
└────────────────────────────────────────┘  ← 8pt from bottom
```

### Settings Sheet Layout

Standard iOS Form with grouped sections:
- Tracking Mode (segmented control)
- Parameters (4 sliders with labels)
- Eye Tracking (1 slider)
- Connection (1 toggle)
- Info (read-only fields)

---

## UI Components

### 1. Status Pill
- Rounded capsule shape
- Contains: status dot (8-12pt) + text label
- Background: ultraThinMaterial
- Position: Top edge, 16pt from safe area

### 2. Start Button
- Large centered button (120pt × 100pt)
- Contains: SF Symbol icon (40pt) + label text
- Background: ultraThinMaterial, 20pt corner radius
- Only visible when NOT tracking

### 3. Glass Tray
- Fixed bottom bar (88pt height)
- 3 evenly-spaced glass buttons
- Background: ultraThinMaterial, 24pt top corners
- Always visible

### 4. Glass Button
- Fixed size: 70pt × 60pt
- Contains: SF Symbol icon (20pt) + label (10pt)
- Background: ultraThinMaterial, 12pt corner radius
- No border, no shadow

### 5. Data Overlay (Tracking Mode)
- Shows X, Y, Z position
- Shows Pitch, Yaw, Roll angles
- Font: SF Mono 11pt
- Background: ultraThinMaterial, 8pt corner radius
- Position: Above glass tray when tracking

### 6. Settings Sliders
- Standard iOS Slider with custom labels
- Value displayed right-aligned
- Description text below (caption size)
- Section header for grouping

---

## Interaction Design

### Touch Targets

- Minimum touch target: 44pt × 44pt (Apple HIG)
- Glass buttons: 70pt × 60pt ✓
- Settings rows: Full width ✓

### Gestures

| Gesture | Location | Action |
|---------|----------|--------|
| Tap | Start button | Begin tracking |
| Tap | Calibrate | Save current position |
| Tap | Recenter | Reset to origin |
| Tap | Settings | Open sheet |
| Drag | Sliders | Adjust values |
| Swipe down | Settings sheet | Dismiss |

### Haptic Feedback

- Light impact on calibration save
- Light impact on recenter
- No feedback on start/stop (distraction-free)

---

## Responsive Behavior

### Device Support

| Device | Screen Size | Layout Adaptation |
|--------|-------------|-------------------|
| iPhone SE (1st) | 320pt width | Stacked, smaller buttons |
| iPhone 8/SE 2-3 | 375pt width | Standard |
| iPhone Plus | 414pt width | Wider spacing |
| iPhone Mini | 360pt width | Standard |
| iPhone 13-15 | 393pt width | Standard |

### Orientation

- **Primary:** Portrait (seated usage)
- **Secondary:** LandscapeLeft (optional, same layout)
- Not supported: LandscapeRight (thumb reach issues)

---

## Animations

### Stealth Mode Transition
```swift
// Fade out (500ms)
withAnimation(.easeInOut(duration: 0.5)) {
    opacity = 0.3
}

// Fade in (300ms)  
withAnimation(.easeInOut(duration: 0.3)) {
    opacity = 1.0
}
```

### Button Press
- System default: Scale down 2%, 100ms

### Settings Sheet
- Standard iOS sheet presentation (drag to dismiss)

---

## Accessibility

### VoiceOver Support
- All buttons have accessibility labels
- Status indicators announce state changes
- Sliders have value announcements

### Dynamic Type
- Supports up to xxxLarge
- Minimum: Body text scales, buttons fixed

### Reduce Motion
- Stealth mode fades disable if Reduce Motion enabled

---

## Assets Required

### SF Symbols Used
| Symbol | Usage |
|--------|-------|
| person.fill | Head Only mode |
| eye.fill | Eyes Only mode |
| person.fill.badge.plus | Head + Eyes mode |
| light.min | LiDAR mode |
| scope | Calibrate |
| arrow.counterclockwise | Recenter |
| gearshape | Settings |

### App Icon
- Required sizes: 1024×1024 (App Store), @2x/@3x for devices
- Design: Camera lens + eye symbol, blue gradient
- (Future: Custom icon design needed)

---

## Success Metrics

### Visual Checkpoints
- [ ] AR camera feed visible at 40% opacity
- [ ] Status pills visible and readable
- [ ] Start button centered and tappable
- [ ] Glass tray at bottom, always visible
- [ ] Stealth mode dims UI after 10s idle
- [ ] Settings sheet slides up smoothly
- [ ] All text legible in low light (cockpit)

### Interaction Checkpoints
- [ ] Tap start → tracking begins within 2 seconds
- [ ] Calibration saves position immediately
- [ ] Recenter resets in under 100ms
- [ ] Settings changes apply immediately
- [ ] No accidental touches during flight

---

## Future Design Considerations

### v2.0 Ideas
- Dark mode: Replace glass with tinted dark blur
- Widget: Home screen quick start
- Watch app: Basic status view
- Siri: "Recenter view" voice command
- Multi-camera: Front + back for wider FOV
