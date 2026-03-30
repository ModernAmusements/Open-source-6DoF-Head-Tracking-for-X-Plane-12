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
    
    private var lastPitch: Float = 0
    private var lastYaw: Float = 0
    private var lastRoll: Float = 0
    private var hasFirstPose: Bool = false
    
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
        print("DEBUG: requestLocalNetworkPermission called")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_lidarsight._udp", domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("DEBUG: Browser ready - permission granted!")
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
        print("DEBUG: startUDPServer called")
        connectionStatus = .connected
        updateLocalIP()
        setupBroadcastConnection()
    }
    
    func stopUDPServer() {
        listener?.cancel()
        listener = nil
        broadcastConnection?.cancel()
        broadcastConnection = nil
        browser?.cancel()
        browser = nil
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
        guard connectionStatus == .connected || isUSBConnected else {
            print("DEBUG: sendPose skipped - connectionStatus=\(connectionStatus), isUSBConnected=\(isUSBConnected)")
            return
        }
        
        guard pose.isValid else {
            hasFirstPose = false
            return
        }
        
        packetId += 1
        
        let data: Data
        
        if settings.protocolMode == .openTrack {
            let opPacket = OpenTrackPacket(from: pose, settings: settings, calibration: calibrationOffset)
            data = opPacket.toData()
        } else {
            var packet = HeadPosePacket()
            packet.packetId = packetId
            packet.timestampUs = Float(pose.timestamp * 1_000_000)
            
            let normalizeAngle: (Float) -> Float = { angle in
                var a = angle.truncatingRemainder(dividingBy: 360)
                if a > 180 { a -= 360 }
                if a < -180 { a += 360 }
                return a
            }
            
            let rawPitch = normalizeAngle(pose.rotation.x - calibrationOffset.rotation.x)
            let rawYaw = normalizeAngle(pose.rotation.y - calibrationOffset.rotation.y)
            let rawRoll = normalizeAngle(pose.rotation.z - calibrationOffset.rotation.z)
            
            let alpha = max(0.0, min(1.0, 1.0 - settings.smoothing))
            
            if !hasFirstPose || settings.smoothing <= 0.01 {
                lastPitch = rawPitch
                lastYaw = rawYaw
                lastRoll = rawRoll
                hasFirstPose = true
            }
            
            packet.pitch = lastPitch + alpha * (rawPitch - lastPitch)
            packet.yaw = lastYaw + alpha * (rawYaw - lastYaw)
            packet.roll = lastRoll + alpha * (rawRoll - lastRoll)
            
            lastPitch = packet.pitch
            lastYaw = packet.yaw
            lastRoll = packet.roll
            
            packet.x = 0
            packet.y = 0
            packet.z = 0
            
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
        var targets: [String] = ["255.255.255.255"]
        
        if !settings.targetIP.isEmpty && settings.targetIP != "0.0.0.0" {
            targets.append(settings.targetIP)
        }
        
        for targetIP in targets {
            sendToTarget(data, host: targetIP)
        }
    }
    
    private func sendToTarget(_ data: Data, host: String) {
        guard !host.isEmpty, host != "0.0.0.0" else { return }
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
                print("DEBUG: Sending packet to \(host):\(port), size=\(data.count)")
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
