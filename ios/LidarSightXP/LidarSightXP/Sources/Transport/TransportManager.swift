import Foundation
import Network
import Combine

@MainActor
class TransportManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isUSBConnected: Bool = false
    @Published var localIP: String = "0.0.0.0"
    @Published var udpPort: UInt16 = 4242
    @Published var needsLocalNetworkPermission: Bool = false
    
    private var listener: NWListener?
    private var broadcastConnection: NWConnection?
    private var packetId: UInt32 = 0
    private var browser: NWBrowser?
    var calibrationOffset: CalibrationOffset = CalibrationOffset()
    var settings: TrackingSettings = TrackingSettings()
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected): return true
            case (.connecting, .connecting): return true
            case (.connected, .connected): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }
    
    init() {
        loadSettings()
        loadCalibration()
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "trackingSettings"),
           let saved = try? JSONDecoder().decode(TrackingSettings.self, from: data) {
            settings = saved
        }
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "trackingSettings")
        }
    }
    
    func updateSettings(_ newSettings: TrackingSettings) {
        settings = newSettings
        saveSettings()
    }
    
    func setCalibration(_ offset: CalibrationOffset) {
        calibrationOffset = offset
    }
    
    func calibrate(pose: HeadPose) {
        let offset = CalibrationOffset(
            position: pose.position,
            rotation: pose.rotation
        )
        setCalibration(offset)
        saveCalibration()
    }
    
    func resetCalibration() {
        setCalibration(CalibrationOffset())
        saveCalibration()
    }
    
    func saveCalibration() {
        if let data = try? JSONEncoder().encode(calibrationOffset) {
            UserDefaults.standard.set(data, forKey: "calibrationOffset")
        }
    }
    
    func loadCalibration() {
        if let data = UserDefaults.standard.data(forKey: "calibrationOffset"),
           let saved = try? JSONDecoder().decode(CalibrationOffset.self, from: data) {
            calibrationOffset = saved
        }
    }
    
    func requestLocalNetworkPermission(completion: @escaping () -> Void) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_lidarsight._udp", domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    self?.needsLocalNetworkPermission = false
                    completion()
                }
            case .failed(let error):
                print("Browser failed: \(error)")
                DispatchQueue.main.async {
                    self?.needsLocalNetworkPermission = true
                }
            default:
                break
            }
        }
        
        browser?.start(queue: .global(qos: .userInitiated))
        needsLocalNetworkPermission = true
    }
    
    func startUDPServerIfReady() {
        guard !needsLocalNetworkPermission else { return }
        startUDPServer()
    }
    
    func startUDPServer() {
        connectionStatus = .connected
        updateLocalIP()
        setupBroadcastConnection()
    }
    
    func stopUDPServer() {
        listener?.cancel()
        listener = nil
        broadcastConnection?.cancel()
        broadcastConnection = nil
        connectionStatus = .disconnected
    }
    
    private func updateLocalIP() {
        var address = "0.0.0.0"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        
        localIP = address
    }
    
    func sendPose(_ pose: HeadPose) {
        guard connectionStatus == .connected || isUSBConnected else { return }
        
        packetId += 1
        
        let data: Data
        
        if settings.protocolMode == .openTrack {
            let opPacket = OpenTrackPacket(from: pose, settings: settings, calibration: calibrationOffset)
            data = opPacket.toData()
        } else {
            var packet = HeadPosePacket()
            packet.packetId = packetId
            packet.timestampUs = Float(pose.timestamp * 1_000_000)
            
            let useEyeRotation = settings.trackingMode.usesEyeTracking && pose.eyeRotation != nil
            let eyeWeight: Float = 0.3
            
            let finalRotation: SIMD3<Float>
            
            if useEyeRotation, let eyeRot = pose.eyeRotation {
                let eyeOffset = SIMD3<Float>(
                    (eyeRot.x - calibrationOffset.rotation.x) * settings.eyeSensitivity,
                    (eyeRot.y - calibrationOffset.rotation.y) * settings.eyeSensitivity,
                    (eyeRot.z - calibrationOffset.rotation.z) * settings.eyeSensitivity
                )
                
                switch settings.trackingMode {
                case .eyesOnly:
                    finalRotation = eyeOffset
                case .headAndEyes:
                    let headRot = SIMD3<Float>(
                        (pose.rotation.x - calibrationOffset.rotation.x) * settings.sensitivity,
                        (pose.rotation.y - calibrationOffset.rotation.y) * settings.sensitivity,
                        (pose.rotation.z - calibrationOffset.rotation.z) * settings.sensitivity
                    )
                    finalRotation = SIMD3<Float>(
                        headRot.x + eyeOffset.x * eyeWeight,
                        headRot.y + eyeOffset.y * eyeWeight,
                        headRot.z + eyeOffset.z * eyeWeight
                    )
                default:
                    finalRotation = SIMD3<Float>(
                        (pose.rotation.x - calibrationOffset.rotation.x) * settings.sensitivity,
                        (pose.rotation.y - calibrationOffset.rotation.y) * settings.sensitivity,
                        (pose.rotation.z - calibrationOffset.rotation.z) * settings.sensitivity
                    )
                }
            } else {
                finalRotation = SIMD3<Float>(
                    (pose.rotation.x - calibrationOffset.rotation.x) * settings.sensitivity,
                    (pose.rotation.y - calibrationOffset.rotation.y) * settings.sensitivity,
                    (pose.rotation.z - calibrationOffset.rotation.z) * settings.sensitivity
                )
            }
            
            let rawX = (pose.position.x - calibrationOffset.position.x) * settings.sensitivity
            let rawY = (pose.position.y - calibrationOffset.position.y) * settings.sensitivity
            let rawZ = (pose.position.z - calibrationOffset.position.z) * settings.sensitivity
            
            packet.x = applyRangeMapping(rawX)
            packet.y = applyRangeMapping(rawY)
            packet.z = applyRangeMapping(rawZ)
            packet.pitch = applyAngleClamp(finalRotation.x)
            packet.yaw = applyAngleClamp(finalRotation.y)
            packet.roll = applyAngleClamp(finalRotation.z)
            
            let isCalibrated = calibrationOffset != CalibrationOffset()
            packet.setFlag(.calibrated, isCalibrated)
            packet.setFlag(.trackingValid, pose.isValid)
            
            data = packet.toData()
        }
        
        if isUSBConnected {
            sendOverPeerTalk(data)
        } else {
            broadcastPacket(data)
        }
    }
    
    private func applyAngleClamp(_ angle: Float) -> Float {
        let maxA = settings.maxAngle
        if abs(angle) <= maxA {
            return angle
        }
        return maxA * (angle > 0 ? 1 : -1)
    }
    
    private func applyRangeMapping(_ value: Float) -> Float {
        let scale = settings.rangeScale
        let sign: Float = value >= 0 ? 1 : -1
        let absValue = abs(value)
        let mapped = pow(absValue, 1.0 + scale)
        return sign * mapped
    }
    
    private func setupBroadcastConnection() {
        // Skip broadcast setup - we'll send directly
        // The X-Plane plugin will receive on port 4242
        print("UDP setup complete - will broadcast to all addresses")
    }
    
    private func getBroadcastAddress() -> String {
        // Use simple broadcast to all interfaces
        return "255.255.255.255"
    }
    
    private func broadcastPacket(_ data: Data) {
        // Send to both broadcast and direct Mac IP for reliability
        let targets = ["255.255.255.255", settings.targetIP]
        
        for targetIP in targets {
            sendToTarget(data, host: targetIP)
        }
    }
    
    private func sendToTarget(_ data: Data, host: String) {
        guard let port = NWEndpoint.Port(rawValue: udpPort) else { return }
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: port
        )
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        let connection = NWConnection(to: endpoint, using: params)
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("Send error: \(error)")
                    }
                    connection.cancel()
                })
            case .failed(let error):
                print("Connection failed: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        
        connection.start(queue: .global(qos: .userInitiated))
    }
    
    private func sendOverPeerTalk(_ data: Data) {
        // PeerTalk implementation
    }
    
    func connectToUSB() {
        isUSBConnected = true
    }
    
    func disconnectFromUSB() {
        isUSBConnected = false
    }
}
