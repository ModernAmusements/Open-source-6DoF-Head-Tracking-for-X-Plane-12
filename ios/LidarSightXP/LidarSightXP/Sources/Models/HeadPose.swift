import Foundation
import simd

struct HeadPose: Equatable {
    var position: SIMD3<Float>
    var rotation: SIMD3<Float> // pitch, yaw, roll in degrees
    var timestamp: TimeInterval
    var isValid: Bool
    
    init(position: SIMD3<Float> = SIMD3<Float>(0, 0, 0), 
         rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0), 
         timestamp: TimeInterval = 0,
         isValid: Bool = false) {
        self.position = position
        self.rotation = rotation
        self.timestamp = timestamp
        self.isValid = isValid
    }
    
    static let zero = HeadPose()
}

struct CalibrationOffset: Codable, Equatable {
    var position: SIMD3<Float>
    var rotation: SIMD3<Float>
    
    init(position: SIMD3<Float> = SIMD3<Float>(0, 0, 0), 
         rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        self.position = position
        self.rotation = rotation
    }
    
    static let zero = CalibrationOffset()
}

struct TrackingSettings: Codable, Equatable {
    var sensitivity: Float
    var smoothing: Float
    var stealthMode: Bool
    
    init(sensitivity: Float = 1.0, 
         smoothing: Float = 0.6, 
         stealthMode: Bool = true) {
        self.sensitivity = sensitivity
        self.smoothing = smoothing
        self.stealthMode = stealthMode
    }
    
    static let `default` = TrackingSettings()
}
