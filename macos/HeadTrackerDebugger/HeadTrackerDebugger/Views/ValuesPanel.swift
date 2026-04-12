import SwiftUI

struct ValuesPanel: View {
    var title: String
    var pitch: Float
    var yaw: Float
    var roll: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                ValueColumn(label: "Pitch", value: pitch)
                ValueColumn(label: "Yaw", value: yaw)
                ValueColumn(label: "Roll", value: roll)
            }
        }
        .padding(16)
        .background(.regularMaterial)
    }
}

struct ValueColumn: View {
    var label: String
    var value: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value, specifier: "%+.1f")°")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

struct ValuesPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ValuesPanel(title: "Raw Values", pitch: -5.2, yaw: 12.8, roll: -1.0)
            ValuesPanel(title: "Filtered Values", pitch: -4.9, yaw: 11.5, roll: -0.8)
            ValuesPanel(title: "Output Values", pitch: -6.1, yaw: 34.5, roll: -1.0)
        }
        .frame(width: 288)
        .padding()
    }
}