# LidarSight XP - Testing Checklist

## Pre-Flight Checklist

### Hardware Setup
- [ ] iPhone connected to Mac via USB (for deployment)
- [ ] iPhone mounted on tripod, facing user (webcam style)
- [ ] iPhone and Mac on same WiFi network
- [ ] X-Plane 12 installed on Mac

### Software Setup
- [ ] iOS app built and deployed to iPhone
- [ ] Plugin installed: `~/Library/Application Support/X-Plane 12/Plugins/LidarSightXP.xpl/`

---

## Testing Steps

### 1. iOS App Test
- [ ] Launch LidarSightXP on iPhone
- [ ] Grant camera permission when prompted
- [ ] Tap "Start Tracking"
- [ ] Verify green "Tracking" indicator appears
- [ ] Check IP address shown in connection status

### 2. X-Plane Plugin Test
- [ ] Launch X-Plane 12
- [ ] Go to `Plugins` menu
- [ ] Verify "LidarSight XP" appears in list (no errors)
- [ ] Load any aircraft
- [ ] Enter cockpit view (press `C` or use View menu)

### 3. End-to-End Test
- [ ] On iPhone: Move your head left/right
- [ ] In X-Plane: Cockpit should pan left/right
- [ ] On iPhone: Nod up/down
- [ ] In X-Plane: View should tilt up/down
- [ ] On iPhone: Tilt head side to side
- [ ] In X-Plane: Head should roll

### 4. Calibration Test
- [ ] Sit in normal flying position
- [ ] Look at center of monitor
- [ ] Tap "Calibrate" button
- [ ] This becomes your neutral head position
- [ ] Test recenter by tapping "Recenter"

---

## Troubleshooting

### iOS App Issues

| Problem | Solution |
|---------|----------|
| "No Face" indicator | Ensure good lighting, face visible to camera |
| Red connection status | Check WiFi, ensure both on same network |
| App crashes | Check Console.app for crash logs |

### X-Plane Plugin Issues

| Problem | Solution |
|---------|----------|
| Plugin not in menu | Check Console.app for errors |
| Head not moving | Verify UDP port 4242 not blocked by firewall |
| Works in external view | Normal - plugin only activates in cockpit |
| No cockpit movement | Check view is type 1017 (3D cockpit) |

---

## Expected Behavior

- **Latency:** ~30-50ms over WiFi UDP
- **Smoothing:** One Euro filter should remove jitter
- **Range:** Depends on sensitivity setting (adjust in app)
- **Thermal:** App may throttle to 30fps if phone overheats

---

## Test Results

Record your test results:

| Test | Pass/Fail | Notes |
|------|------------|-------|
| Face detection | | |
| UDP connection | | |
| Head tracking X | | |
| Head tracking Y | | |
| Head tracking Z | | |
| Calibration | | |
| Recenter | | |

---

## Known Limitations

1. Only works in cockpit view
2. Range limited by aircraft 3D model
3. WiFi may have latency spikes
4. USB (PeerTalk) not yet implemented
