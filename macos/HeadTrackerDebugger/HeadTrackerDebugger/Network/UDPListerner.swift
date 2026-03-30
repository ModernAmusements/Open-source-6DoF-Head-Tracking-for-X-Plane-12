import Foundation
import Network
import Combine

class UDPListerner: ObservableObject {
    @Published var lastPacket: ParsedPacket?
    @Published var isConnected: Bool = false
    @Published var packetRate: Double = 0.0
    @Published var detectedProtocol: PacketProtocol = .lidarSight
    @Published var errorMessage: String?
    
    var onPacketReceived: ((ParsedPacket) -> Void)?
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "UDPListerner", qos: .userInitiated)
    private var packetCount: Int = 0
    private var lastRateUpdate: Date = Date()
    private var packetsInLastSecond: Int = 0
    
    private var port: UInt16 = 4242
    
    func start(port: UInt16 = 4242) {
        self.port = port
        stop()
        
        isConnected = true
        errorMessage = nil
        
        let host = NWEndpoint.Host("0.0.0.0")
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        print("UDPListerner: Starting on port \(port)")
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        connection = NWConnection(host: host, port: nwPort, using: params)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.errorMessage = nil
                    print("UDP Listener: Ready on port \(port)")
                case .failed(let error):
                    self?.isConnected = false
                    self?.errorMessage = "Failed: \(error)"
                    print("UDP Listener: Failed - \(error)")
                case .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: queue)
        receiveData()
    }
    
    func stop() {
        connection?.cancel()
        connection = nil
        isConnected = false
        packetCount = 0
        packetsInLastSecond = 0
        packetRate = 0
    }
    
    private func receiveData() {
        connection?.receiveMessage { [weak self] data, _, _, error in
            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data)
            }
            
            if error == nil {
                self?.receiveData()
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        print("UDPListerner: Received \(data.count) bytes")
        
        guard let packet = PacketParser.parse(data) else { 
            print("UDPListerner: Failed to parse packet, size = \(data.count)")
            return 
        }
        
        print("UDPListerner: Parsed packet - pitch=\(packet.pose.pitch) yaw=\(packet.pose.yaw) roll=\(packet.pose.roll)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.lastPacket = packet
            self.detectedProtocol = packet.packetProtocol
            self.packetCount += 1
            self.packetsInLastSecond += 1
            
            let now = Date()
            let elapsed = now.timeIntervalSince(self.lastRateUpdate)
            if elapsed >= 1.0 {
                self.packetRate = Double(self.packetsInLastSecond) / elapsed
                self.packetsInLastSecond = 0
                self.lastRateUpdate = now
            }
            
            self.onPacketReceived?(packet)
        }
    }
}
