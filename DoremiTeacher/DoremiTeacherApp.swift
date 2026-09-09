import SwiftUI

@main
struct DoremiTeacherApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tonePlayer = TonePlayer()
    @StateObject private var settings = DemoLaunch.demoSettings() ?? SettingsStore()
    @StateObject private var stats = DemoLaunch.demoStats() ?? StatsStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(tonePlayer)
                .environmentObject(settings)
                .environmentObject(stats)
                .transformEnvironment(\.sizeCategory) { size in
                    if let forced = DemoLaunch.sizeCategory { size = forced }
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                stats.refreshDay()
            } else {
                tonePlayer.stop()
            }
        }
    }
}
