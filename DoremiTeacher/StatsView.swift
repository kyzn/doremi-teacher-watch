import SwiftUI

/// Three swipeable pages: everything, seven-note rounds, sharps/flats rounds. Each page shows
/// Today and All time with correct and wrong counts and their shares.
struct StatsView: View {
    @EnvironmentObject private var stats: StatsStore
    @State private var page = DemoLaunch.statsPage ?? 0
    @State private var midnightTimer: Timer?

    var body: some View {
        TabView(selection: $page) {
            StatsPage(title: "Total",
                      today: stats.snapshot.today.total(mode: .listening),
                      lifetime: stats.snapshot.lifetime.total(mode: .listening),
                      saveError: stats.saveError)
                .tag(0)
            StatsPage(title: "Seven notes",
                      today: stats.snapshot.today.total(mode: .listening, noteSet: .seven),
                      lifetime: stats.snapshot.lifetime.total(mode: .listening, noteSet: .seven),
                      saveError: stats.saveError)
                .tag(1)
            StatsPage(title: "With sharps/flats",
                      today: stats.snapshot.today.total(mode: .listening, noteSet: .twelve),
                      lifetime: stats.snapshot.lifetime.total(mode: .listening, noteSet: .twelve),
                      saveError: stats.saveError)
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
        .onAppear {
            stats.refreshDay()
            scheduleMidnightRefresh()
        }
        .onDisappear {
            midnightTimer?.invalidate()
            midnightTimer = nil
        }
    }

    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()
        guard let midnight = stats.nextMidnight() else { return }
        let timer = Timer(fire: midnight.addingTimeInterval(1), interval: 0, repeats: false) { _ in
            Task { @MainActor in
                stats.refreshDay()
                scheduleMidnightRefresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        midnightTimer = timer
    }
}

private struct StatsPage: View {
    let title: LocalizedStringKey
    let today: ModeCounters
    let lifetime: ModeCounters
    let saveError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatsSection(title: "Today", counters: today)
                StatsSection(title: "All time", counters: lifetime)
                if let saveError {
                    Text(verbatim: saveError)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.bottom, 18)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}

private struct StatsSection: View {
    let title: LocalizedStringKey
    let counters: ModeCounters

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            StatRow(label: "Correct", value: counters.correct, percent: counters.accuracyPercent)
            StatRow(label: "Wrong", value: counters.wrong, percent: counters.wrongPercent)
        }
    }
}

private struct StatRow: View {
    let label: LocalizedStringKey
    let value: Int
    let percent: Int?

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
            Spacer()
            Text(verbatim: String(value))
                .font(.body.monospacedDigit().weight(.semibold))
            Text(verbatim: percentText)
                .font(.footnote.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 38, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var percentText: String {
        guard let percent else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Double(percent) / 100)) ?? "\(percent)%"
    }
}
