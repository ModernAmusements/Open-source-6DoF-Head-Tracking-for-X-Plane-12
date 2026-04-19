import SwiftUI

struct ContentView: View {
    @EnvironmentObject var trackingManager: ARTrackingManager
    @EnvironmentObject var transportManager: TransportManager
    @EnvironmentObject var calibrationManager: CalibrationManager
    @EnvironmentObject var flightDataManager: FlightDataManager
    
    @State private var showSettings = false
    @State private var opacity: Double = 1.0
    @State private var steadyFrames = 0
    @State private var lastPoseChange = Date()
    @State private var stealthTimer: Timer?
    
    let steadyThreshold = 60
    let dimDelay: Double = 10.0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    StatusIndicator()
                    Spacer()
                    ConnectionStatusView()
                }
                .padding()
                
                Spacer()
                
                if trackingManager.isTracking {
                    HeadIconOverlay()
                        .environmentObject(trackingManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    FlightDataPanel()
                        .environmentObject(flightDataManager)
                        .padding(.bottom, 20)
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
        .onDisappear {
            stopStealthMonitor()
        }
        .onChange(of: trackingManager.currentPose) { _ in
            checkForStealthMode()
        }
    }
    
    private func startStealthMonitor() {
        stealthTimer?.invalidate()
        stealthTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let settings = self.transportManager.settings
                if settings.stealthMode {
                    let timeSinceChange = Date().timeIntervalSince(self.lastPoseChange)
                    if timeSinceChange > self.dimDelay && self.steadyFrames > self.steadyThreshold {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.opacity = 0.3
                        }
                    }
                }
            }
        }
    }
    
    private func stopStealthMonitor() {
        stealthTimer?.invalidate()
        stealthTimer = nil
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
            
            if transportManager.needsLocalNetworkPermission {
                Text("Tap to enable")
                    .font(.caption)
                    .foregroundColor(.yellow)
            } else {
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .onTapGesture {
            transportManager.requestLocalNetworkPermission {
                transportManager.startTCPServer()
            }
        }
    }
    
    private var statusColor: Color {
        if transportManager.needsLocalNetworkPermission {
            return .yellow
        }
        switch transportManager.connectionStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch transportManager.connectionStatus {
        case .connected: 
            let targetIP = transportManager.settings.targetIP.isEmpty ? transportManager.localIP : transportManager.settings.targetIP
            if transportManager.settings.protocolMode == .openTrack {
                return "UDP: \(targetIP):4242"
            } else {
                return "TCP: \(targetIP):\(transportManager.tcpPort)"
            }
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
    
    private var modeIcon: String {
        switch trackingManager.trackingMode {
        case .headOnly:
            return "person.fill"
        case .eyesOnly:
            return "eye.fill"
        case .headAndEyes:
            return "person.fill.badge.plus"
        case .lidar:
            return "light.min"
        }
    }
    
    private var modeLabel: String {
        switch trackingManager.trackingMode {
        case .headOnly:
            return "Head Only"
        case .eyesOnly:
            return "Eyes Only"
        case .headAndEyes:
            return "Head + Eyes"
        case .lidar:
            return "LiDAR Mode"
        }
    }
    
    var body: some View {
        Button(action: {
            transportManager.requestLocalNetworkPermission { [self] in
                transportManager.startTCPServer()
                trackingManager.trackingMode = transportManager.settings.trackingMode
                trackingManager.startTracking()
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: modeIcon)
                    .font(.system(size: 40))
                Text("Start Tracking")
                    .font(.headline)
                Text(modeLabel)
                    .font(.caption)
                    .opacity(0.7)
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
    @EnvironmentObject var trackingManager: ARTrackingManager
    @Environment(\.dismiss) var dismiss
    
    @State private var sensitivity: Double = 1.0
    @State private var smoothingEnabled: Bool = true
    @State private var stealthMode: Bool = true
    @State private var selectedMode: TrackingMode = .headOnly
    @State private var selectedProtocol: ProtocolMode = .openTrack
    @State private var maxAngle: Double = 45.0
    @State private var nonlinearCurve: Bool = true
    @State private var eyeTrackingEnabled: Bool = false
    @State private var targetIP: String = ""
    @State private var invertRoll: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tracking Mode") {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(TrackingMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    
                    Text(selectedMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Parameters") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Sensitivity")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1fx", sensitivity))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $sensitivity, in: 0.5...3.0, step: 0.1)
                            .onChange(of: sensitivity) { _ in saveSettings() }
                        Text("Multiplies head movement range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Smoothing", isOn: $smoothingEnabled)
                        .onChange(of: smoothingEnabled) { _ in saveSettings() }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Max Angle")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.0f°", maxAngle))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $maxAngle, in: 15...90, step: 5)
                            .onChange(of: maxAngle) { _ in saveSettings() }
                        Text("Clamps rotation range to keep looking at screen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Non-linear Curve", isOn: $nonlinearCurve)
                        .onChange(of: nonlinearCurve) { _ in saveSettings() }
                }
                
                Section("Eye Tracking") {
                    Toggle("Enable Eye Tracking", isOn: $eyeTrackingEnabled)
                        .onChange(of: eyeTrackingEnabled) { _ in saveSettings() }
                }
                
                Section("Roll Inversion") {
                    Toggle("Invert Roll", isOn: $invertRoll)
                        .onChange(of: invertRoll) { _ in saveSettings() }
                    Text("Use if tilting left shows view tilting right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Connection") {
                    Picker("Protocol", selection: $selectedProtocol) {
                        ForEach(ProtocolMode.allCases, id: \.self) { proto in
                            Text(proto.rawValue)
                                .tag(proto)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProtocol) { _ in saveSettings() }
                    
                    Text(selectedProtocol.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Target IP (Mac)", text: $targetIP)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: targetIP) { _ in saveSettings() }
                    
                    Text("IP of your Mac (e.g., 192.168.0.100)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Stealth Mode", isOn: $stealthMode)
                        .onChange(of: stealthMode) { _ in saveSettings() }
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
                        Text("\(transportManager.tcpPort)")
                            .foregroundColor(.secondary)
                    }
                    if trackingManager.isTracking {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(trackingManager.isFaceDetected ? "Tracking" : "No Detection")
                                .foregroundColor(trackingManager.isFaceDetected ? .green : .red)
                        }
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
        smoothingEnabled = transportManager.settings.smoothing > 0
        stealthMode = transportManager.settings.stealthMode
        selectedMode = transportManager.settings.trackingMode
        selectedProtocol = transportManager.settings.protocolMode
        maxAngle = Double(transportManager.settings.maxAngle)
        nonlinearCurve = transportManager.settings.rangeScale > 0
        eyeTrackingEnabled = transportManager.settings.eyeSensitivity > 0
        targetIP = transportManager.settings.targetIP
        invertRoll = transportManager.settings.invertRoll
    }
    
    private func saveSettings() {
        let settings = TrackingSettings(
            sensitivity: Float(sensitivity),
            smoothing: smoothingEnabled ? 0.85 : 0.0,
            stealthMode: stealthMode,
            trackingMode: selectedMode,
            protocolMode: selectedProtocol,
            maxAngle: Float(maxAngle),
            rangeScale: nonlinearCurve ? 0.7 : 0.0,
            eyeSensitivity: eyeTrackingEnabled ? 2.5 : 0.0,
            targetIP: targetIP,
            invertRoll: invertRoll
        )
        transportManager.updateSettings(settings)
        trackingManager.trackingMode = selectedMode
    }
}
