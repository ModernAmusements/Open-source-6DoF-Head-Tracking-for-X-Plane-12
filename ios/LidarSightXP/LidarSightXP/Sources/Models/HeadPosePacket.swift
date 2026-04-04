import Foundation
import simd

struct HeadPosePacket {
    var packetId: UInt32 = 0
    var flags: UInt8 = 0
    var timestampUs: Float = 0
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    var pitch: Float = 0
    var yaw: Float = 0
    var roll: Float = 0
    
    static let size = 33
    
    enum Flag: UInt8 {
        case calibrated = 0x01      // Calibration has been applied
        case trackingValid = 0x02   // Tracking data is valid
        case recenter = 0x04         // Plugin should reset its offset
    }
    
    func toData() -> Data {
        var data = Data()
        withUnsafeBytes(of: packetId.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: flags) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: timestampUs) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: x) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: y) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: z) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: pitch) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: yaw) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: roll) { data.append(contentsOf: $0) }
        return data
    }
    
    mutating func setFlag(_ flag: Flag, _ value: Bool) {
        if value {
            flags |= flag.rawValue
        } else {
            flags &= ~flag.rawValue
        }
    }
    
    func isFlagSet(_ flag: Flag) -> Bool {
        return (flags & flag.rawValue) != 0
    }
    
    static func fromData(_ data: Data) -> HeadPosePacket? {
        guard data.count >= size else { return nil }
        
        var packet = HeadPosePacket()
        packet.packetId = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        packet.flags = data.subdata(in: 4..<5).withUnsafeBytes { $0.load(as: UInt8.self) }
        packet.timestampUs = data.subdata(in: 5..<9).withUnsafeBytes { $0.load(as: Float.self) }
        packet.x = data.subdata(in: 9..<13).withUnsafeBytes { $0.load(as: Float.self) }
        packet.y = data.subdata(in: 13..<17).withUnsafeBytes { $0.load(as: Float.self) }
        packet.z = data.subdata(in: 17..<21).withUnsafeBytes { $0.load(as: Float.self) }
        packet.pitch = data.subdata(in: 21..<25).withUnsafeBytes { $0.load(as: Float.self) }
        packet.yaw = data.subdata(in: 25..<29).withUnsafeBytes { $0.load(as: Float.self) }
        packet.roll = data.subdata(in: 29..<33).withUnsafeBytes { $0.load(as: Float.self) }
        return packet
    }
}

struct OpenTrackPacket {
    var x: Double = 0      // position x
    var y: Double = 0      // position y
    var z: Double = 0      // position z
    var pitch: Double = 0  // rotation x (radians)
    var yaw: Double = 0    // rotation y (radians)
    var roll: Double = 0   // rotation z (radians)
    
    static let size = 48
    
    init(x: Double = 0, y: Double = 0, z: Double = 0,
         pitch: Double = 0, yaw: Double = 0, roll: Double = 0) {
        self.x = x
        self.y = y
        self.z = z
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
    }
    
    init(from pose: HeadPose, settings: TrackingSettings, calibration: CalibrationOffset) {
        let normalizeAngle: (Float) -> Float = { angle in
            var a = angle.truncatingRemainder(dividingBy: 360)
            if a > 180 { a -= 360 }
            if a < -180 { a += 360 }
            return a
        }
        
        // Note: calibration is already applied in ARTrackingManager via CalibrationManager
        // So we use pose.rotation directly (which is already relative to calibration)
        let rawPitch = normalizeAngle(pose.rotation.x)
        let rawYaw = normalizeAngle(pose.rotation.y)
        let rawRoll = normalizeAngle(pose.rotation.z)
        
        self.x = 0
        self.y = 0
        self.z = 0
        
        self.pitch = Double(rawPitch) * .pi / 180.0
        self.yaw = Double(rawYaw) * .pi / 180.0
        self.roll = Double(rawRoll) * .pi / 180.0
    }
    
    func toData() -> Data {
        var packet = self
        return Data(bytes: &packet, count: OpenTrackPacket.size)
    }
}
