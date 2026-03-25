import SwiftUI
import ARKit
import SceneKit

struct ARSceneView: UIViewRepresentable {
    @EnvironmentObject var trackingManager: ARTrackingManager
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.automaticallyUpdatesLighting = true
        arView.session = ARSession()
        arView.delegate = context.coordinator
        
        if ARFaceTrackingConfiguration.isSupported {
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = true
            config.maximumNumberOfTrackedFaces = 1
            arView.session.run(config)
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARSceneView
        var faceNode: SCNNode?
        
        init(_ parent: ARSceneView) {
            self.parent = parent
        }
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard ARFaceTrackingConfiguration.isSupported,
                  anchor is ARFaceAnchor else { return nil }
            
            guard let device = renderer.device else { return nil }
            
            let faceGeometry = ARSCNFaceGeometry(device: device)
            guard let geometry = faceGeometry else { return nil }
            
            let faceNode = SCNNode(geometry: geometry)
            faceNode.geometry?.firstMaterial?.fillMode = .lines
            faceNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.6)
            faceNode.geometry?.firstMaterial?.isDoubleSided = true
            
            self.faceNode = faceNode
            return faceNode
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }
            guard let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }
            
            faceGeometry.update(from: faceAnchor.geometry)
        }
    }
}
