import SwiftUI

/// Three rows for v1. Note → Hum is deferred (see TODO.md), so it has no row yet.
struct HomeView: View {
    @EnvironmentObject private var tonePlayer: TonePlayer

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 8) {
                    NavigationLink(destination: PlaceholderView()) {
                        Text("Hear → Guess")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.accentColor)

                    NavigationLink(destination: PlaceholderView()) {
                        Text("Stats")
                            .frame(maxWidth: .infinity)
                    }

                    NavigationLink(destination: PlaceholderView()) {
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
            }
        }
    }
}

/// Stands in for a screen until it lands in its own delivery step.
struct PlaceholderView: View {
    var body: some View {
        Text("Coming soon")
            .foregroundColor(.secondary)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(TonePlayer())
    }
}
