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
        case calibrated = 0x01
        case trackingValid = 0x02
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
    
    func toData() -> Data {
        var packet = self
        return Data(bytes: &packet, count: HeadPosePacket.size)
    }
    
    static func fromData(_ data: Data) -> HeadPosePacket? {
        guard data.count >= size else { return nil }
        
        var packet = HeadPosePacket()
        _ = withUnsafeMutableBytes(of: &packet) { buffer in
            data.copyBytes(to: buffer)
        }
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
        
        let rawPitch = normalizeAngle(pose.rotation.x - calibration.rotation.x)
        let rawYaw = normalizeAngle(pose.rotation.y - calibration.rotation.y)
        let rawRoll = normalizeAngle(pose.rotation.z - calibration.rotation.z)
        
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
