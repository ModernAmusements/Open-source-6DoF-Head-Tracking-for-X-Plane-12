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
        VStack(alignment: .leading, spacing: 12) {
            Text("CONNECTION STATUS")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(isConnected ? .green : .red)
            }
            
            HStack(spacing: 4) {
                Text("Local IP:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(localIP):\(port)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Protocol")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(protocol_.displayName)
                        .font(.system(.body, design: .monospaced))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Packet Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(packetRate, specifier: "%.1f") pkt/s")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(packetRate > 0 ? .primary : .secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StatusPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            StatusPanel(isConnected: true, protocol_: .openTrack, packetRate: 58.2, errorMessage: nil, port: 4242)
            StatusPanel(isConnected: false, protocol_: .lidarSight, packetRate: 0, errorMessage: "Failed to bind socket", port: 4242)
        }
        .frame(width: 280)
        .padding()
    }
}
