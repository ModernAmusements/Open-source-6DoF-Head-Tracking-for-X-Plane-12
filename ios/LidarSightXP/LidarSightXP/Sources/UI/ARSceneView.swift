import SwiftUI
import ARKit

struct ARSceneView: UIViewRepresentable {
    @EnvironmentObject var trackingManager: ARTrackingManager
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        
        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            configuration.isLightEstimationEnabled = true
            
            if ARFaceTrackingConfiguration.supportsFrameSemantics(.faceLandmarks) {
                configuration.frameSemantics = [.faceLandmarks]
            }
            
            arView.session.run(configuration)
        }
        
        arView.automaticallyUpdatesLighting = true
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Updates handled by ARTrackingManager via session delegate
    }
    
    static var dismantleAction: ((UIViewRepresentableContext<ARSceneView>, ARSCNView) -> Void)? {
        return { _, arView in
            arView.session.pause()
        }
    }
}
