import WatchKit
import XCTest
@testable import Doremi_Teacher_Watch_App

@MainActor
final class FakeTonePlayer: TonePlaying {
    private(set) var played: [[ToneSegment]] = []
    private(set) var stopCount = 0
    private var pending: ((PlaybackOutcome) -> Void)?

    func play(_ segments: [ToneSegment], completion: @escaping (PlaybackOutcome) -> Void) {
        stop()
        played.append(segments)
        pending = completion
    }

    func cancel() {
        let callback = pending
        pending = nil
        callback?(.cancelled)
    }

    func stop() {
        stopCount += 1
        cancel()
    }

    func finish() { let c = pending; pending = nil; c?(.finished) }
    func fail(_ message: String = "boom") { let c = pending; pending = nil; c?(.failed(message)) }
}

@MainActor
final class ListeningSessionTests: XCTestCase {
    private var player: FakeTonePlayer!
    private var results: [PracticeResult] = []
    private var haptics: [WKHapticType] = []
    private var session: ListeningSession!

    private func makeSession(_ settings: PracticeSettings = .default) {
        player = FakeTonePlayer()
        results = []
        haptics = []
        var generator = QuestionGenerator(rng: SeededRandomNumberGenerator(seed: 42))
        session = ListeningSession(
            player: player,
            nextQuestion: { generator.listeningQuestion(settings: settings, avoiding: $0) },
            onResult: { [unowned self] in results.append($0) },
            haptics: { [unowned self] in haptics.append($0) }
        )
    }

    override func setUp() {
        super.setUp()
        makeSession()
    }

    private func wrongChoice() -> PitchClass {
        session.question.choices.first { $0 != session.question.target }!
    }

    func testPlaybackIsJustTheTarget() {
        session.play()
        let segments = player.played[0]
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].frequencyHz!, session.question.targetFrequency)
        XCTAssertEqual(segments[0].duration, ListeningSession.targetDuration)
    }

    func testInstrumentNamingTransposesTheTarget() {
        var s = PracticeSettings.default
        s.naming = sazNaming
        makeSession(s)
        session.play()
        let written = session.question.target
        XCTAssertEqual(player.played[0][0].frequencyHz!, sazNaming.frequency(forWritten: written))
        XCTAssertNotEqual(player.played[0][0].frequencyHz!, NoteNaming().frequency(forWritten: written))
    }

    func testHappyPathRecordsExactlyOneCorrectResult() {
        session.play(); player.finish()
        XCTAssertEqual(session.phase, .ready)
        session.answer(session.question.target)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].isCorrect)
        XCTAssertEqual(results[0].bucket, StatsBucket(mode: .listening, noteSet: .seven))
        XCTAssertEqual(haptics, [.success])
        session.answer(wrongChoice())
        XCTAssertEqual(results.count, 1)
    }

    func testWrongAnswer() {
        session.play(); player.finish()
        session.answer(wrongChoice())
        XCTAssertEqual(session.isCorrect, false)
        XCTAssertEqual(results.map(\.isCorrect), [false])
        XCTAssertEqual(haptics, [.failure])
    }

    func testAnswerIgnoredBeforeAndDuringPlayback() {
        session.answer(session.question.target)
        session.play()
        session.answer(session.question.target)
        XCTAssertTrue(results.isEmpty)
    }

    func testCancelledPlaybackRequiresFullReplay() {
        session.play()
        player.stop()
        XCTAssertEqual(session.phase, .fresh)
        XCTAssertFalse(session.hasHeardQuestion)
    }

    func testFailedPlaybackShowsError() {
        session.play(); player.fail("no sound")
        XCTAssertEqual(session.playbackError, "no sound")
        XCTAssertEqual(session.phase, .awaitingPlayback(error: "no sound"))
        session.autoplayIfFresh()
        XCTAssertEqual(player.played.count, 1)
    }

    func testHearAgainInFeedbackDoesNotRecord() {
        session.play(); player.finish()
        session.answer(session.question.target)
        session.play()
        XCTAssertTrue(session.isPlaying)
        player.finish()
        XCTAssertEqual(results.count, 1)
    }

    func testNextAutoplaysAndChangesTarget() {
        session.play(); player.finish()
        let first = session.question
        session.answer(first.target)
        session.next()
        XCTAssertNotEqual(session.question.id, first.id)
        XCTAssertNotEqual(session.question.target, first.target)
        XCTAssertEqual(session.phase, .playing(replay: false))
        player.finish()
        session.answer(session.question.target)
        XCTAssertEqual(results.count, 2)
    }

    func testAutoplayOnlyWhenFresh() {
        session.autoplayIfFresh()
        XCTAssertEqual(player.played.count, 1)
        player.finish()
        session.autoplayIfFresh()
        XCTAssertEqual(player.played.count, 1)
    }

    // MARK: Regression tests from docs/STATE_MACHINES.md

    /// D1: a Replay cut short (wrist down) keeps the answers open; the note was heard in full.
    func testCancelledReplayKeepsAnswersOpen() {
        session.play(); player.finish()
        session.play()
        XCTAssertEqual(session.phase, .playing(replay: true))
        XCTAssertTrue(session.hasHeardQuestion)
        XCTAssertFalse(session.canAnswer)
        player.stop()
        XCTAssertEqual(session.phase, .ready)
        session.answer(session.question.target)
        XCTAssertEqual(results.count, 1)
    }

    func testFailedReplayKeepsAnswersOpenAndShowsError() {
        session.play(); player.finish()
        session.play(); player.fail("no sound")
        XCTAssertEqual(session.phase, .awaitingAnswer(error: "no sound"))
        XCTAssertTrue(session.canAnswer)
        session.play()
        XCTAssertNil(session.playbackError, "a new attempt clears the error")
        player.finish()
        XCTAssertEqual(session.phase, .ready)
    }

    /// B1: Hear again failing used to be ignored; the feedback screen now gets the error.
    func testFailedHearAgainShowsErrorWithoutRecording() {
        session.play(); player.finish()
        let target = session.question.target
        session.answer(target)
        session.play(); player.fail("no sound")
        XCTAssertEqual(session.phase, .feedback(chosen: target, replaying: false, error: "no sound"))
        XCTAssertEqual(session.playbackError, "no sound")
        XCTAssertFalse(session.isPlaying)
        session.play()
        XCTAssertEqual(session.phase, .feedback(chosen: target, replaying: true, error: nil))
        player.finish()
        XCTAssertNil(session.playbackError)
        XCTAssertEqual(results.count, 1)
    }

    func testPlayIgnoredWhilePlaying() {
        session.play()
        session.play()
        XCTAssertEqual(player.played.count, 1)
        player.finish()
        session.answer(session.question.target)
        session.play()
        session.play()
        XCTAssertEqual(player.played.count, 2)
    }

    func testNextDuringHearAgainStartsTheNewQuestion() {
        session.play(); player.finish()
        let first = session.question
        session.answer(first.target)
        session.play()
        session.next()
        XCTAssertNotEqual(session.question.id, first.id)
        XCTAssertEqual(session.phase, .playing(replay: false))
        player.finish()
        XCTAssertEqual(session.phase, .ready)
    }

    func testLeaveWhilePlayingReturnsToFresh() {
        session.play()
        session.leave()
        XCTAssertEqual(session.phase, .fresh)
        XCTAssertFalse(session.isPlaying)
    }
}
