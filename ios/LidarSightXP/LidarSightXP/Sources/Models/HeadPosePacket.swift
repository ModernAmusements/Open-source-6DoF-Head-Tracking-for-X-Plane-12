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
        let useEyeRotation = settings.trackingMode.usesEyeTracking && pose.eyeRotation != nil
        let eyeWeight: Float = 0.3
        
        let finalRotation: SIMD3<Float>
        
        if useEyeRotation, let eyeRot = pose.eyeRotation {
            let eyeOffset = SIMD3<Float>(
                (eyeRot.x - calibration.rotation.x) * settings.eyeSensitivity,
                (eyeRot.y - calibration.rotation.y) * settings.eyeSensitivity,
                (eyeRot.z - calibration.rotation.z) * settings.eyeSensitivity
            )
            
            switch settings.trackingMode {
            case .eyesOnly:
                finalRotation = eyeOffset
            case .headAndEyes:
                let headRot = SIMD3<Float>(
                    (pose.rotation.x - calibration.rotation.x) * settings.sensitivity,
                    (pose.rotation.y - calibration.rotation.y) * settings.sensitivity,
                    (pose.rotation.z - calibration.rotation.z) * settings.sensitivity
                )
                finalRotation = SIMD3<Float>(
                    headRot.x + eyeOffset.x * eyeWeight,
                    headRot.y + eyeOffset.y * eyeWeight,
                    headRot.z + eyeOffset.z * eyeWeight
                )
            default:
                finalRotation = SIMD3<Float>(
                    (pose.rotation.x - calibration.rotation.x) * settings.sensitivity,
                    (pose.rotation.y - calibration.rotation.y) * settings.sensitivity,
                    (pose.rotation.z - calibration.rotation.z) * settings.sensitivity
                )
            }
        } else {
            finalRotation = SIMD3<Float>(
                (pose.rotation.x - calibration.rotation.x) * settings.sensitivity,
                (pose.rotation.y - calibration.rotation.y) * settings.sensitivity,
                (pose.rotation.z - calibration.rotation.z) * settings.sensitivity
            )
        }
        
        let rawX = (pose.position.x - calibration.position.x) * settings.sensitivity
        let rawY = (pose.position.y - calibration.position.y) * settings.sensitivity
        let rawZ = (pose.position.z - calibration.position.z) * settings.sensitivity
        
        self.x = Double(OpenTrackPacket.applyRangeMapping(rawX, scale: settings.rangeScale))
        self.y = Double(OpenTrackPacket.applyRangeMapping(rawY, scale: settings.rangeScale))
        self.z = Double(OpenTrackPacket.applyRangeMapping(rawZ, scale: settings.rangeScale))
        
        let clampedPitch = OpenTrackPacket.applyAngleClamp(finalRotation.x, maxAngle: settings.maxAngle)
        let clampedYaw = OpenTrackPacket.applyAngleClamp(finalRotation.y, maxAngle: settings.maxAngle)
        let clampedRoll = OpenTrackPacket.applyAngleClamp(finalRotation.z, maxAngle: settings.maxAngle)
        
        self.pitch = Double(clampedPitch) * .pi / 180.0  // degrees to radians
        self.yaw = Double(clampedYaw) * .pi / 180.0
        self.roll = Double(clampedRoll) * .pi / 180.0
    }
    
    private static func applyRangeMapping(_ value: Float, scale: Float) -> Float {
        let sign: Float = value >= 0 ? 1 : -1
        let absValue = abs(value)
        let mapped = pow(absValue, 1.0 + scale)
        return sign * mapped
    }
    
    private static func applyAngleClamp(_ angle: Float, maxAngle: Float) -> Float {
        let maxA = maxAngle
        if abs(angle) <= maxA {
            return angle
        }
        return maxA * (angle > 0 ? 1 : -1)
    }
    
    func toData() -> Data {
        var packet = self
        return Data(bytes: &packet, count: OpenTrackPacket.size)
    }
}
