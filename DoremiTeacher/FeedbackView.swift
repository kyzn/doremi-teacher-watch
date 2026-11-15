import SwiftUI

/// Result screen: verdict, the answer, what was chosen when wrong, Hear again / Next.
/// Under an instrument mapping the concert sound is shown too ("sounds E").
struct FeedbackView: View {
    let isCorrect: Bool
    let question: ListeningQuestion
    let chosen: PitchClass
    let isPlaying: Bool
    /// The last Hear again could not play. The speaker button turns red, like Retry on the
    /// question screen, so a silent failure is visible.
    let playbackFailed: Bool
    let hearAgain: () -> Void
    let next: () -> Void

    private let script = SyllableScript.forCurrentLocale()

    var body: some View {
        VStack(spacing: 2) {
            Text(isCorrect ? "Correct" : "Not quite")
                .font(.headline)
                .foregroundColor(isCorrect ? .green : .red)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: question.label(for: question.target, script: script))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 0) {
                    // The other spelling of an altered note (D♭ for C♯), then the concert
                    // sound under an instrument mapping.
                    if let other = question.naming.alternateLabel(forWritten: question.target, script: script) {
                        Text("also \(other)")
                    }
                    if let sounds = concertNote(for: question.target) {
                        Text("sounds \(sounds)")
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: question.naming.spokenLabel(forWritten: question.target, script: script)))

            if !isCorrect {
                let chosenLabel = question.label(for: chosen, script: script)
                if let sounds = concertNote(for: chosen) {
                    Text("You chose \(chosenLabel), sounds \(sounds)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("You chose \(chosenLabel)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button(action: hearAgain) {
                    Image(systemName: playbackFailed ? "exclamationmark.triangle.fill" : "speaker.wave.2.fill")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(FillButtonStyle(tint: playbackFailed ? .red : nil))
                .frame(width: 48)
                .disabled(isPlaying)
                .accessibilityLabel(Text("Hear again"))
                .accessibilityValue(playbackFailed ? Text("Sound unavailable") : Text(verbatim: ""))

                Button(action: next) {
                    Label("Next", systemImage: "arrow.right")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(FillButtonStyle(tint: .accentColor))

                VolumeIndicator()
            }
            .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// Concert letter when it differs from the written name; nil under standard naming.
    private func concertNote(for pitch: PitchClass) -> String? {
        guard question.naming.transpositionCents != 0 else { return nil }
        return question.naming.concertLabel(forWritten: pitch)
    }
}
