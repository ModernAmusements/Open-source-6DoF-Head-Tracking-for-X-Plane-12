import Foundation
import Network
import Combine

@MainActor
class TransportManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isUSBConnected: Bool = false
    @Published var localIP: String = "0.0.0.0"
    @Published var udpPort: UInt16 = 4242
    
    private var udpConnection: NWConnection?
    private var listener: NWListener?
    
    private var packetId: UInt32 = 0
    private var calibrationOffset: CalibrationOffset = .zero
    private var settings: TrackingSettings = .default
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
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
        setCalibration(.zero)
        saveCalibration()
    }
    
    private func saveCalibration() {
        if let data = try? JSONEncoder().encode(calibrationOffset) {
            UserDefaults.standard.set(data, forKey: "calibrationOffset")
        }
    }
    
    private func loadCalibration() {
        if let data = UserDefaults.standard.data(forKey: "calibrationOffset"),
           let saved = try? JSONDecoder().decode(CalibrationOffset.self, from: data) {
            calibrationOffset = saved
        }
    }
    
    // MARK: - UDP Transport
    
    func startUDPServer() {
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: udpPort)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.connectionStatus = .connected
                        self?.updateLocalIP()
                    case .failed(let error):
                        self?.connectionStatus = .error(error.localizedDescription)
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }
            
            listener?.start(queue: .main)
            connectionStatus = .connecting
            
        } catch {
            connectionStatus = .error(error.localizedDescription)
        }
    }
    
    func stopUDPServer() {
        listener?.cancel()
        listener = nil
        connectionStatus = .disconnected
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(from: connection)
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] data, _, isComplete, _ in
            if let _ = data {
                // Handle commands from Mac plugin (recenter, etc.)
            }
            if !isComplete {
                Task { @MainActor in
                    self?.receiveData(from: connection)
                }
            }
        }
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
    
    // MARK: - Send Pose
    
    func sendPose(_ pose: HeadPose) {
        guard connectionStatus == .connected || isUSBConnected else { return }
        
        packetId += 1
        
        var packet = HeadPosePacket()
        packet.packetId = packetId
        packet.timestampUs = pose.timestamp * 1_000_000
        packet.x = (pose.position.x - calibrationOffset.position.x) * settings.sensitivity
        packet.y = (pose.position.y - calibrationOffset.position.y) * settings.sensitivity
        packet.z = (pose.position.z - calibrationOffset.position.z) * settings.sensitivity
        packet.pitch = (pose.rotation.x - calibrationOffset.rotation.x) * settings.sensitivity
        packet.yaw = (pose.rotation.y - calibrationOffset.rotation.y) * settings.sensitivity
        packet.roll = (pose.rotation.z - calibrationOffset.rotation.z) * settings.sensitivity
        
        packet.setFlag(.calibrated, calibrationOffset != .zero)
        packet.setFlag(.trackingValid, pose.isValid)
        
        let data = packet.toData()
        
        if isUSBConnected {
            sendOverPeerTalk(data)
        } else {
            sendOverUDP(data)
        }
    }
    
    private func sendOverUDP(_ data: Data) {
        guard let listener = listener else { return }
        
        for connection in listener.connectedEndpoints {
            let conn = NWConnection(to: connection, using: .udp)
            conn.send(content: data, completion: .idempotent)
        }
    }
    
    private func sendOverPeerTalk(_ data: Data) {
        // PeerTalk implementation - requires PeerTalk framework
        // Will be implemented with CocoaPods integration
    }
}
