import SwiftUI
import Combine

class HeadTrackerViewModel: ObservableObject {
    @Published var rawPitch: Float = 0
    @Published var rawYaw: Float = 0
    @Published var rawRoll: Float = 0
    
    @Published var filteredPitch: Float = 0
    @Published var filteredYaw: Float = 0
    @Published var filteredRoll: Float = 0
    
    @Published var outputPitch: Float = 0
    @Published var outputYaw: Float = 0
    @Published var outputRoll: Float = 0
    
    @Published var isConnected: Bool = false
    @Published var detectedProtocol: PacketProtocol = .lidarSight
    @Published var packetRate: Double = 0
    @Published var errorMessage: String?
    
    @Published var settings: DebuggerSettings = .load()
    
    private let listener = TCPListener()
    private let filter = OneEuroFilterVector3()
    private var hasInitialPose = false
    private var poseOffset = HeadPose()
    private var lastPacketTime = Date()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupFilter()
        setupListener()
    }
    
    private func setupFilter() {
        filter.setParameters(
            minCutoff: settings.tracking.filterMinCutoff,
            beta: settings.tracking.filterBeta,
            dCutoff: settings.tracking.filterDCutoff
        )
    }
    
    private func setupListener() {
        listener.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        
        listener.$detectedProtocol
            .receive(on: DispatchQueue.main)
            .assign(to: &$detectedProtocol)
        
        listener.$packetRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$packetRate)
        
        listener.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
        
        listener.onPacketReceived = { [weak self] packet in
            DispatchQueue.main.async {
                self?.processPacket(packet)
            }
        }
        
        listener.start(port: UInt16(settings.listenPort))
    }
    
    func startListening() {
        listener.start(port: UInt16(settings.listenPort))
    }
    
    func stopListening() {
        listener.stop()
    }
    
    func recenter() {
        hasInitialPose = false
        filter.reset()
    }
    
    func saveSettings() {
        settings.save()
        setupFilter()
    }
    
    func updateFilter() {
        setupFilter()
    }
    
    private func processPacket(_ packet: ParsedPacket) {
        let rawPose = packet.pose
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.rawPitch = rawPose.pitch
            self.rawYaw = rawPose.yaw
            self.rawRoll = rawPose.roll
            
            if !rawPose.isValid {
                self.filteredPitch = 0
                self.filteredYaw = 0
                self.filteredRoll = 0
                return
            }
            
            let dt = Date().timeIntervalSince(self.lastPacketTime)
            self.lastPacketTime = Date()
            
            let filtered = self.filter.filter(
                pitch: Double(rawPose.pitch),
                yaw: Double(rawPose.yaw),
                roll: Double(rawPose.roll),
                dt: max(dt, 0.001)
            )
            
            self.filteredPitch = Float(filtered.pitch)
            self.filteredYaw = Float(filtered.yaw)
            self.filteredRoll = Float(filtered.roll)
            
            var offsetPitch = self.filteredPitch - self.poseOffset.pitch
            var offsetYaw = self.filteredYaw - self.poseOffset.yaw
            var offsetRoll = self.filteredRoll - self.poseOffset.roll
            
            if !self.hasInitialPose {
                self.hasInitialPose = true
                self.poseOffset.pitch = self.filteredPitch
                self.poseOffset.yaw = self.filteredYaw
                self.poseOffset.roll = self.filteredRoll
                offsetPitch = 0
                offsetYaw = 0
                offsetRoll = 0
            }
            
            self.outputPitch = self.applyCurve(offsetPitch, config: self.settings.tracking.pitch)
            self.outputYaw = self.applyCurve(offsetYaw, config: self.settings.tracking.yaw)
            self.outputRoll = self.applyCurve(offsetRoll, config: self.settings.tracking.roll)
        }
    }
    
    private func applyCurve(_ value: Float, config: AxisConfig) -> Float {
        guard config.enabled else { return 0 }
        
        let absVal = abs(value)
        guard absVal >= config.deadzone else { return 0 }
        
        let sign: Float = value > 0 ? 1 : -1
        let effectiveMaxInput = max(config.maxInput, config.deadzone + 0.1)
        var t = (absVal - config.deadzone) / (effectiveMaxInput - config.deadzone)
        t = max(0, min(1, t))
        
        let curvePower = max(0.1, config.curvePower)
        var tPowered = t
        for _ in 0..<Int(curvePower * 10) {
            tPowered *= t
        }
        
        let curved = config.deadzone + (config.maxOutput - config.deadzone) * tPowered
        return sign * curved * (config.invert ? -1 : 1)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = HeadTrackerViewModel()
    @State private var showSettings = false
    
    var body: some View {
        HSplitView {
            VStack(spacing: 16) {
                WindshieldView3D(
                    pitch: viewModel.outputPitch,
                    yaw: viewModel.outputYaw,
                    roll: viewModel.outputRoll
                )
                .frame(minHeight: 300)
                
                HStack {
                    Button("Recenter") {
                        viewModel.recenter()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(viewModel.isConnected ? "Stop" : "Start") {
                        if viewModel.isConnected {
                            viewModel.stopListening()
                        } else {
                            viewModel.startListening()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Button("Settings") {
                        showSettings.toggle()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(minWidth: 500)
            .padding()
            
            VStack(alignment: .leading, spacing: 16) {
                StatusPanel(
                    isConnected: viewModel.isConnected,
                    protocol_: viewModel.detectedProtocol,
                    packetRate: viewModel.packetRate,
                    errorMessage: viewModel.errorMessage
                )
                
                ValuesPanel(
                    title: "RAW VALUES",
                    pitch: viewModel.rawPitch,
                    yaw: viewModel.rawYaw,
                    roll: viewModel.rawRoll,
                    color: .blue
                )
                
                ValuesPanel(
                    title: "FILTERED (One Euro)",
                    pitch: viewModel.filteredPitch,
                    yaw: viewModel.filteredYaw,
                    roll: viewModel.filteredRoll,
                    color: .orange
                )
                
                ValuesPanel(
                    title: "OUTPUT (to X-Plane)",
                    pitch: viewModel.outputPitch,
                    yaw: viewModel.outputYaw,
                    roll: viewModel.outputRoll,
                    color: .green
                )
                
                Spacer()
            }
            .frame(width: 300)
            .padding()
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showSettings) {
            SettingsPanel(
                settings: $viewModel.settings,
                onSave: {
                    viewModel.saveSettings()
                    showSettings = false
                },
                isPresented: $showSettings
            )
            .frame(width: 400, height: 650)
            .padding()
            .interactiveDismissDisabled(false)
        }
        .onChange(of: viewModel.settings.tracking.filterMinCutoff) { _, _ in
            viewModel.updateFilter()
        }
        .onChange(of: viewModel.settings.tracking.filterBeta) { _, _ in
            viewModel.updateFilter()
        }
        .onChange(of: viewModel.settings.tracking.filterDCutoff) { _, _ in
            viewModel.updateFilter()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
