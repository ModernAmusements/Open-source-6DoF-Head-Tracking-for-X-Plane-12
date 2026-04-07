import Foundation
import Network
import Combine

class UDPListener: ObservableObject {
    @Published var lastPacket: ParsedPacket?
    @Published var isConnected: Bool = false
    @Published var packetRate: Double = 0.0
    @Published var detectedProtocol: PacketProtocol = .lidarSight
    @Published var errorMessage: String?
    
    var onPacketReceived: ((ParsedPacket) -> Void)?
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "UDPListener", qos: .userInitiated)
    private var packetCount: Int = 0
    private var lastRateUpdate: Date = Date()
    private var packetsInLastSecond: Int = 0
    
    private var port: UInt16 = 4242
    
    func start(port: UInt16 = 4242) {
        self.port = port
        stop()
        
        isConnected = true
        errorMessage = nil
        
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        print("UDPListener: Starting server on port \(port)")
        
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: params, on: nwPort)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isConnected = true
                        self?.errorMessage = nil
                        print("UDP Listener: READY on port \(port)")
                    case .failed(let error):
                        self?.isConnected = false
                        self?.errorMessage = "Failed: \(error)"
                        print("UDP Listener: FAILED - \(error)")
                    case .cancelled:
                        self?.isConnected = false
                        print("UDP Listener: CANCELLED")
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                print("UDP Listener: Received connection from \(connection.endpoint)")
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
            print("UDPListener: Listener started")
        } catch {
            errorMessage = "Failed to create listener: \(error.localizedDescription)"
            print("UDP Listener: Failed to create - \(error)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveData(from: connection)
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isConnected = false
        packetCount = 0
        packetsInLastSecond = 0
        packetRate = 0
    }
    
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let error = error {
                print("UDPListener: Receive ERROR - \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                print("UDPListener: Received \(data.count) bytes")
                print("UDPListener: First 16 bytes hex: \(data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
                self?.handleReceivedData(data)
            }
            
            self?.receiveData(from: connection)
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        print("UDPListener: Processing \(data.count) bytes")
        
        guard let packet = PacketParser.parse(data) else {
            print("UDPListener: Failed to parse packet, size = \(data.count)")
            return
        }
        
        print("UDPListener: Parsed packet - pitch=\(packet.pose.pitch) yaw=\(packet.pose.yaw) roll=\(packet.pose.roll)")
        
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
