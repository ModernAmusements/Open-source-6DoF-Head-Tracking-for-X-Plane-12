import SwiftUI
import SceneKit

struct WindshieldView3D: View {
    var pitch: Float
    var yaw: Float
    var roll: Float
    
    var body: some View {
        VStack(spacing: 0) {
            SceneView(
                scene: createScene(),
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .background(Color(red: 0.05, green: 0.08, blue: 0.12))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 2)
            )
            
            HStack {
                Text("Pitch: \(pitch, specifier: "%.1f")°")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Yaw: \(yaw, specifier: "%.1f")°")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Roll: \(roll, specifier: "%.1f")°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
    
    private func createScene() -> SCNScene {
        let scene = SCNScene()
        
        let cockpitGeometry = SCNBox(width: 4, height: 2.5, length: 0.1, chamferRadius: 0.05)
        let cockpitMaterial = SCNMaterial()
        cockpitMaterial.diffuse.contents = NSColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1.0)
        cockpitMaterial.isDoubleSided = true
        cockpitGeometry.materials = [cockpitMaterial]
        
        let cockpit = SCNNode(geometry: cockpitGeometry)
        cockpit.position = SCNVector3(0, 0, 0.5)
        scene.rootNode.addChildNode(cockpit)
        
        let windowGeometry = SCNBox(width: 3.6, height: 2.0, length: 0.02, chamferRadius: 0.02)
        let windowMaterial = SCNMaterial()
        windowMaterial.diffuse.contents = NSColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 0.3)
        windowMaterial.transparency = 0.7
        windowMaterial.isDoubleSided = true
        windowGeometry.materials = [windowMaterial]
        
        let window = SCNNode(geometry: windowGeometry)
        window.position = SCNVector3(0, 0, 0.45)
        scene.rootNode.addChildNode(window)
        
        let crosshair = createCrosshair()
        crosshair.position = SCNVector3(0, 0, 0.3)
        scene.rootNode.addChildNode(crosshair)
        
        let groundGeometry = SCNPlane(width: 100, height: 100)
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = NSColor(red: 0.2, green: 0.35, blue: 0.2, alpha: 1.0)
        groundMaterial.isDoubleSided = true
        groundGeometry.materials = [groundMaterial]
        
        let ground = SCNNode(geometry: groundGeometry)
        ground.position = SCNVector3(0, -2, 10)
        ground.eulerAngles.x = -.pi / 2
        scene.rootNode.addChildNode(ground)
        
        let skyGeometry = SCNSphere(radius: 50)
        let skyMaterial = SCNMaterial()
        skyMaterial.diffuse.contents = NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
        skyMaterial.isDoubleSided = true
        skyGeometry.materials = [skyMaterial]
        
        let sky = SCNNode(geometry: skyGeometry)
        scene.rootNode.addChildNode(sky)
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        
        let clampedPitch = max(-30, min(30, pitch))
        let clampedYaw = max(-60, min(60, yaw))
        let clampedRoll = max(-30, min(30, roll))
        
        cameraNode.eulerAngles = SCNVector3(
            Float(clampedPitch) * .pi / 180.0,
            Float(clampedYaw) * .pi / 180.0,
            Float(clampedRoll) * .pi / 180.0
        )
        
        cameraNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        
        return scene
    }
    
    private func createCrosshair() -> SCNNode {
        let crosshairNode = SCNNode()
        
        let horizontalGeometry = SCNBox(width: 0.4, height: 0.01, length: 0.01, chamferRadius: 0)
        let horizontalMaterial = SCNMaterial()
        horizontalMaterial.diffuse.contents = NSColor.green
        horizontalMaterial.emission.contents = NSColor.green
        horizontalGeometry.materials = [horizontalMaterial]
        
        let horizontal = SCNNode(geometry: horizontalGeometry)
        crosshairNode.addChildNode(horizontal)
        
        let verticalGeometry = SCNBox(width: 0.01, height: 0.3, length: 0.01, chamferRadius: 0)
        let verticalMaterial = SCNMaterial()
        verticalMaterial.diffuse.contents = NSColor.green
        verticalMaterial.emission.contents = NSColor.green
        verticalGeometry.materials = [verticalMaterial]
        
        let vertical = SCNNode(geometry: verticalGeometry)
        crosshairNode.addChildNode(vertical)
        
        let circleGeometry = SCNTorus(ringRadius: 0.15, pipeRadius: 0.005)
        let circleMaterial = SCNMaterial()
        circleMaterial.diffuse.contents = NSColor.green.withAlphaComponent(0.5)
        circleMaterial.emission.contents = NSColor.green.withAlphaComponent(0.3)
        circleGeometry.materials = [circleMaterial]
        
        let circle = SCNNode(geometry: circleGeometry)
        crosshairNode.addChildNode(circle)
        
        return crosshairNode
    }
}

struct WindshieldView3D_Previews: PreviewProvider {
    static var previews: some View {
        WindshieldView3D(pitch: 10, yaw: -20, roll: 5)
            .frame(width: 400, height: 300)
    }
}
