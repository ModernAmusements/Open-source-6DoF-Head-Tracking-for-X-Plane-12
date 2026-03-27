import Foundation
import simd

enum TrackingMode: String, Codable, CaseIterable {
    case headOnly = "Head Only"
    case eyesOnly = "Eyes Only"
    case headAndEyes = "Head + Eyes"
    case lidar = "LiDAR"
    
    var description: String {
        switch self {
        case .headOnly:
            return "Head movement controls view, eyes not used"
        case .eyesOnly:
            return "Eye direction controls view, minimal head movement"
        case .headAndEyes:
            return "Eyes add fine control on top of head movement"
        case .lidar:
            return "Uses rear camera for position tracking"
        }
    }
    
    var icon: String {
        switch self {
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
    
    var usesEyeTracking: Bool {
        switch self {
        case .eyesOnly, .headAndEyes:
            return true
        default:
            return false
        }
    }
}

enum ProtocolMode: String, Codable, CaseIterable {
    case custom = "LidarSight"
    case openTrack = "OpenTrack"
    
    var description: String {
        switch self {
        case .custom:
            return "LidarSight protocol (33 bytes)"
        case .openTrack:
            return "OpenTrack UDP format (48 bytes)"
        }
    }
}

struct HeadPose: Equatable {
    var position: SIMD3<Float>
    var rotation: SIMD3<Float> // pitch, yaw, roll in degrees
    var eyeRotation: SIMD3<Float>? // eye gaze direction (pitch, yaw, roll)
    var timestamp: TimeInterval
    var isValid: Bool
    
    init(position: SIMD3<Float> = SIMD3<Float>(0, 0, 0), 
         rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
         eyeRotation: SIMD3<Float>? = nil,
         timestamp: TimeInterval = 0,
         isValid: Bool = false) {
        self.position = position
        self.rotation = rotation
        self.eyeRotation = eyeRotation
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
    var trackingMode: TrackingMode
    var protocolMode: ProtocolMode
    var maxAngle: Float
    var rangeScale: Float
    var eyeSensitivity: Float // Extra sensitivity for eye tracking (eyes move less than head)
    
    init(sensitivity: Float = 1.0, 
         smoothing: Float = 0.6, 
         stealthMode: Bool = true,
         trackingMode: TrackingMode = .headOnly,
         protocolMode: ProtocolMode = .openTrack,
         maxAngle: Float = 45.0,
         rangeScale: Float = 0.7,
         eyeSensitivity: Float = 2.5) {
        self.sensitivity = sensitivity
        self.smoothing = smoothing
        self.stealthMode = stealthMode
        self.trackingMode = trackingMode
        self.protocolMode = protocolMode
        self.maxAngle = maxAngle
        self.rangeScale = rangeScale
        self.eyeSensitivity = eyeSensitivity
    }
    
    static let `default` = TrackingSettings()
}
