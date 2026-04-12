import SwiftUI

struct SettingsPanel: View {
    @Binding var settings: DebuggerSettings
    var onSave: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        Form {
            Section("Filter Settings") {
                Stepper("Min Cutoff: \(settings.tracking.filterMinCutoff, specifier: "%.1f") Hz",
                       value: $settings.tracking.filterMinCutoff,
                       in: 0.1...10.0,
                       step: 0.1)
                
                Stepper("Beta: \(settings.tracking.filterBeta, specifier: "%.2f")",
                       value: $settings.tracking.filterBeta,
                       in: 0.0...2.0,
                       step: 0.05)
                
                Stepper("d Cutoff: \(settings.tracking.filterDCutoff, specifier: "%.1f") Hz",
                       value: $settings.tracking.filterDCutoff,
                       in: 0.1...10.0,
                       step: 0.1)
            }
            
            Section("Yaw Settings") {
                Toggle("Enabled", isOn: $settings.tracking.yaw.enabled)
                Toggle("Invert", isOn: $settings.tracking.yaw.invert)
                
                Stepper("Deadzone: \(settings.tracking.yaw.deadzone, specifier: "%.1f")°",
                       value: $settings.tracking.yaw.deadzone,
                       in: 0...15,
                       step: 0.5)
                
                Stepper("Max Output: \(settings.tracking.yaw.maxOutput, specifier: "%.0f")°",
                       value: $settings.tracking.yaw.maxOutput,
                       in: 30...180,
                       step: 5)
                
                Stepper("Curve Power: \(settings.tracking.yaw.curvePower, specifier: "%.1f")",
                       value: $settings.tracking.yaw.curvePower,
                       in: 0.5...4.0,
                       step: 0.1)
            }
            
            Section("Pitch Settings") {
                Toggle("Enabled", isOn: $settings.tracking.pitch.enabled)
                Toggle("Invert", isOn: $settings.tracking.pitch.invert)
                
                Stepper("Deadzone: \(settings.tracking.pitch.deadzone, specifier: "%.1f")°",
                       value: $settings.tracking.pitch.deadzone,
                       in: 0...15,
                       step: 0.5)
                
                Stepper("Max Output: \(settings.tracking.pitch.maxOutput, specifier: "%.0f")°",
                       value: $settings.tracking.pitch.maxOutput,
                       in: 10...90,
                       step: 5)
            }
            
            Section {
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
