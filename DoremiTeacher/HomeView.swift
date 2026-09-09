import SwiftUI

/// Three rows for v1. Note → Hum is deferred (see TODO.md), so it has no row yet.
struct HomeView: View {
    @EnvironmentObject private var tonePlayer: TonePlayer
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var stats: StatsStore
    @State private var demo = DemoLaunch.requested

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 8) {
                    NavigationLink(destination: ListeningView(player: tonePlayer, settings: settings, stats: stats)) {
                        Text("Hear → Guess")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.accentColor)

                    NavigationLink(destination: StatsView()) {
                        Text("Stats")
                            .frame(maxWidth: .infinity)
                    }

                    NavigationLink(destination: SettingsView()) {
                        Text("Settings")
                            .frame(maxWidth: .infinity)
                    }

                    #if DEBUG
                    NavigationLink(destination: ToneCheckView()) {
                        Text("Tone check")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.orange)
                    #endif
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .background(demoLinks)
            }
        }
    }

    @ViewBuilder
    private var demoLinks: some View {
        #if DEBUG
        NavigationLink(
            destination: ListeningView(player: tonePlayer, settings: settings, stats: stats, demo: demo),
            isActive: demoBinding(for: [.listening, .feedbackCorrect, .feedbackWrong])
        ) { EmptyView() }
            .hidden()
        NavigationLink(destination: SettingsView(), isActive: demoBinding(for: [.settings])) { EmptyView() }
            .hidden()
        NavigationLink(destination: InstrumentView(), isActive: demoBinding(for: [.instrument])) { EmptyView() }
            .hidden()
        NavigationLink(destination: StatsView(), isActive: demoBinding(for: [.stats])) { EmptyView() }
            .hidden()
        #endif
    }

    private func demoBinding(for screens: [DemoLaunch]) -> Binding<Bool> {
        Binding(
            get: { demo.map(screens.contains) ?? false },
            set: { active in
                if active { demo = demo ?? screens[0] } else { demo = nil }
            }
        )
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(TonePlayer())
            .environmentObject(SettingsStore())
            .environmentObject(StatsStore())
    }
}
