import SwiftUI

struct SettingsPanel: View {
    @Binding var settings: DebuggerSettings
    var onSave: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SETTINGS")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            Text("FILTER SETTINGS")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Min Cutoff: \(settings.tracking.filterMinCutoff, specifier: "%.1f") Hz")
                    .font(.caption)
                Slider(value: $settings.tracking.filterMinCutoff, in: 0.1...10.0, step: 0.1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Beta: \(settings.tracking.filterBeta, specifier: "%.2f")")
                    .font(.caption)
                Slider(value: $settings.tracking.filterBeta, in: 0.0...2.0, step: 0.05)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("d Cutoff: \(settings.tracking.filterDCutoff, specifier: "%.1f") Hz")
                    .font(.caption)
                Slider(value: $settings.tracking.filterDCutoff, in: 0.1...10.0, step: 0.1)
            }
            
            Divider()
            
            Text("AXIS SETTINGS")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Group {
                Text("YAW")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Toggle("Enabled", isOn: $settings.tracking.yaw.enabled)
                Toggle("Invert", isOn: $settings.tracking.yaw.invert)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deadzone: \(settings.tracking.yaw.deadzone, specifier: "%.1f")°")
                        .font(.caption)
                    Slider(value: $settings.tracking.yaw.deadzone, in: 0...15, step: 0.5)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Output: \(settings.tracking.yaw.maxOutput, specifier: "%.0f")°")
                        .font(.caption)
                    Slider(value: $settings.tracking.yaw.maxOutput, in: 30...180, step: 5)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Curve Power: \(settings.tracking.yaw.curvePower, specifier: "%.1f")")
                        .font(.caption)
                    Slider(value: $settings.tracking.yaw.curvePower, in: 0.5...4.0, step: 0.1)
                }
            }
            
            Group {
                Divider()
                
                Text("PITCH")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Toggle("Enabled", isOn: $settings.tracking.pitch.enabled)
                Toggle("Invert", isOn: $settings.tracking.pitch.invert)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deadzone: \(settings.tracking.pitch.deadzone, specifier: "%.1f")°")
                        .font(.caption)
                    Slider(value: $settings.tracking.pitch.deadzone, in: 0...15, step: 0.5)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Output: \(settings.tracking.pitch.maxOutput, specifier: "%.0f")°")
                        .font(.caption)
                    Slider(value: $settings.tracking.pitch.maxOutput, in: 10...90, step: 5)
                }
            }
            
            Divider()
            
            Button("Save Settings") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
