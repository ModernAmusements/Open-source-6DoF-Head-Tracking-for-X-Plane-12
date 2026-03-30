import SwiftUI

struct ValuesPanel: View {
    var title: String
    var pitch: Float
    var yaw: Float
    var roll: Float
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Pitch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(pitch, specifier: "%+.1f")°")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading) {
                    Text("Yaw")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(yaw, specifier: "%+.1f")°")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading) {
                    Text("Roll")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(roll, specifier: "%+.1f")°")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(color)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ValuesPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ValuesPanel(title: "RAW VALUES", pitch: -5.2, yaw: 12.8, roll: -1.0, color: .blue)
            ValuesPanel(title: "FILTERED", pitch: -4.9, yaw: 11.5, roll: -0.8, color: .orange)
            ValuesPanel(title: "OUTPUT (to X-Plane)", pitch: -6.1, yaw: 34.5, roll: -1.0, color: .green)
        }
        .frame(width: 280)
        .padding()
    }
}
