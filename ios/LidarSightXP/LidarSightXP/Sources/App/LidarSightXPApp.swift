import SwiftUI
import Combine

@main
struct LidarSightXPApp: App {
    @StateObject private var trackingManager = ARTrackingManager()
    @StateObject private var transportManager = TransportManager()
    @StateObject private var calibrationManager = CalibrationManager()
    @StateObject private var flightDataManager = FlightDataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(trackingManager)
                .environmentObject(transportManager)
                .environmentObject(calibrationManager)
                .environmentObject(flightDataManager)
                .onAppear {
                    trackingManager.setTransportManager(transportManager)
                    trackingManager.setCalibrationManager(calibrationManager)
                    flightDataManager.startListening()
                }
                .onDisappear {
                    flightDataManager.stopListening()
                }
        }
    }
}
