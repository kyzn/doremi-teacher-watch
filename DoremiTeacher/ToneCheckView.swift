#if DEBUG
import SwiftUI

/// Debug-only wrist experiment for step 1: which register is audible on the watch speaker.
/// Naturals from C4 to B6, each a 700 ms sine. Removed from Release builds by the `#if`.
struct ToneCheckView: View {
    @EnvironmentObject private var tonePlayer: TonePlayer

    private struct Note: Identifiable {
        let name: String
        let midi: Double
        var id: Double { midi }
        var hz: Double { PitchMath.frequency(midi: midi) }
    }

    private let notes: [Note] = {
        let naturals: [(String, Double)] = [("C", 0), ("D", 2), ("E", 4), ("F", 5), ("G", 7), ("A", 9), ("B", 11)]
        return [4, 5, 6].flatMap { octave in
            naturals.map { Note(name: "\($0.0)\(octave)", midi: 12 * Double(octave + 1) + $0.1) }
        }
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                VolumeView()
                    .volumeIndicatorFrame()
                ForEach(notes) { note in
                    Button {
                        tonePlayer.play([.tone(note.hz, 0.7)]) { _ in }
                    } label: {
                        HStack {
                            Text(verbatim: note.name)
                                .font(.title3.bold())
                            Spacer()
                            Text(verbatim: String(format: "%.0f Hz", note.hz))
                                .font(.footnote.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onDisappear(perform: tonePlayer.stop)
    }
}
#endif
