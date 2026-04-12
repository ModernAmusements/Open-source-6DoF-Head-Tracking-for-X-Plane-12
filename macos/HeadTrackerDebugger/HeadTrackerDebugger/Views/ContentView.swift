import SwiftUI
import Combine
import Foundation

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
    private let udpListener = UDPListener()
    private let tcpListener = TCPListener()
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
        udpListener.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        
        udpListener.$detectedProtocol
            .receive(on: DispatchQueue.main)
            .assign(to: &$detectedProtocol)
        
        udpListener.$packetRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$packetRate)
        
        udpListener.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
        
        udpListener.onPacketReceived = { [weak self] packet in
            self?.processPacket(packet)
        }
        
        udpListener.start(port: 4242)
    }
    
    func startListening() {
        udpListener.start(port: 4242)
    }
    
    func stopListening() {
        udpListener.stop()
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
            
            let offsetPitch = self.filteredPitch - self.poseOffset.pitch
            let offsetYaw = self.filteredYaw - self.poseOffset.yaw
            let offsetRoll = self.filteredRoll - self.poseOffset.roll
            
            if !self.hasInitialPose {
                self.hasInitialPose = true
                self.poseOffset.pitch = self.filteredPitch
                self.poseOffset.yaw = self.filteredYaw
                self.poseOffset.roll = self.filteredRoll
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
        let tPowered = pow(t, curvePower)
        
        let curved = config.deadzone + (config.maxOutput - config.deadzone) * tPowered
        return sign * curved * (config.invert ? -1 : 1)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = HeadTrackerViewModel()
    @State private var showSettings = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List {
                Section("Connection") {
                    HStack {
                        Circle()
                            .fill(viewModel.isConnected ? .green : .secondary)
                            .frame(width: 10, height: 10)
                        Text(viewModel.isConnected ? "Connected" : "Disconnected")
                        Spacer()
                        Text("\(viewModel.packetRate, specifier: "%.1f") Hz")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Protocol")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.detectedProtocol.displayName)
                    }
                    
                    HStack {
                        Text("Port")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(viewModel.settings.listenPort)")
                    }
                }
                
                Section("Raw Values") {
                    ValueRow(label: "Pitch", value: viewModel.rawPitch)
                    ValueRow(label: "Yaw", value: viewModel.rawYaw)
                    ValueRow(label: "Roll", value: viewModel.rawRoll)
                }
                
                Section("Filtered") {
                    ValueRow(label: "Pitch", value: viewModel.filteredPitch)
                    ValueRow(label: "Yaw", value: viewModel.filteredYaw)
                    ValueRow(label: "Roll", value: viewModel.filteredRoll)
                }
                
                Section("Output") {
                    ValueRow(label: "Pitch", value: viewModel.outputPitch)
                    ValueRow(label: "Yaw", value: viewModel.outputYaw)
                    ValueRow(label: "Roll", value: viewModel.outputRoll)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            VStack(spacing: 16) {
                WindshieldView3D(
                    pitch: viewModel.outputPitch,
                    yaw: viewModel.outputYaw,
                    roll: viewModel.outputRoll
                )
                .frame(minHeight: 300)
                
                HStack(spacing: 12) {
                    Button {
                        viewModel.recenter()
                    } label: {
                        Image(systemName: "location.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isConnected == false)
                    .help("Recenter tracking (⌘R)")
                    
                    Button(viewModel.isConnected ? "Stop" : "Start") {
                        if viewModel.isConnected {
                            viewModel.stopListening()
                        } else {
                            viewModel.startListening()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isConnected ? .red : .green)
                    .keyboardShortcut(viewModel.isConnected ? "x" : "s", modifiers: [.command, .shift])
                    
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .help("Settings (⌘,)")
                }
                .padding(.bottom, 8)
            }
            .frame(minWidth: 500)
        }
        .navigationTitle("Head Tracker")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.recenter()
                } label: {
                    Image(systemName: "location.viewfinder")
                }
                .disabled(viewModel.isConnected == false)
                .help("Recenter tracking")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
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
            .frame(width: 400, height: 600)
            .interactiveDismissDisabled(false)
        }
    }
}

struct ValueRow: View {
    let label: String
    let value: Float
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value, specifier: "%+.1f")°")
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}