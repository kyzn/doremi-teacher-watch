import Combine
import Foundation
import WatchKit

/// One "Hear → Guess" round: awaitingPlayback → playing → awaitingAnswer → feedback.
/// Same guarantees as Morse Teacher: main-actor transitions, one result per question, stale
/// playback callbacks ignored, an interrupted playback demands a full replay.
@MainActor
final class ListeningSession: ObservableObject {
    enum Phase: Equatable {
        case awaitingPlayback
        case playing
        case awaitingAnswer
        case feedback(chosen: PitchClass)
    }

    static let targetDuration: TimeInterval = 0.85

    @Published private(set) var question: ListeningQuestion
    @Published private(set) var phase: Phase = .awaitingPlayback
    @Published private(set) var isPlaying = false
    @Published private(set) var playbackError: String?
    @Published private(set) var hasHeardQuestion = false

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
        if case let .feedback(chosen) = phase { return chosen == question.target }
        return nil
    }

    /// Just the target. Same timbre and length for every note so they carry no clue.
    var playbackSegments: [ToneSegment] {
        [.tone(question.targetFrequency, Self.targetDuration)]
    }

    func play() {
        guard !isPlaying else { return }
        let questionID = question.id
        isPlaying = true
        playbackError = nil

        if case .feedback = phase {
            player.play(playbackSegments) { [weak self] _ in
                guard let self, self.question.id == questionID else { return }
                self.isPlaying = false
            }
            return
        }

        phase = .playing
        player.play(playbackSegments) { [weak self] outcome in
            guard let self, self.question.id == questionID else { return }
            self.isPlaying = false
            switch outcome {
            case .finished:
                self.hasHeardQuestion = true
                self.phase = .awaitingAnswer
            case .cancelled:
                self.hasHeardQuestion = false
                self.phase = .awaitingPlayback
            case let .failed(message):
                self.hasHeardQuestion = false
                self.playbackError = message
                self.phase = .awaitingPlayback
            }
        }
    }

    func answer(_ pitch: PitchClass) {
        guard phase == .awaitingAnswer, recordedQuestionID != question.id else { return }
        recordedQuestionID = question.id
        let correct = pitch == question.target
        phase = .feedback(chosen: pitch)
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
        isPlaying = false
        question = nextQuestion(question.target)
        phase = .awaitingPlayback
        playbackError = nil
        hasHeardQuestion = false
        play()
    }

    func autoplayIfFresh() {
        guard phase == .awaitingPlayback, !hasHeardQuestion, playbackError == nil else { return }
        play()
    }

    #if DEBUG
    func applyDemo(correct: Bool) {
        let chosen = correct ? question.target : question.choices.first { $0 != question.target }!
        recordedQuestionID = question.id
        hasHeardQuestion = true
        phase = .feedback(chosen: chosen)
    }
    #endif

    func leave() {
        player.stop()
        isPlaying = false
    }
}
