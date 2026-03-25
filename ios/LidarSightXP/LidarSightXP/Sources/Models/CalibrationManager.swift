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
    
    func applyCalibration(to pose: HeadPose) -> HeadPose {
        var calibrated = pose
        calibrated.position = pose.position - calibrationOffset.position
        calibrated.rotation = pose.rotation - calibrationOffset.rotation
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
