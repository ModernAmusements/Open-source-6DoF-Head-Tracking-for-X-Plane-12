import Foundation
import Network
import Combine

class TCPListener: ObservableObject {
    @Published var lastPacket: ParsedPacket?
    @Published var isConnected: Bool = false
    @Published var packetRate: Double = 0.0
    @Published var detectedProtocol: PacketProtocol = .lidarSight
    @Published var errorMessage: String?
    
    var onPacketReceived: ((ParsedPacket) -> Void)?
    
    private var listener: NWListener?
    private var clientConnection: NWConnection?
    private let queue = DispatchQueue(label: "TCPListener", qos: .userInitiated)
    private var packetCount: Int = 0
    private var lastRateUpdate: Date = Date()
    private var packetsInLastSecond: Int = 0
    
    private var port: UInt16 = 4243
    private var receiveBuffer = Data()
    
    func start(port: UInt16 = 4243) {
        self.port = port
        stop()
        
        isConnected = true
        errorMessage = nil
        
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        print("TCPListener: Starting on port \(port)")
        
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: params, on: nwPort)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isConnected = true
                        self?.errorMessage = nil
                        print("TCP Listener: Ready on port \(port)")
                    case .failed(let error):
                        self?.isConnected = false
                        self?.errorMessage = "Failed: \(error)"
                        print("TCP Listener: Failed - \(error)")
                    case .cancelled:
                        self?.isConnected = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                print("TCP Listener: New connection from \(connection.endpoint)")
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: queue)
        } catch {
            errorMessage = "Failed to create listener: \(error.localizedDescription)"
            print("TCP Listener: Failed to create - \(error)")
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        clientConnection?.cancel()
        clientConnection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("TCP Listener: Client connected")
                DispatchQueue.main.async {
                    self?.isConnected = true
                }
            case .failed(let error):
                print("TCP Listener: Client failed - \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            case .cancelled:
                print("TCP Listener: Client disconnected")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            default:
                break
            }
        }
        
        connection.start(queue: queue)
        receiveData(from: connection)
    }
    
    func stop() {
        clientConnection?.cancel()
        clientConnection = nil
        listener?.cancel()
        listener = nil
        isConnected = false
        packetCount = 0
        packetsInLastSecond = 0
        packetRate = 0
        receiveBuffer = Data()
    }
    
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                print("TCP Listener: Received \(data.count) bytes")
                self?.receiveBuffer.append(data)
                self?.processBuffer()
            }
            
            if let error = error {
                print("TCP Listener: Receive error: \(error)")
            }
            
            if !isComplete && error == nil {
                self?.receiveData(from: connection)
            }
        }
    }
    
    private func processBuffer() {
        while receiveBuffer.count >= 4 {
            let lengthData = receiveBuffer.subdata(in: 0..<4)
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            guard receiveBuffer.count >= 4 + Int(length) else {
                break
            }
            
            let packetData = receiveBuffer.subdata(in: 4..<(4 + Int(length)))
            receiveBuffer.removeSubrange(0..<(4 + Int(length)))
            
            handleReceivedData(packetData)
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        print("TCPListener: Processing \(data.count) bytes")
        
        guard let packet = PacketParser.parse(data) else { 
            print("TCPListener: Failed to parse packet, size = \(data.count)")
            return 
        }
        
        print("TCPListener: Parsed packet - pitch=\(packet.pose.pitch) yaw=\(packet.pose.yaw) roll=\(packet.pose.roll)")
        
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
