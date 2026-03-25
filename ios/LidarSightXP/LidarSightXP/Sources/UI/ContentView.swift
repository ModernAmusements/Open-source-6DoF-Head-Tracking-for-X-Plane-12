import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var trackingManager: ARTrackingManager
    @EnvironmentObject var transportManager: TransportManager
    @EnvironmentObject var calibrationManager: CalibrationManager
    
    @State private var showSettings = false
    @State private var opacity: Double = 1.0
    @State private var steadyFrames = 0
    @State private var lastPoseChange = Date()
    
    let steadyThreshold = 60
    let dimDelay: Double = 10.0
    
    var body: some View {
        ZStack {
            ARSceneView()
                .ignoresSafeArea()
                .opacity(0.4)
            
            VStack {
                HStack {
                    StatusIndicator()
                    Spacer()
                    ConnectionStatusView()
                }
                .padding()
                
                Spacer()
                
                if trackingManager.isTracking {
                    TrackingOverlayView()
                } else {
                    StartButtonView()
                }
                
                Spacer()
                
                GlassTrayView(
                    onCalibrate: {
                        calibrationManager.calibrate(pose: trackingManager.currentPose)
                    },
                    onRecenter: {
                        calibrationManager.resetCalibration()
                    },
                    onSettings: {
                        showSettings = true
                    }
                )
            }
            .opacity(opacity)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(transportManager)
        }
        .onAppear {
            transportManager.loadCalibration()
            startStealthMonitor()
        }
        .onChange(of: trackingManager.currentPose) { _ in
            checkForStealthMode()
        }
    }
    
    private func startStealthMonitor() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            Task { @MainActor in
                let settings = transportManager.settings
                if settings.stealthMode {
                    let timeSinceChange = Date().timeIntervalSince(lastPoseChange)
                    if timeSinceChange > dimDelay && steadyFrames > steadyThreshold {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            opacity = 0.3
                        }
                    }
                }
            }
        }
    }
    
    private func checkForStealthMode() {
        let currentPos = trackingManager.currentPose.position
        let lastPos = calibrationManager.calibrationOffset.position
        let threshold: Float = 0.01
        
        if abs(currentPos.x - lastPos.x) < threshold &&
           abs(currentPos.y - lastPos.y) < threshold &&
           abs(currentPos.z - lastPos.z) < threshold {
            steadyFrames += 1
        } else {
            steadyFrames = 0
            lastPoseChange = Date()
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 1.0
            }
        }
    }
}

struct StatusIndicator: View {
    @EnvironmentObject var trackingManager: ARTrackingManager
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(trackingManager.isFaceDetected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            
            Text(trackingManager.isFaceDetected ? "Tracking" : "No Face")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct ConnectionStatusView: View {
    @EnvironmentObject var transportManager: TransportManager
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    private var statusColor: Color {
        switch transportManager.connectionStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch transportManager.connectionStatus {
        case .connected: return "UDP: \(transportManager.localIP):\(transportManager.udpPort)"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

struct TrackingOverlayView: View {
    @EnvironmentObject var trackingManager: ARTrackingManager
    
    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "X: %.2f  Y: %.2f  Z: %.2f",
                       trackingManager.currentPose.position.x,
                       trackingManager.currentPose.position.y,
                       trackingManager.currentPose.position.z))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
            
            Text(String(format: "Pitch: %.1f°  Yaw: %.1f°  Roll: %.1f°",
                       trackingManager.currentPose.rotation.x,
                       trackingManager.currentPose.rotation.y,
                       trackingManager.currentPose.rotation.z))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct StartButtonView: View {
    @EnvironmentObject var trackingManager: ARTrackingManager
    @EnvironmentObject var transportManager: TransportManager
    
    var body: some View {
        Button(action: {
            transportManager.startUDPServer()
            trackingManager.startTracking()
        }) {
            VStack(spacing: 8) {
                Image(systemName: "face.dashed")
                    .font(.system(size: 40))
                Text("Start Tracking")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct GlassTrayView: View {
    let onCalibrate: () -> Void
    let onRecenter: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            GlassButton(icon: "scope", label: "Calibrate", action: onCalibrate)
            GlassButton(icon: "arrow.counterclockwise", label: "Recenter", action: onRecenter)
            GlassButton(icon: "gearshape", label: "Settings", action: onSettings)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct GlassButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 60)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsView: View {
    @EnvironmentObject var transportManager: TransportManager
    @Environment(\.dismiss) var dismiss
    
    @State private var sensitivity: Double = 1.0
    @State private var smoothing: Double = 0.6
    @State private var stealthMode: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tracking") {
                    Slider(value: $sensitivity, in: 0.5...2.0, step: 0.1) {
                        Text("Sensitivity")
                    }
                    Slider(value: $smoothing, in: 0.1...1.0, step: 0.1) {
                        Text("Smoothing")
                    }
                }
                
                Section("Connection") {
                    Toggle("Stealth Mode", isOn: $stealthMode)
                }
                
                Section("Info") {
                    HStack {
                        Text("IP Address")
                        Spacer()
                        Text(transportManager.localIP)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Port")
                        Spacer()
                        Text("\(transportManager.udpPort)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        sensitivity = Double(transportManager.settings.sensitivity)
        smoothing = Double(transportManager.settings.smoothing)
        stealthMode = transportManager.settings.stealthMode
    }
    
    private func saveSettings() {
        let settings = TrackingSettings(
            sensitivity: Float(sensitivity),
            smoothing: Float(smoothing),
            stealthMode: stealthMode
        )
        transportManager.updateSettings(settings)
    }
}
