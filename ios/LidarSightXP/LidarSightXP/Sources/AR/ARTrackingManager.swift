import Foundation
import ARKit
import Combine

@MainActor
class ARTrackingManager: NSObject, ObservableObject {
    @Published var currentPose: HeadPose = HeadPose()
    @Published var isTracking: Bool = false
    @Published var isFaceDetected: Bool = false
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var trackingMode: TrackingMode = .faceTracking
    
    private var session: ARSession?
    var arSession: ARSession? { session }
    private var faceConfiguration: ARFaceTrackingConfiguration?
    private var worldConfiguration: ARWorldTrackingConfiguration?
    private var packetId: UInt32 = 0
    
    private var transportManager: TransportManager?
    private var calibrationManager: CalibrationManager?
    
    var onPoseUpdate: ((HeadPose) -> Void)?
    
    override init() {
        super.init()
        setupThermalMonitoring()
    }
    
    func setTransportManager(_ manager: TransportManager) {
        self.transportManager = manager
    }
    
    func setCalibrationManager(_ manager: CalibrationManager) {
        self.calibrationManager = manager
    }
    
    private func setupThermalMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.handleThermalChange()
            }
        }
    }
    
    private func handleThermalChange() {
        guard let config = getCurrentConfiguration() else { return }
        
        if thermalState == .critical || thermalState == .serious {
            config.frameSemantics = []
        }
        
        session?.run(config)
    }
    
    private func getCurrentConfiguration() -> ARConfiguration? {
        switch trackingMode {
        case .faceTracking:
            return faceConfiguration
        case .lidar:
            return worldConfiguration
        }
    }
    
    static var isLidarSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
    
    func startTracking() {
        switch trackingMode {
        case .faceTracking:
            startFaceTracking()
        case .lidar:
            startLidarTracking()
        }
    }
    
    private func startFaceTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking not supported on this device")
            return
        }
        
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        
        faceConfiguration = config
        session = ARSession()
        session?.delegate = self
        session?.run(config)
        
        isTracking = true
    }
    
    private func startLidarTracking() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("World tracking not supported on this device")
            return
        }
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        
        worldConfiguration = config
        session = ARSession()
        session?.delegate = self
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
            currentPose = HeadPose(isValid: false)
            return
        }
        
        let transform = anchor.transform
        
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        let rotation = extractEulerAngles(from: transform)
        
        var pose = HeadPose(
            position: position,
            rotation: rotation,
            timestamp: CACurrentMediaTime(),
            isValid: true
        )
        
        if let calibration = calibrationManager {
            pose = calibration.applyCalibration(to: pose)
        }
        
        currentPose = pose
        packetId += 1
        
        onPoseUpdate?(pose)
        
        transportManager?.sendPose(pose)
    }
    
    private func processARAnchor(_ anchor: ARAnchor) {
        let transform = anchor.transform
        
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        let rotation = extractEulerAngles(from: transform)
        
        var pose = HeadPose(
            position: position,
            rotation: rotation,
            timestamp: CACurrentMediaTime(),
            isValid: true
        )
        
        if let calibration = calibrationManager {
            pose = calibration.applyCalibration(to: pose)
        }
        
        currentPose = pose
        isFaceDetected = true
        packetId += 1
        
        onPoseUpdate?(pose)
        
        transportManager?.sendPose(pose)
    }
    
    private func extractEulerAngles(from transform: simd_float4x4) -> SIMD3<Float> {
        let quaternion = simd_quatf(transform)
        
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

extension ARTrackingManager: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            Task { @MainActor in
                if let faceAnchor = anchor as? ARFaceAnchor {
                    self.processFaceAnchor(faceAnchor)
                } else if self.trackingMode == .lidar {
                    self.processARAnchor(anchor)
                }
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @MainActor in
            self.trackingState = camera.trackingState
        }
    }
}
