import SwiftUI

extension Notification.Name {
    static let startListening = Notification.Name("startListening")
    static let stopListening = Notification.Name("stopListening")
    static let recenter = Notification.Name("recenter")
    static let showSettings = Notification.Name("showSettings")
}

@main
struct LidarSightApp: App {
    @State private var showLaunchScreen = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandMenu("Tracker") {
                Button("Start Listening") {
                    NotificationCenter.default.post(name: .startListening, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Button("Stop Listening") {
                    NotificationCenter.default.post(name: .stopListening, object: nil)
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Recenter") {
                    NotificationCenter.default.post(name: .recenter, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Divider()
                
                Button("Settings...") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

struct LaunchScreenView: View {
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
