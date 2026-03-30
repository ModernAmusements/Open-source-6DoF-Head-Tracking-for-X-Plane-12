LidarSight XP - 6DoF Head Tracking for X-Plane 12
Version 1.0

USAGE:
 1. Run LidarSight XP app on your iPhone
 2. Connect iPhone and Mac to same WiFi network
 3. Set your Mac's IP in iOS app Settings > Connection
 4. Start tracking in the iOS app
 5. Plugin receives head tracking data automatically

NETWORK:
 - iOS app connects to Mac via TCP on port 4243
 - Plugin forwards data to UDP broadcast on port 4242
   (for X-Plane native head tracking / OpenTrack)

TROUBLESHOOTING:
- Ensure firewall allows TCP port 4243 and UDP port 4242
- Check that both devices are on same network
- Restart X-Plane if plugin doesn't appear in menu

For support, visit: https://github.com/lidarsight/xp