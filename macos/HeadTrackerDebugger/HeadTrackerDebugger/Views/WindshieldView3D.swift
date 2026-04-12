import SwiftUI
import SceneKit

struct WindshieldView3D: View {
    var pitch: Float
    var yaw: Float
    var roll: Float
    
    var body: some View {
        ZStack {
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
            }
            
            CrosshairOverlay(pitch: pitch, yaw: yaw, roll: roll)
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
        
        addReferencePosts(to: scene)
        addFloatingCubes(to: scene)
        addChessboardFloor(to: scene)
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.usesOrthographicProjection = false
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .ambient
        lightNode.light?.intensity = 500
        lightNode.light?.color = NSColor.white
        scene.rootNode.addChildNode(lightNode)
        
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
    
    private func addStaticClouds(to scene: SCNScene) {
        let cloudPositions: [(Float, Float, Float)] = [
            (-15, 8, 20), (10, 10, 25), (-25, 7, 30), (20, 9, 22), (0, 12, 28),
            (-35, 6, 35), (30, 8, 32), (-10, 11, 18), (15, 6, 38), (-30, 10, 26)
        ]
        for (x, y, z) in cloudPositions {
            let cloudGeometry = SCNSphere(radius: 2.0)
            let cloudMaterial = SCNMaterial()
            cloudMaterial.diffuse.contents = NSColor.white.withAlphaComponent(0.8)
            cloudMaterial.transparency = 0.8
            cloudMaterial.isDoubleSided = true
            cloudGeometry.materials = [cloudMaterial]
            
            let cloud = SCNNode(geometry: cloudGeometry)
            cloud.position = SCNVector3(x, y, z)
            cloud.scale = SCNVector3(2.0, 0.6, 1.5)
            scene.rootNode.addChildNode(cloud)
        }
    }
    
    private func addStaticMountains(to scene: SCNScene) {
        let mountainPositions: [(Float, Float, Float, Float)] = [
            (-40, -2, 40, 8), (-20, -2, 45, 12), (0, -2, 50, 15),
            (25, -2, 42, 10), (-35, -2, 48, 6), (15, -2, 38, 7),
            (-50, -2, 35, 5), (40, -2, 44, 9)
        ]
        for (x, y, z, height) in mountainPositions {
            let mountainGeometry = SCNCone(topRadius: 0, bottomRadius: 4, height: CGFloat(height))
            let mountainMaterial = SCNMaterial()
            mountainMaterial.diffuse.contents = NSColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 1.0)
            mountainMaterial.isDoubleSided = true
            mountainGeometry.materials = [mountainMaterial]
            
            let mountain = SCNNode(geometry: mountainGeometry)
            mountain.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(mountain)
        }
    }
    
    private func addReferencePosts(to scene: SCNScene) {
        let angles: [Float] = [-90, -60, -30, 30, 60, 90]
        for angle in angles {
            let radians = angle * .pi / 180
            let distance: Float = 15
            let x = sin(radians) * distance
            let z = cos(radians) * distance
            
            let postGeometry = SCNCylinder(radius: 0.1, height: 3)
            let postMaterial = SCNMaterial()
            postMaterial.diffuse.contents = NSColor.orange
            postMaterial.emission.contents = NSColor.orange
            postGeometry.materials = [postMaterial]
            
            let post = SCNNode(geometry: postGeometry)
            post.position = SCNVector3(x, 0.5, z)
            scene.rootNode.addChildNode(post)
            
            let stripeGeometry = SCNCylinder(radius: 0.12, height: 0.2)
            let stripeMaterial = SCNMaterial()
            stripeMaterial.diffuse.contents = NSColor.white
            stripeGeometry.materials = [stripeMaterial]
            
            let stripe = SCNNode(geometry: stripeGeometry)
            stripe.position = SCNVector3(0, 1, 0)
            post.addChildNode(stripe)
        }
    }
    
    private func addGroundGrid(to scene: SCNScene) {
        let gridNode = SCNNode()
        let gridSize: Float = 100
        let gridSpacing: Float = 5
        
        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = NSColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 0.5)
        lineMaterial.emission.contents = NSColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 0.3)
        
        for i in stride(from: -gridSize/2, through: gridSize/2, by: gridSpacing) {
            let hLine = SCNBox(width: CGFloat(gridSize), height: 0.05, length: 0.05, chamferRadius: 0)
            hLine.materials = [lineMaterial]
            let hNode = SCNNode(geometry: hLine)
            hNode.position = SCNVector3(0, -2.5, CGFloat(i))
            gridNode.addChildNode(hNode)
            
            let vLine = SCNBox(width: 0.05, height: 0.05, length: CGFloat(gridSize), chamferRadius: 0)
            vLine.materials = [lineMaterial]
            let vNode = SCNNode(geometry: vLine)
            vNode.position = SCNVector3(CGFloat(i), -2.5, 0)
            gridNode.addChildNode(vNode)
        }
        
        scene.rootNode.addChildNode(gridNode)
    }
    
    private func addSunAndStars(to scene: SCNScene) {
        let sunGeometry = SCNSphere(radius: 1.5)
        let sunMaterial = SCNMaterial()
        sunMaterial.diffuse.contents = NSColor.yellow
        sunMaterial.emission.contents = NSColor.orange
        sunGeometry.materials = [sunMaterial]
        
        let sun = SCNNode(geometry: sunGeometry)
        sun.position = SCNVector3(30, 25, 40)
        scene.rootNode.addChildNode(sun)
        
        let starPositions: [(Float, Float, Float)] = [
            (-20, 35, 45), (15, 38, 42), (-35, 30, 48), (25, 32, 44),
            (-10, 40, 40), (5, 36, 46), (-40, 28, 43), (35, 34, 41),
            (-25, 42, 38), (10, 28, 49), (-15, 25, 47), (30, 40, 39)
        ]
        for (x, y, z) in starPositions {
            let starGeometry = SCNSphere(radius: 0.2)
            let starMaterial = SCNMaterial()
            starMaterial.diffuse.contents = NSColor.white
            starMaterial.emission.contents = NSColor.white
            starGeometry.materials = [starMaterial]
            
            let star = SCNNode(geometry: starGeometry)
            star.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(star)
        }
    }
    
    private func addFloatingCubes(to scene: SCNScene) {
        let cubePositions: [(Float, Float, Float, Float)] = [
            (-8, 2, 12, 0.5), (12, 3, 15, 0.8), (-15, 1, 18, 0.6),
            (8, 4, 20, 0.4), (-20, 2, 14, 0.7), (18, 1, 16, 0.5),
            (-5, 5, 22, 0.3), (0, 2, 25, 0.9), (-12, 3, 16, 0.4),
            (25, 2, 19, 0.6), (-25, 4, 21, 0.5), (5, 1, 13, 0.7)
        ]
        let colors: [NSColor] = [.red, .blue, .green, .yellow, .orange, .purple, .cyan, .magenta]
        
        for (i, (x, y, z, size)) in cubePositions.enumerated() {
            let cubeGeometry = SCNBox(width: CGFloat(size), height: CGFloat(size), length: CGFloat(size), chamferRadius: 0.1)
            let cubeMaterial = SCNMaterial()
            cubeMaterial.diffuse.contents = colors[i % colors.count]
            cubeMaterial.transparency = 0.7
            cubeGeometry.materials = [cubeMaterial]
            
            let cube = SCNNode(geometry: cubeGeometry)
            cube.position = SCNVector3(x, y, z)
            cube.eulerAngles = SCNVector3(Float(i) * 0.3, Float(i) * 0.5, Float(i) * 0.2)
            scene.rootNode.addChildNode(cube)
        }
    }
    
    private func addChessboardFloor(to scene: SCNScene) {
        let floorSize: Int = 20
        let squareSize: Float = 1.0
        let floorNode = SCNNode()
        
        for row in 0..<floorSize {
            for col in 0..<floorSize {
                let isWhite = (row + col) % 2 == 0
                let squareGeometry = SCNBox(width: CGFloat(squareSize), height: 0.05, length: CGFloat(squareSize), chamferRadius: 0)
                let squareMaterial = SCNMaterial()
                if isWhite {
                    squareMaterial.diffuse.contents = NSColor.white
                } else {
                    squareMaterial.diffuse.contents = NSColor.black
                }
                squareGeometry.materials = [squareMaterial]
                
                let square = SCNNode(geometry: squareGeometry)
                let x = Float(col - floorSize/2) * squareSize
                let z = Float(row - floorSize/2) * squareSize
                square.position = SCNVector3(x, -2.0, z)
                floorNode.addChildNode(square)
            }
        }
        
        scene.rootNode.addChildNode(floorNode)
    }
}

struct WindshieldView3D_Previews: PreviewProvider {
    static var previews: some View {
        WindshieldView3D(pitch: 10, yaw: -20, roll: 5)
            .frame(width: 400, height: 300)
    }
}

struct CrosshairOverlay: View {
    var pitch: Float
    var yaw: Float
    var roll: Float
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Text("P: \(Int(pitch))°")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                    Spacer()
                    Text("Y: \(Int(yaw))°")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                    Spacer()
                    Text("R: \(Int(roll))°")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2, height: 25)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 25, height: 2)
                }
                
                Spacer()
            }
        }
    }
}
