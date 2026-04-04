import Foundation
import Network
import Combine

@MainActor
class TransportManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isUSBConnected: Bool = false
    @Published var localIP: String = "0.0.0.0"
    @Published var tcpPort: UInt16 = 4242 {
        didSet {
            print("DEBUG: tcpPort changed to \(tcpPort)")
        }
    }
    @Published var needsLocalNetworkPermission: Bool = false
    
    private var tcpConnection: NWConnection?
    private let connectionQueue = DispatchQueue(label: "tcpconnection", qos: .userInitiated)
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
        sendRecenterPacket()
    }
    
    func resetCalibration() {
        setCalibration(CalibrationOffset())
        saveCalibration()
        sendRecenterPacket()
    }
    
    private func sendRecenterPacket() {
        guard connectionStatus == .connected || isUSBConnected else { return }
        
        var packet = HeadPosePacket()
        packet.packetId = 0
        packet.timestampUs = 0
        packet.pitch = 0
        packet.yaw = 0
        packet.roll = 0
        packet.setFlag(.recenter, true)
        packet.setFlag(.trackingValid, true)
        
        let data = packet.toData()
        
        if isUSBConnected {
            sendOverPeerTalk(data)
        } else {
            sendOverTCP(data)
        }
        
        hasFirstPose = false
        print("DEBUG: Sent recenter packet to plugin")
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
    
    func startTCPServerIfReady() {
        guard !needsLocalNetworkPermission else { return }
        startTCPServer()
    }
    
    func startTCPServer() {
        print("DEBUG: startTCPServer called")
        connectionStatus = .connecting
        updateLocalIP()
        connectToMac()
    }
    
    func stopTCPServer() {
        tcpConnection?.cancel()
        tcpConnection = nil
        browser?.cancel()
        browser = nil
        connectionStatus = .disconnected
    }
    
    private func connectToMac() {
        let targetIP: String
        if !settings.targetIP.isEmpty && settings.targetIP != "0.0.0.0" {
            targetIP = settings.targetIP
        } else {
            let localIP = getLocalNetworkIP()
            print("DEBUG: Device local IP: \(localIP)")
            
            connectionStatus = .error("Enter Mac IP in Settings")
            print("DEBUG: No target IP configured. Please enter your Mac's IP in Settings.")
            return
        }
        
        guard targetIP != "0.0.0.0" else {
            print("DEBUG: No valid target IP")
            connectionStatus = .error("No target IP")
            return
        }
        
        print("DEBUG: Connecting to \(targetIP):\(tcpPort)")
        
        let host = NWEndpoint.Host(targetIP)
        let port = NWEndpoint.Port(rawValue: tcpPort)!
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        tcpConnection = NWConnection(host: host, port: port, using: parameters)
        
        print("DEBUG: Created TCP connection, setting up state handler...")
        
        tcpConnection?.stateUpdateHandler = { [weak self] state in
            print("DEBUG: TCP state changed: \(state)")
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("DEBUG: TCP Connected!")
                    self?.connectionStatus = .connected
                case .failed(let error):
                    print("DEBUG: TCP Connection failed: \(error)")
                    self?.connectionStatus = .error(error.localizedDescription)
                    self?.reconnectAfterDelay()
                case .cancelled:
                    print("DEBUG: TCP Cancelled")
                    self?.connectionStatus = .disconnected
                case .waiting(let error):
                    print("DEBUG: TCP Waiting: \(error)")
                case .setup:
                    print("DEBUG: TCP Setup")
                case .preparing:
                    print("DEBUG: TCP Preparing")
                default:
                    print("DEBUG: TCP Unknown state: \(state)")
                    break
                }
            }
        }
        
        print("DEBUG: Starting TCP connection...")
        tcpConnection?.start(queue: connectionQueue)
        print("DEBUG: TCP connection start called")
    }
    
    private func reconnectAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard self?.connectionStatus != .connected else { return }
            self?.connectToMac()
        }
    }
    
    private func getLocalNetworkIP() -> String {
        var address = "0.0.0.0"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return address }
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
        
        return address
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
            
            // Note: calibration is already applied in ARTrackingManager via CalibrationManager
            // So we use pose.rotation directly (which is already relative to calibration)
            // However, if calibration wasn't applied, apply it here
            let rawPitch: Float
            let rawYaw: Float
            let rawRoll: Float
            
            if calibrationOffset != CalibrationOffset() {
                // Calibration already applied, use as-is
                rawPitch = normalizeAngle(pose.rotation.x)
                rawYaw = normalizeAngle(pose.rotation.y)
                rawRoll = normalizeAngle(pose.rotation.z)
            } else {
                // Apply calibration manually
                rawPitch = normalizeAngle(pose.rotation.x - calibrationOffset.rotation.x)
                rawYaw = normalizeAngle(pose.rotation.y - calibrationOffset.rotation.y)
                rawRoll = normalizeAngle(pose.rotation.z - calibrationOffset.rotation.z)
            }
            
            print("DEBUG sendPose: raw pitch=\(rawPitch) yaw=\(rawYaw) roll=\(rawRoll), calibrationOffset=\(calibrationOffset.rotation)")
            
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
            
            print("DEBUG sendPose: raw=(\(rawPitch), \(rawYaw), \(rawRoll)) -> smoothed=(\(packet.pitch), \(packet.yaw), \(packet.roll))")
            
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
            sendOverTCP(data)
        }
    }
    
    private func sendOverTCP(_ data: Data) {
        guard let connection = tcpConnection, connection.state == .ready else {
            print("DEBUG TCP not ready, triggering reconnect")
            connectionStatus = .disconnected
            reconnectAfterDelay()
            return
        }
        
        var length = UInt32(data.count).bigEndian
        var packetData = Data(bytes: &length, count: 4)
        packetData.append(data)
        
        connection.send(content: packetData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("DEBUG: TCP send error: \(error)")
                self?.connectionStatus = .disconnected
                self?.reconnectAfterDelay()
            }
        })
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
    
    func stop() {
        tcpConnection?.cancel()
        tcpConnection = nil
        browser?.cancel()
        browser = nil
        connectionStatus = .disconnected
        hasFirstPose = false
        lastPitch = 0
        lastYaw = 0
        lastRoll = 0
    }
}
