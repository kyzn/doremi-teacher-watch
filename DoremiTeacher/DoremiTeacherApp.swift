import SwiftUI

@main
struct DoremiTeacherApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tonePlayer = TonePlayer()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(tonePlayer)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                tonePlayer.stop()
            }
        }
    }
}
