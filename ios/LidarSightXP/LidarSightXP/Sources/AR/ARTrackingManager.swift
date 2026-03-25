import Foundation
import ARKit
import Combine

@MainActor
class ARTrackingManager: ObservableObject {
    @Published var currentPose: HeadPose = .zero
    @Published var isTracking: Bool = false
    @Published var isFaceDetected: Bool = false
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    private var session: ARSession?
    private var configuration: ARFaceTrackingConfiguration?
    private var packetId: UInt32 = 0
    
    var onPoseUpdate: ((HeadPose) -> Void)?
    
    init() {
        setupThermalMonitoring()
    }
    
    private func setupThermalMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thermalState = ProcessInfo.processInfo.thermalState
            self?.handleThermalChange()
        }
    }
    
    private func handleThermalChange() {
        guard let config = configuration else { return }
        
        if thermalState == .critical || thermalState == .serious {
            config.frameSemantics = []
        } else {
            config.frameSemantics = [.faceLandmarks]
        }
        
        session?.run(config)
    }
    
    func startTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking not supported on this device")
            return
        }
        
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        
        if ARFaceTrackingConfiguration.supportsFrameSemantics(.faceLandmarks) {
            config.frameSemantics = [.faceLandmarks]
        }
        
        configuration = config
        session = ARSession()
        session?.delegate = FaceTrackingDelegate.shared
        FaceTrackingDelegate.shared.onFrameUpdate = { [weak self] anchor in
            Task { @MainActor in
                self?.processFaceAnchor(anchor)
            }
        }
        session?.run(config)
        
        isTracking = true
    }
    
    func stopTracking() {
        session?.pause()
        session = nil
        isTracking = false
        isFaceDetected = false
    }
    
    private func processFaceAnchor(_ anchor: ARFaceAnchor) {
        isFaceDetected = anchor.isTracked
        
        guard anchor.isTracked else {
            var invalidPose = currentPose
            invalidPose.isValid = false
            currentPose = invalidPose
            return
        }
        
        let transform = anchor.transform
        
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        let rotation = extractEulerAngles(from: transform)
        
        let pose = HeadPose(
            position: position,
            rotation: rotation,
            timestamp: CACurrentMediaTime(),
            isValid: true
        )
        
        currentPose = pose
        packetId += 1
        
        onPoseUpdate?(pose)
    }
    
    private func extractEulerAngles(from transform: simd_float4x4) -> SIMD3<Float> {
        let quaternion = simd_quatf(transform)
        let eulerAngles = quaternion.act(SIMD3<Float>(1, 0, 0))
        
        let pitch = atan2(2 * (quaternion.real * quaternion.imag.x + quaternion.imag.y * quaternion.imag.z),
                          1 - 2 * (quaternion.imag.x * quaternion.imag.x + quaternion.imag.y * quaternion.imag.y))
        let yaw = asin(2 * (quaternion.real * quaternion.imag.y - quaternion.imag.z * quaternion.imag.x))
        let roll = atan2(2 * (quaternion.real * quaternion.imag.z + quaternion.imag.x * quaternion.imag.y),
                         1 - 2 * (quaternion.imag.y * quaternion.imag.y + quaternion.imag.z * quaternion.imag.z))
        
        return SIMD3<Float>(
            Float(pitch) * 180 / .pi,
            Float(yaw) * 180 / .pi,
            Float(roll) * 180 / .pi
        )
    }
}

class FaceTrackingDelegate: NSObject, ARSessionDelegate {
    static let shared = FaceTrackingDelegate()
    
    var onFrameUpdate: ((ARFaceAnchor) -> Void)?
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let faceAnchor = anchor as? ARFaceAnchor {
                onFrameUpdate?(faceAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .trackingStateChanged,
                object: camera.trackingState
            )
        }
    }
}

extension Notification.Name {
    static let trackingStateChanged = Notification.Name("trackingStateChanged")
}
