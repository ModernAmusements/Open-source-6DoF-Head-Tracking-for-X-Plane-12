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
    
    private var port: UInt16 = 4242
    private var receiveBuffer = Data()
    
    func start(port: UInt16 = 4242) {
        self.port = port
        stop()
        
        isConnected = true
        errorMessage = nil
        
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        print("TCPListener: Starting server on port \(port)")
        print("TCPListener: Server type = TCP (not UDP)")
        
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            
            print("TCPListener: Creating NWListener...")
            listener = try NWListener(using: params, on: nwPort)
            
            print("TCPListener: Setting up state handler...")
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    print("TCPListener: State changed to \(state)")
                    switch state {
                    case .ready:
                        self?.isConnected = true
                        self?.errorMessage = nil
                        print("TCP Listener: READY on port \(port)")
                    case .failed(let error):
                        self?.isConnected = false
                        self?.errorMessage = "Failed: \(error)"
                        print("TCP Listener: FAILED - \(error)")
                    case .cancelled:
                        self?.isConnected = false
                        print("TCP Listener: CANCELLED")
                    case .waiting(let error):
                        print("TCP Listener: WAITING - \(error)")
                    default:
                        break
                    }
                }
            }
            
            print("TCPListener: Setting new connection handler...")
            listener?.newConnectionHandler = { [weak self] connection in
                print("TCP Listener: New connection from \(connection.endpoint)")
                self?.handleNewConnection(connection)
            }
            
            print("TCPListener: Starting listener...")
            listener?.start(queue: queue)
            print("TCPListener: Listener started")
        } catch {
            errorMessage = "Failed to create listener: \(error.localizedDescription)"
            print("TCP Listener: Failed to create - \(error)")
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        print("TCPListener: Handling new connection from \(connection.endpoint)")
        clientConnection?.cancel()
        clientConnection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            print("TCPListener: Connection state changed: \(state)")
            switch state {
            case .ready:
                print("TCPListener: Client READY - receiving data")
                DispatchQueue.main.async {
                    self?.isConnected = true
                }
            case .failed(let error):
                print("TCPListener: Client FAILED - \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            case .cancelled:
                print("TCPListener: Client DISCONNECTED")
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
        print("TCPListener: Starting receive loop...")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let error = error {
                print("TCPListener: Receive ERROR - \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
                return
            }
            
            if let data = data, !data.isEmpty {
                print("TCPListener: Received \(data.count) bytes")
                print("TCPListener: First 16 bytes hex: \(data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
                self?.receiveBuffer.append(data)
                self?.processBuffer()
            }
            
            if isComplete {
                print("TCPListener: Connection completed (closed)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
                return
            }
            
            // Continue receiving
            self?.receiveData(from: connection)
        }
    }
    
    private func processBuffer() {
        print("TCPListener: Buffer size = \(receiveBuffer.count) bytes")
        
        // If data is too small for length prefix, wait for more
        guard receiveBuffer.count >= 4 else {
            print("TCPListener: Waiting for more data (need 4 bytes for length)")
            return
        }
        
        let lengthData = receiveBuffer.subdata(in: 0..<4)
        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        
        print("TCPListener: Packet length prefix = \(length) bytes")
        
        guard receiveBuffer.count >= 4 + Int(length) else {
            print("TCPListener: Have \(receiveBuffer.count) bytes, need \(4 + Int(length)) - waiting for more")
            return
        }
        
        let packetData = receiveBuffer.subdata(in: 4..<(4 + Int(length)))
        receiveBuffer.removeSubrange(0..<(4 + Int(length)))
        
        print("TCPListener: Extracted \(packetData.count) bytes, remaining = \(receiveBuffer.count)")
        
        handleReceivedData(packetData)
        
        // Process any remaining data
        if receiveBuffer.count >= 4 {
            processBuffer()
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        print("TCPListener: Processing \(data.count) bytes")
        
        guard let packet = PacketParser.parse(data) else { 
            print("TCPListener: Failed to parse packet, size = \(data.count)")
            // Maybe the packet doesn't have a length prefix - try without
            if data.count >= 33 && data.count < 50 {
                let directData = data.prefix(33)
                if let directPacket = PacketParser.parse(Data(directData)) {
                    print("TCPListener: Direct parse succeeded! pitch=\(directPacket.pose.pitch)")
                    DispatchQueue.main.async { [weak self] in
                        self?.lastPacket = directPacket
                        self?.detectedProtocol = directPacket.packetProtocol
                        self?.packetCount += 1
                        self?.packetsInLastSecond += 1
                        
                        let now = Date()
                        let elapsed = now.timeIntervalSince(self?.lastRateUpdate ?? now)
                        if elapsed >= 1.0 {
                            self?.packetRate = Double(self?.packetsInLastSecond ?? 0)
                            self?.packetsInLastSecond = 0
                            self?.lastRateUpdate = now
                        }
                        
                        self?.onPacketReceived?(directPacket)
                    }
                } else {
                    print("TCPListener: Direct parse also failed")
                }
            }
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
