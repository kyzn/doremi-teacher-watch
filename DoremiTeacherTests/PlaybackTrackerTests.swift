import XCTest
@testable import Doremi_Teacher_Watch_App

/// The player's bookkeeping (docs/STATE_MACHINES.md §2): exactly one outcome per play, stale
/// callbacks dropped, the stall watchdog's decision, and re-entrant plays.
@MainActor
final class PlaybackTrackerTests: XCTestCase {
    private var tracker: PlaybackTracker!
    private var log: [String] = []

    override func setUp() {
        super.setUp()
        tracker = PlaybackTracker()
        log = []
    }

    private func recorder(_ name: String) -> (PlaybackOutcome) -> Void {
        { [unowned self] outcome in log.append("\(name):\(outcome)") }
    }

    func testFinishDeliversOnce() {
        let g = tracker.begin(recorder("a"))!
        XCTAssertTrue(tracker.isActive)
        XCTAssertTrue(tracker.finish(.finished, generation: g))
        XCTAssertFalse(tracker.finish(.finished, generation: g))
        tracker.cancel()
        XCTAssertEqual(log, ["a:finished"])
        XCTAssertFalse(tracker.isActive)
    }

    func testNewPlayCancelsTheOldOneAndDropsItsLateCallback() {
        let old = tracker.begin(recorder("a"))!
        let new = tracker.begin(recorder("b"))!
        XCTAssertNotEqual(old, new)
        XCTAssertFalse(tracker.finish(.finished, generation: old), "late buffer callback from the stopped sound")
        XCTAssertTrue(tracker.finish(.finished, generation: new))
        XCTAssertEqual(log, ["a:cancelled", "b:finished"])
    }

    func testCancelMakesTheGenerationStale() {
        let g = tracker.begin(recorder("a"))!
        tracker.cancel()
        XCTAssertFalse(tracker.finish(.finished, generation: g))
        XCTAssertEqual(tracker.watchdogFired(generation: g, isRetry: false), .ignore)
        XCTAssertEqual(log, ["a:cancelled"])
    }

    func testWatchdogRetriesOnceThenFails() {
        let g = tracker.begin(recorder("a"))!
        XCTAssertEqual(tracker.watchdogFired(generation: g, isRetry: false), .retry)
        // The player hands the same completion to the replayed sound.
        let pending = tracker.detach()!
        let retry = tracker.begin(pending)!
        XCTAssertEqual(tracker.watchdogFired(generation: g, isRetry: false), .ignore, "the first attempt is stale")
        XCTAssertEqual(tracker.watchdogFired(generation: retry, isRetry: true), .fail)
        tracker.finish(.failed("stalled"), generation: retry)
        XCTAssertEqual(log, ["a:failed(\"stalled\")"])
    }

    func testWatchdogIgnoredAfterFinish() {
        let g = tracker.begin(recorder("a"))!
        tracker.finish(.finished, generation: g)
        XCTAssertEqual(tracker.watchdogFired(generation: g, isRetry: false), .ignore)
    }

    /// G3: a completion that starts a new sound from inside its cancellation. The newer sound
    /// wins; the interrupted `begin` gets `.cancelled` instead of overwriting it.
    func testReentrantPlayFromACancellationKeepsTheNewestOwner() {
        var inner: UInt64?
        _ = tracker.begin { [unowned self] outcome in
            log.append("a:\(outcome)")
            if outcome == .cancelled { inner = tracker.begin(recorder("c")) }
        }
        let outer = tracker.begin(recorder("b"))
        XCTAssertNil(outer)
        XCTAssertNotNil(inner)
        XCTAssertTrue(tracker.finish(.finished, generation: inner!))
        XCTAssertEqual(log, ["a:cancelled", "b:cancelled", "c:finished"])
    }

    func testCompletionMayStartTheNextSound() {
        var second: UInt64?
        let g = tracker.begin { [unowned self] _ in second = tracker.begin(recorder("b")) }!
        tracker.finish(.finished, generation: g)
        XCTAssertTrue(tracker.isActive)
        tracker.finish(.finished, generation: second!)
        XCTAssertEqual(log, ["b:finished"])
    }
}
