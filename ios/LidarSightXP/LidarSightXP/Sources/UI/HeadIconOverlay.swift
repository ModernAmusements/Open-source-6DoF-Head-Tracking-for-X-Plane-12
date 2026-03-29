import SwiftUI

struct HeadIconOverlay: View {
    @EnvironmentObject var trackingManager: ARTrackingManager
    
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    
    private let maxOffset: CGFloat = 60
    
    var body: some View {
        ZStack {
            Circle()
                .fill(trackingManager.isFaceDetected ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(trackingManager.isFaceDetected ? .green : .red)
                )
                .offset(x: offsetX, y: offsetY)
                .animation(.easeOut(duration: 0.15), value: offsetX)
                .animation(.easeOut(duration: 0.15), value: offsetY)
            
            VStack {
                HStack {
                    Image(systemName: trackingManager.isFaceDetected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(trackingManager.isFaceDetected ? .green : .red)
                    Text(trackingManager.isFaceDetected ? "Tracking" : "No Face")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .padding(.leading, 20)
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: trackingManager.currentPose) { pose in
            updateOffset(from: pose)
        }
    }
    
    private func updateOffset(from pose: HeadPose) {
        let rotation = pose.rotation
        
        let yawValue: Float = rotation.y / 45.0
        let pitchValue: Float = rotation.x / 30.0
        
        let yawPercent = CGFloat(max(-1.0, min(1.0, yawValue)))
        let pitchPercent = CGFloat(max(-1.0, min(1.0, pitchValue)))
        
        offsetX = yawPercent * maxOffset
        offsetY = -pitchPercent * maxOffset
    }
}
