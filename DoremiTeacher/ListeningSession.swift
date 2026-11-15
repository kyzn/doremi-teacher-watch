import Combine
import Foundation
import WatchKit

/// One "Hear → Guess" round: awaitingPlayback → playing → awaitingAnswer → feedback.
/// Same guarantees as Morse Teacher: main-actor transitions, one result per question, stale
/// playback callbacks ignored. A first play that is cut short demands a full replay; a replay
/// that is cut short leaves the answers open, because the note was already heard in full.
///
/// `phase` is the whole state. `isPlaying`, `playbackError` and `hasHeardQuestion` are read
/// from it, so they cannot disagree with it (see docs/STATE_MACHINES.md §1).
@MainActor
final class ListeningSession: ObservableObject {
    enum Phase: Equatable {
        /// Not heard in full yet. `error` is the last playback failure, shown as "Retry".
        case awaitingPlayback(error: String?)
        /// `replay` is true when the note was already heard in full before this play.
        case playing(replay: Bool)
        /// Heard in full; answers open. `error` is a failed replay.
        case awaitingAnswer(error: String?)
        case feedback(chosen: PitchClass, replaying: Bool, error: String?)

        static let fresh = Phase.awaitingPlayback(error: nil)
        static let ready = Phase.awaitingAnswer(error: nil)
    }

    static let targetDuration: TimeInterval = 0.85

    @Published private(set) var question: ListeningQuestion
    @Published private(set) var phase: Phase = .fresh

    private let player: TonePlaying
    private let nextQuestion: (PitchClass?) -> ListeningQuestion
    private let onResult: (PracticeResult) -> Void
    private let haptics: (WKHapticType) -> Void
    private var recordedQuestionID: UUID?

    init(
        player: TonePlaying,
        nextQuestion: @escaping (PitchClass?) -> ListeningQuestion,
        onResult: @escaping (PracticeResult) -> Void,
        haptics: @escaping (WKHapticType) -> Void = { WKInterfaceDevice.current().play($0) }
    ) {
        self.player = player
        self.nextQuestion = nextQuestion
        self.onResult = onResult
        self.haptics = haptics
        question = nextQuestion(nil)
    }

    var isCorrect: Bool? {
        if case let .feedback(chosen, _, _) = phase { return chosen == question.target }
        return nil
    }

    var isPlaying: Bool {
        switch phase {
        case .playing, .feedback(_, true, _): return true
        default: return false
        }
    }

    var playbackError: String? {
        switch phase {
        case let .awaitingPlayback(error), let .awaitingAnswer(error), let .feedback(_, _, error): return error
        case .playing: return nil
        }
    }

    var hasHeardQuestion: Bool {
        switch phase {
        case .awaitingPlayback, .playing(replay: false): return false
        case .playing(replay: true), .awaitingAnswer, .feedback: return true
        }
    }

    var canAnswer: Bool {
        if case .awaitingAnswer = phase { return true }
        return false
    }

    /// Just the target. Same timbre and length for every note so they carry no clue.
    var playbackSegments: [ToneSegment] {
        [.tone(question.targetFrequency, Self.targetDuration)]
    }

    func play() {
        let questionID = question.id
        switch phase {
        case .playing, .feedback(_, true, _):
            return

        case let .feedback(chosen, false, _):
            // Hear again: never scores, and a failure is shown on the feedback screen.
            phase = .feedback(chosen: chosen, replaying: true, error: nil)
            player.play(playbackSegments) { [weak self] outcome in
                guard let self, self.question.id == questionID,
                      case .feedback(chosen, true, _) = self.phase else { return }
                self.phase = .feedback(chosen: chosen, replaying: false, error: outcome.errorMessage)
            }

        case .awaitingPlayback, .awaitingAnswer:
            let replay = hasHeardQuestion
            phase = .playing(replay: replay)
            player.play(playbackSegments) { [weak self] outcome in
                guard let self, self.question.id == questionID, case .playing = self.phase else { return }
                switch outcome {
                case .finished:
                    self.phase = .ready
                case .cancelled:
                    // A first play heard part of the note at best; a replay was heard in full before.
                    self.phase = replay ? .ready : .fresh
                case let .failed(message):
                    self.phase = replay ? .awaitingAnswer(error: message) : .awaitingPlayback(error: message)
                }
            }
        }
    }

    func answer(_ pitch: PitchClass) {
        guard canAnswer, recordedQuestionID != question.id else { return }
        recordedQuestionID = question.id
        let correct = pitch == question.target
        phase = .feedback(chosen: pitch, replaying: false, error: nil)
        onResult(PracticeResult(
            questionID: question.id,
            mode: .listening,
            bucket: StatsBucket(mode: .listening, noteSet: question.noteSet),
            isCorrect: correct
        ))
        haptics(correct ? .success : .failure)
    }

    func next() {
        player.cancel()
        question = nextQuestion(question.target)
        phase = .fresh
        play()
    }

    func autoplayIfFresh() {
        guard phase == .fresh else { return }
        play()
    }

    #if DEBUG
    func applyDemo(correct: Bool) {
        let chosen = correct ? question.target : question.choices.first { $0 != question.target }!
        recordedQuestionID = question.id
        phase = .feedback(chosen: chosen, replaying: false, error: nil)
    }
    #endif

    func leave() {
        player.stop()
    }
}
