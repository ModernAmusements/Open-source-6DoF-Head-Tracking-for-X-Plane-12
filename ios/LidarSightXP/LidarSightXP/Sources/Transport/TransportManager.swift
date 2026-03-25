import Foundation
import Network
import Combine

@MainActor
class TransportManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isUSBConnected: Bool = false
    @Published var localIP: String = "0.0.0.0"
    @Published var udpPort: UInt16 = 4242
    
    private var listener: NWListener?
    private var packetId: UInt32 = 0
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
                    case .cancelled:
                        self?.connectionStatus = .disconnected
                    default:
                        break
                    }
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
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
        
        var packet = HeadPosePacket()
        packet.packetId = packetId
        packet.timestampUs = Float(pose.timestamp * 1_000_000)
        packet.x = (pose.position.x - calibrationOffset.position.x) * settings.sensitivity
        packet.y = (pose.position.y - calibrationOffset.position.y) * settings.sensitivity
        packet.z = (pose.position.z - calibrationOffset.position.z) * settings.sensitivity
        packet.pitch = (pose.rotation.x - calibrationOffset.rotation.x) * settings.sensitivity
        packet.yaw = (pose.rotation.y - calibrationOffset.rotation.y) * settings.sensitivity
        packet.roll = (pose.rotation.z - calibrationOffset.rotation.z) * settings.sensitivity
        
        let isCalibrated = calibrationOffset != CalibrationOffset()
        packet.setFlag(.calibrated, isCalibrated)
        packet.setFlag(.trackingValid, pose.isValid)
        
        let data = packet.toData()
        
        if isUSBConnected {
            sendOverPeerTalk(data)
        } else {
            broadcastPacket(data)
        }
    }
    
    private func broadcastPacket(_ data: Data) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("255.255.255.255"),
            port: NWEndpoint.Port(rawValue: udpPort)!
        )
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        let connection = NWConnection(to: endpoint, using: params)
        connection.send(content: data, completion: .contentProcessed { _ in })
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
