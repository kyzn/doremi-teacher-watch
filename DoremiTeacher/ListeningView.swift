import SwiftUI

/// "Hear → Guess": the hidden note plays; the learner picks one of four.
struct ListeningView: View {
    @StateObject private var session: ListeningSession
    private let script = SyllableScript.forCurrentLocale()

    init(player: TonePlayer, settings: SettingsStore, stats: StatsStore, demo: DemoLaunch? = nil) {
        var generator = QuestionGenerator(rng: SystemRandomNumberGenerator())
        let frozen = settings.settings
        let session = ListeningSession(
            player: player,
            nextQuestion: { generator.listeningQuestion(settings: frozen, avoiding: $0) },
            onResult: { stats.record($0) }
        )
        #if DEBUG
        switch demo {
        case .feedbackCorrect: session.applyDemo(correct: true)
        case .feedbackWrong: session.applyDemo(correct: false)
        default: break
        }
        #endif
        _session = StateObject(wrappedValue: session)
    }

    var body: some View {
        Group {
            if case let .feedback(chosen) = session.phase {
                FeedbackView(
                    isCorrect: chosen == session.question.target,
                    question: session.question,
                    chosen: chosen,
                    isPlaying: session.isPlaying,
                    hearAgain: session.play,
                    next: session.next
                )
            } else {
                questionBody
            }
        }
        .onAppear(perform: session.autoplayIfFresh)
        .onDisappear(perform: session.leave)
    }

    private var questionBody: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button(action: session.play) {
                    Label { playTitle } icon: { Image(systemName: playSymbol) }
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(FillButtonStyle(tint: session.playbackError == nil ? .accentColor : .red))
                .disabled(session.isPlaying)

                VolumeView()
                    .volumeIndicatorFrame()
            }
            .frame(height: 38)

            let choices = session.question.choices
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(choices[(row * 2)..<(row * 2 + 2)], id: \.self) { pitch in
                        Button {
                            session.answer(pitch)
                        } label: {
                            Text(verbatim: session.question.label(for: pitch, script: script))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(FillButtonStyle())
                        .accessibilityLabel(Text(verbatim: session.question.naming.spokenLabel(forWritten: pitch, script: script)))
                    }
                }
            }
            .disabled(session.phase != .awaitingAnswer)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var playTitle: Text {
        if session.isPlaying { return Text("Playing…") }
        if session.playbackError != nil { return Text("Retry") }
        return session.hasHeardQuestion ? Text("Replay") : Text("Play")
    }

    private var playSymbol: String {
        if session.playbackError != nil { return "exclamationmark.triangle.fill" }
        return session.hasHeardQuestion ? "arrow.counterclockwise" : "play.fill"
    }
}
