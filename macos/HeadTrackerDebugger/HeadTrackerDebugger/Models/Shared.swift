import Foundation

enum PacketProtocol: String, Codable, CaseIterable {
    case lidarSight = "LidarSight"
    case openTrack = "OpenTrack"
    
    var displayName: String { rawValue }
}

struct HeadPose {
    var pitch: Float = 0
    var yaw: Float = 0
    var roll: Float = 0
    
    var isValid: Bool = true
}

struct TrackingSettings: Codable {
    var filterMinCutoff: Double = 1.0
    var filterBeta: Double = 0.8
    var filterDCutoff: Double = 1.0
    
    var yaw: AxisConfig = AxisConfig(
        deadzone: 2.0,
        maxInput: 30.0,
        maxOutput: 90.0,
        curvePower: 2.0,
        enabled: true,
        invert: false
    )
    
    var pitch: AxisConfig = AxisConfig(
        deadzone: 3.0,
        maxInput: 20.0,
        maxOutput: 25.0,
        curvePower: 1.5,
        enabled: true,
        invert: false
    )
    
    var roll: AxisConfig = AxisConfig(
        deadzone: 0.0,
        maxInput: 15.0,
        maxOutput: 15.0,
        curvePower: 1.0,
        enabled: false,
        invert: false
    )
}

struct AxisConfig: Codable {
    var deadzone: Float = 0.0
    var maxInput: Float = 30.0
    var maxOutput: Float = 90.0
    var curvePower: Float = 1.0
    var enabled: Bool = true
    var invert: Bool = false
}

struct ParsedPacket {
    var pose: HeadPose
    var packetProtocol: PacketProtocol
    var timestamp: Date
    
    init(pose: HeadPose, proto: PacketProtocol, timestamp: Date = Date()) {
        self.pose = pose
        self.packetProtocol = proto
        self.timestamp = timestamp
    }
}

struct DebuggerSettings: Codable {
    var tracking = TrackingSettings()
    var listenPort: Int = 4243
    
    static var `default`: DebuggerSettings { DebuggerSettings() }
    
    static func load() -> DebuggerSettings {
        let url = getSettingsURL()
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(DebuggerSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    func save() {
        let url = Self.getSettingsURL()
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url)
    }
    
    private static func getSettingsURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("HeadTrackerDebugger", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("settings.json")
    }
}
