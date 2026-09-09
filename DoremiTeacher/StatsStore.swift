import Combine
import Foundation

struct ModeCounters: Codable, Equatable {
    var correct = 0
    var wrong = 0

    var answered: Int { correct + wrong }

    var accuracyPercent: Int? {
        guard answered > 0 else { return nil }
        return Int((Double(correct) / Double(answered) * 100).rounded())
    }

    var wrongPercent: Int? {
        guard answered > 0 else { return nil }
        return Int((Double(wrong) / Double(answered) * 100).rounded())
    }

    static func + (lhs: ModeCounters, rhs: ModeCounters) -> ModeCounters {
        ModeCounters(correct: lhs.correct + rhs.correct, wrong: lhs.wrong + rhs.wrong)
    }
}

/// Counters keyed by `StatsBucket.key`, so listening and humming, and each note set, stay
/// separate on disk while the UI sums whatever it wants to show.
struct BucketTotals: Codable, Equatable {
    var counters: [String: ModeCounters] = [:]

    subscript(bucket: StatsBucket) -> ModeCounters {
        get { counters[bucket.key] ?? ModeCounters() }
        set { counters[bucket.key] = newValue }
    }

    var combined: ModeCounters { counters.values.reduce(ModeCounters(), +) }

    func total(mode: PracticeMode) -> ModeCounters {
        counters.filter { StatsBucket(key: $0.key)?.mode == mode }.values.reduce(ModeCounters(), +)
    }

    func total(mode: PracticeMode, noteSet: NoteSet) -> ModeCounters {
        self[StatsBucket(mode: mode, noteSet: noteSet)]
    }
}

struct StatsSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var dayKey: String
    var today = BucketTotals()
    var lifetime = BucketTotals()
    var lastRecordedQuestionID: UUID?
}

/// Persists one small snapshot in UserDefaults and writes it after every recorded answer.
/// Same day-rollover rules as Morse Teacher.
@MainActor
final class StatsStore: ObservableObject {
    static let defaultsKey = "doremi.stats.snapshot"

    @Published private(set) var snapshot: StatsSnapshot
    @Published private(set) var saveError: String?

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now

        let todayKey = Self.dayKey(for: now(), calendar: calendar)
        if let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode(StatsSnapshot.self, from: data),
           stored.schemaVersion == StatsSnapshot.currentSchemaVersion {
            snapshot = stored
        } else {
            snapshot = StatsSnapshot(dayKey: todayKey)
        }
        refreshDay()
    }

    func refreshDay() {
        let key = Self.dayKey(for: now(), calendar: calendar)
        guard key != snapshot.dayKey else { return }
        snapshot.dayKey = key
        snapshot.today = BucketTotals()
        save()
    }

    func record(_ result: PracticeResult) {
        refreshDay()
        guard snapshot.lastRecordedQuestionID != result.questionID else { return }
        snapshot.lastRecordedQuestionID = result.questionID
        if result.isCorrect {
            snapshot.today[result.bucket].correct += 1
            snapshot.lifetime[result.bucket].correct += 1
        } else {
            snapshot.today[result.bucket].wrong += 1
            snapshot.lifetime[result.bucket].wrong += 1
        }
        save()
    }

    func nextMidnight() -> Date? {
        calendar.nextDate(after: now(), matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime)
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.defaultsKey)
            saveError = nil
        } catch {
            saveError = "Stats could not be saved."
        }
    }

    #if DEBUG
    /// In-memory store pre-filled for screenshots: [todayCorrect, todayWrong, lifetimeCorrect, lifetimeWrong] per set.
    static func demo(seven: [Int], twelve: [Int]) -> StatsStore {
        let suite = UserDefaults(suiteName: "doremi.demo.stats")!
        suite.removePersistentDomain(forName: "doremi.demo.stats")
        let store = StatsStore(defaults: suite)
        var snapshot = store.snapshot
        for (set, n) in [(NoteSet.seven, seven), (NoteSet.twelve, twelve)] {
            let bucket = StatsBucket(mode: .listening, noteSet: set)
            snapshot.today[bucket] = ModeCounters(correct: n[0], wrong: n[1])
            snapshot.lifetime[bucket] = ModeCounters(correct: n[2], wrong: n[3])
        }
        store.snapshot = snapshot
        return store
    }
    #endif
}
