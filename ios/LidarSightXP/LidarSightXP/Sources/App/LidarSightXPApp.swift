import SwiftUI
import Combine

@main
struct LidarSightXPApp: App {
    @StateObject private var trackingManager = ARTrackingManager()
    @StateObject private var transportManager = TransportManager()
    @StateObject private var calibrationManager = CalibrationManager()
    @StateObject private var flightDataManager = FlightDataManager()
    @State private var showLaunchScreen = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchScreen {
                    iOSLaunchScreenView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environmentObject(trackingManager)
                        .environmentObject(transportManager)
                        .environmentObject(calibrationManager)
                        .environmentObject(flightDataManager)
                        .transition(.opacity)
                }
            }
            .onAppear {
                trackingManager.setTransportManager(transportManager)
                trackingManager.setCalibrationManager(calibrationManager)
                flightDataManager.startListening()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                }
            }
            .onDisappear {
                transportManager.stop()
                trackingManager.stopTracking()
                flightDataManager.stopListening()
            }
        }
    }
}

struct iOSLaunchScreenView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("LiDARSight")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding(.top, 20)
            }
        }
    }
}
