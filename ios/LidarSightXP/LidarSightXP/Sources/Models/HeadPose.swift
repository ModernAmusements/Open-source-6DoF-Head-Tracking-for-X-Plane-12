import Foundation
import simd

struct HeadPose: Equatable {
    var position: SIMD3<Float>
    var rotation: SIMD3<Float> // pitch, yaw, roll in degrees
    var timestamp: TimeInterval
    var isValid: Bool
    
    init(position: SIMD3<Float> = .zero, 
         rotation: SIMD3<Float> = .zero, 
         timestamp: TimeInterval = 0,
         isValid: Bool = false) {
        self.position = position
        self.rotation = rotation
        self.timestamp = timestamp
        self.isValid = isValid
    }
    
    static let zero = HeadPose()
}

struct CalibrationOffset: Codable {
    var position: SIMD3<Float>
    var rotation: SIMD3<Float>
    
    static let zero = CalibrationOffset(position: .zero, rotation: .zero)
}

struct TrackingSettings: Codable {
    var sensitivity: Float = 1.0
    var smoothing: Float = 0.6
    var useUSB: Bool = true
    var stealthMode: Bool = true
    
    static let `default` = TrackingSettings()
}
