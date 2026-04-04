# Session Summary - April 4, 2026

## Overview

Working on end-to-end head tracking: iOS app → Mac debugger → X-Plane plugin.

---

## Session 1: Initial Setup (March 30)

### Problem
iOS was blocking UDP packets to local network IPs.

### Solution
Switched from UDP to TCP for iOS→Mac communication.

---

## Session 2: Code Review (March 30)

### Bugs Found and Fixed
1. Swift struct padding in HeadPosePacket
2. Double calibration bug
3. Config loading in plugin
4. Calibration sync between iOS and plugin
5. Network cleanup (iOS stop method)
6. Thread cleanup (plugin flight data thread)

---

## Session 3: Testing - Port Mismatch (March 30)

### Issue
- iOS sending to port 4242
- Debugger listening on port 4243 (typo)

### Fix
- Changed debugger default port to 4242

---

## Session 4: Testing - ARKit Getting Stuck (March 30)

### Issue
iOS sending constant values - ARKit callbacks stop firing after first few frames.

### Symptoms
- Values: pitch=6.91 yaw=5.86 roll=-5.26 (constant, never changing)
- Tracking works for 1 second then "stuck"

### Debugging
1. Added extensive debug logging to ARTrackingManager
2. Found ARKit session stops providing new face anchor updates
3. Tracking state shows "normal" but no new data

### Root Cause
ARKit face tracking appears to stop sending updates after a few seconds - known iOS issue.

### Solution Added
1. Stuck detection - if rotation unchanged for 60+ frames, restart AR session
2. Force send timer - send data every 100ms even if ARKit stops updating

---

## Session 5: Testing - TCP Connection Issues (March 30)

### Issues
1. iOS connecting to wrong IP (itself instead of Mac)
2. Debugger not handling reconnection properly
3. "Address already in use" error

### Fixes
1. Added UI for user to enter Mac IP in settings
2. Improved TCP reconnection logic
3. Fixed listener cleanup on reconnect

---

## Session 6: Testing - Data Flow Working (March 30)

### Status
- Data flowing: iOS → TCP → Debugger
- Debugger shows: pitch=31.6°, yaw=36°, roll=-0.3°
- But OUTPUT values showing 0,0,0

### Issue - OUTPUT values all zeros
- RAW VALUES: +31.6°, +36.0°, -0.3°
- FILTERED: same as RAW
- OUTPUT: 0, 0, 0

### Likely Causes
1. hasInitialPose flag incorrectly set
2. Deadzone settings blocking output
3. applyCurve returning 0

---

## Current State (April 4, 2026)

### What's Working
- ✅ iOS ARKit face tracking (with stuck detection workaround)
- ✅ TCP connection iOS → Mac debugger (port 4242)
- ✅ Data displaying in debugger RAW VALUES
- ✅ Force-send timer keeps data flowing when ARKit stalls

### Remaining Issue
- ❌ OUTPUT values in debugger showing all zeros
- Debug logging added to trace the issue

---

## Files Modified (This Session)

### iOS
- `LidarSightXP/Sources/AR/ARTrackingManager.swift`
  - Added stuck detection and session restart
  - Added force-send timer
  - Added debug logging

- `LidarSightXP/Sources/Transport/TransportManager.swift`
  - Improved TCP error handling
  - Added debug logging

### macOS Debugger
- `HeadTrackerDebugger/Views/ContentView.swift`
  - Fixed port from 4243 to 4242
  - Added debug logging for packet processing

- `HeadTrackerDebugger/Views/StatusPanel.swift`
  - Fixed hardcoded port display

- `HeadTrackerDebugger/Network/TCPListener.swift`
  - Fixed default port to 4242
  - Improved reconnection handling

- `HeadTrackerDebugger/Models/Shared.swift`
  - Port default 4242

---

## Commits

- `1906a1a` - Fix ARKit tracking stuck issue and improve TCP reliability
- `f581cd6` - Update conversation log with debugging sessions
