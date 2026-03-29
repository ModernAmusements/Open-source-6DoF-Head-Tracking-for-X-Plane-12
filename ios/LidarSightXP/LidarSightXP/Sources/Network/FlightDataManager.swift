import Foundation
import Network
import Combine

class FlightDataManager: ObservableObject {
    @Published var airspeed: Double = 0
    @Published var altitude: Double = 0
    @Published var heading: Double = 0
    @Published var verticalSpeed: Double = 0
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var isConnected: Bool = false
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "FlightDataManager", qos: .userInitiated)
    private var lastReceiveTime: Date = Date()
    
    static let xPlanePort: UInt16 = 49000
    
    func startListening() {
        let host = NWEndpoint.Host("0.0.0.0")
        let port = NWEndpoint.Port(rawValue: Self.xPlanePort)!
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        connection = NWConnection(host: host, port: port, using: params)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("FlightDataManager: Ready on port \(Self.xPlanePort)")
                self?.isConnected = true
                self?.receiveData()
            case .failed(let error):
                print("FlightDataManager: Failed - \(error)")
                self?.isConnected = false
            case .cancelled:
                self?.isConnected = false
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    func stopListening() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }
    
    private func receiveData() {
        connection?.receiveMessage { [weak self] data, _, _, error in
            if let data = data, !data.isEmpty {
                self?.lastReceiveTime = Date()
                self?.parseXPlaneData(data)
            }
            
            if error == nil {
                self?.receiveData()
            }
        }
    }
    
    private func parseXPlaneData(_ data: Data) {
        guard data.count >= 36 else { return }
        
        let header = String(data: data.prefix(4), encoding: .ascii)
        guard header == "DATA" else { return }
        
        let doubleData = data.dropFirst(4)
        
        doubleData.withUnsafeBytes { buffer in
            guard let basePtr = buffer.baseAddress?.assumingMemoryBound(to: Double.self) else { return }
            
            let count = buffer.count / MemoryLayout<Double>.size
            guard count >= 6 else { return }
            
            let ptr = UnsafeBufferPointer(start: basePtr, count: count)
            
            let valid = ptr.prefix(6).allSatisfy { !$0.isNaN && !$0.isInfinite }
            guard valid else { return }
            
            let airspeed_kts = ptr[0]
            let altitude_ft = ptr[1]
            let heading_deg = ptr[2]
            let pitch_deg = ptr[3]
            let roll_deg = ptr[4]
            let vsi_fpm = ptr[5]
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.airspeed = max(0, airspeed_kts)
                self.altitude = max(0, altitude_ft)
                var h = heading_deg.truncatingRemainder(dividingBy: 360)
                if h < 0 { h += 360 }
                self.heading = h
                self.pitch = pitch_deg
                self.roll = -roll_deg
                self.verticalSpeed = vsi_fpm * 60
                self.isConnected = true
            }
        }
    }
}
