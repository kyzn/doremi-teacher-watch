import XCTest
@testable import Doremi_Teacher_Watch_App

@MainActor
final class StatsStoreTests: XCTestCase {
    private let suiteName = "DoremiTeacherTests.stats"
    private var defaults: UserDefaults!
    private var clock: Date!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        clock = date(2026, 9, 9, 15, 0)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func makeStore() -> StatsStore {
        StatsStore(defaults: defaults, calendar: calendar, now: { [unowned self] in clock })
    }

    private func result(_ set: NoteSet, correct: Bool) -> PracticeResult {
        PracticeResult(questionID: UUID(), mode: .listening, bucket: StatsBucket(mode: .listening, noteSet: set), isCorrect: correct)
    }

    func testBucketsStaySeparateAndSum() {
        let store = makeStore()
        store.record(result(.seven, correct: true))
        store.record(result(.seven, correct: false))
        store.record(result(.twelve, correct: true))
        XCTAssertEqual(store.snapshot.today.total(mode: .listening, noteSet: .seven), ModeCounters(correct: 1, wrong: 1))
        XCTAssertEqual(store.snapshot.today.total(mode: .listening, noteSet: .twelve), ModeCounters(correct: 1, wrong: 0))
        XCTAssertEqual(store.snapshot.today.total(mode: .listening), ModeCounters(correct: 2, wrong: 1))
        XCTAssertEqual(store.snapshot.today.total(mode: .humming), ModeCounters())
    }

    func testDuplicateQuestionIDIsIgnored() {
        let store = makeStore()
        let once = result(.seven, correct: true)
        store.record(once)
        store.record(once)
        XCTAssertEqual(store.snapshot.lifetime.combined, ModeCounters(correct: 1, wrong: 0))
    }

    func testSurvivesRelaunchWithBucketKeys() {
        makeStore().record(result(.twelve, correct: false))
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.snapshot.lifetime.total(mode: .listening, noteSet: .twelve), ModeCounters(correct: 0, wrong: 1))
        XCTAssertEqual(reloaded.snapshot.lifetime.counters.keys.sorted(), ["listening/twelve"])
    }

    func testMidnightResetsTodayButKeepsLifetime() {
        let store = makeStore()
        store.record(result(.seven, correct: true))
        clock = date(2026, 9, 10, 0, 1)
        store.refreshDay()
        XCTAssertEqual(store.snapshot.today.combined.answered, 0)
        XCTAssertEqual(store.snapshot.lifetime.combined.answered, 1)
    }

    func testCorruptDataStartsFresh() {
        defaults.set(Data("nonsense".utf8), forKey: StatsStore.defaultsKey)
        XCTAssertEqual(makeStore().snapshot.lifetime.combined.answered, 0)
    }

    func testBucketKeyRoundTrip() {
        let bucket = StatsBucket(mode: .humming, noteSet: .twelve)
        XCTAssertEqual(StatsBucket(key: bucket.key), bucket)
        XCTAssertNil(StatsBucket(key: "garbage"))
    }
}
