import SwiftUI
import Combine

@main
struct LidarSightXPApp: App {
    @StateObject private var trackingManager = ARTrackingManager()
    @StateObject private var transportManager = TransportManager()
    @StateObject private var calibrationManager = CalibrationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(trackingManager)
                .environmentObject(transportManager)
                .environmentObject(calibrationManager)
                .onAppear {
                    trackingManager.setTransportManager(transportManager)
                    trackingManager.setCalibrationManager(calibrationManager)
                }
        }
    }
}
