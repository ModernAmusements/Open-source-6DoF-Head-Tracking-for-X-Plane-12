import Foundation
import Combine
import simd

@MainActor
class CalibrationManager: ObservableObject {
    @Published var calibrationOffset: CalibrationOffset = CalibrationOffset()
    @Published var isCalibrated: Bool = false
    
    init() {
        loadCalibration()
    }
    
    func calibrate(pose: HeadPose) {
        calibrationOffset = CalibrationOffset(
            position: pose.position,
            rotation: pose.rotation
        )
        isCalibrated = calibrationOffset != CalibrationOffset()
        saveCalibration()
    }
    
    func resetCalibration() {
        calibrationOffset = CalibrationOffset()
        isCalibrated = false
        saveCalibration()
    }
    
    private func normalizeAngle(_ angle: Float) -> Float {
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a > 180 { a -= 360 }
        if a < -180 { a += 360 }
        return a
    }
    
    func applyCalibration(to pose: HeadPose) -> HeadPose {
        var calibrated = pose
        calibrated.position = pose.position - calibrationOffset.position
        calibrated.rotation = SIMD3<Float>(
            normalizeAngle(pose.rotation.x - calibrationOffset.rotation.x),
            normalizeAngle(pose.rotation.y - calibrationOffset.rotation.y),
            normalizeAngle(pose.rotation.z - calibrationOffset.rotation.z)
        )
        return calibrated
    }
    
    private func saveCalibration() {
        if let data = try? JSONEncoder().encode(calibrationOffset) {
            UserDefaults.standard.set(data, forKey: "calibrationOffset")
        }
    }
    
    private func loadCalibration() {
        if let data = UserDefaults.standard.data(forKey: "calibrationOffset"),
           let saved = try? JSONDecoder().decode(CalibrationOffset.self, from: data) {
            calibrationOffset = saved
            isCalibrated = saved != CalibrationOffset()
        }
    }
}
