import SwiftUI
import Network

struct StatusPanel: View {
    var isConnected: Bool
    var protocol_: PacketProtocol
    var packetRate: Double
    var errorMessage: String?
    var port: Int
    
    private var localIP: String {
        var address = "Unknown"
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? .green : .secondary)
                    .frame(width: 10, height: 10)
                
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.subheadline)
            }
            
            HStack(spacing: 8) {
                Text("Listen:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(localIP):\(port)")
                    .font(.system(.subheadline, design: .monospaced))
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protocol")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(protocol_.displayName)
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Packet Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(packetRate, specifier: "%.1f")/s")
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
    }
}

struct StatusPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            StatusPanel(isConnected: true, protocol_: .lidarSight, packetRate: 58.2, errorMessage: nil, port: 4242)
            StatusPanel(isConnected: false, protocol_: .lidarSight, packetRate: 0, errorMessage: "Failed to bind socket", port: 4242)
        }
        .frame(width: 288)
        .padding()
    }
}