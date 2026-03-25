import SwiftUI
import ARKit

struct ARSceneView: UIViewRepresentable {
    @EnvironmentObject var trackingManager: ARTrackingManager
    
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = trackingManager.session ?? ARSession()
        view.automaticallyUpdatesLighting = true
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        if ARFaceTrackingConfiguration.supportsFrameSemantics(.faceLandmarks) {
            configuration.frameSemantics = [.faceLandmarks]
        }
        
        view.session.run(configuration)
        
        return view
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Updates handled by ARTrackingManager
    }
}
