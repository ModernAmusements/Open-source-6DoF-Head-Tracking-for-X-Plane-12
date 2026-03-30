import SwiftUI

struct StatusPanel: View {
    var isConnected: Bool
    var protocol_: PacketProtocol
    var packetRate: Double
    var errorMessage: String?
    
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
            StatusPanel(isConnected: true, protocol_: .openTrack, packetRate: 58.2, errorMessage: nil)
            StatusPanel(isConnected: false, protocol_: .lidarSight, packetRate: 0, errorMessage: "Failed to bind socket")
        }
        .frame(width: 280)
        .padding()
    }
}
