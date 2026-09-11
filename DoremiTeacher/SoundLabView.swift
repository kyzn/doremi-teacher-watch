#if DEBUG
import SwiftUI

/// Debug-only bench for tuning loudness on the wrist. Each variation is a register, a gain
/// table and an overtone mix; Play all runs C to B in sequence, the grid plays single notes.
/// Not compiled into Release builds.
struct SoundLabVariation: Identifiable {
    let name: String
    /// MIDI number of the lowest note (72 = C5, 84 = C6).
    let baseMidi: Double
    let gains: [Float]
    let partials: [Float]
    var id: String { name }

    static let sine: [Float] = [1.0]
    static let overtones: [Float] = ToneSynth.partials

    static let all: [SoundLabVariation] = [
        SoundLabVariation(name: "Current (oct 5, table, overtones)", baseMidi: 72,
                          gains: PlaybackRegister.gainTable, partials: overtones),
        SoundLabVariation(name: "Oct 5, table, pure sine", baseMidi: 72,
                          gains: PlaybackRegister.gainTable, partials: sine),
        SoundLabVariation(name: "Oct 5, flat gain, overtones", baseMidi: 72,
                          gains: Array(repeating: 1.0, count: 12), partials: overtones),
        SoundLabVariation(name: "Oct 5, even steeper, overtones", baseMidi: 72,
                          gains: [1.00, 0.72, 0.52, 0.40, 0.31, 0.25, 0.20, 0.17, 0.14, 0.12, 0.10, 0.09], partials: overtones),
        SoundLabVariation(name: "Oct 5, gentle table, overtones", baseMidi: 72,
                          gains: [1.00, 0.95, 0.90, 0.84, 0.78, 0.72, 0.66, 0.60, 0.55, 0.50, 0.46, 0.42], partials: overtones),
        SoundLabVariation(name: "Oct 6, tamed top, sine", baseMidi: 84,
                          gains: [1.00, 0.90, 0.80, 0.70, 0.60, 0.50, 0.42, 0.36, 0.30, 0.25, 0.20, 0.17], partials: sine),
        SoundLabVariation(name: "Oct 6, tamed top, overtones", baseMidi: 84,
                          gains: [1.00, 0.90, 0.80, 0.70, 0.60, 0.50, 0.42, 0.36, 0.30, 0.25, 0.20, 0.17], partials: overtones),
        SoundLabVariation(name: "Oct 6, flat gain, sine", baseMidi: 84,
                          gains: Array(repeating: 1.0, count: 12), partials: sine),
    ]

    func frequency(_ semitone: Int) -> Double {
        PitchMath.frequency(midi: baseMidi + Double(semitone))
    }
}

struct SoundLabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(SoundLabVariation.all) { variation in
                    NavigationLink(destination: SoundLabVariationView(variation: variation)) {
                        Text(verbatim: variation.name)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                    }
                }
            }
            .lineLimit(2)
            .minimumScaleFactor(0.7)
        }
    }
}

struct SoundLabVariationView: View {
    let variation: SoundLabVariation
    @EnvironmentObject private var tonePlayer: TonePlayer

    private let names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B"]

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(verbatim: variation.name)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    Button {
                        var segments: [ToneSegment] = []
                        for semitone in 0..<12 {
                            segments.append(.tone(variation.frequency(semitone), 0.6, amplitude: variation.gains[semitone]))
                            segments.append(.rest(0.25))
                        }
                        tonePlayer.play(segments, partials: variation.partials) { _ in }
                    } label: {
                        Label("Play all", systemImage: "play.fill")
                    }
                    .buttonStyle(FillButtonStyle(tint: .accentColor))
                    VolumeView()
                        .volumeIndicatorFrame()
                }
                .frame(height: 36)

                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach((row * 3)..<(row * 3 + 3), id: \.self) { semitone in
                            Button {
                                tonePlayer.play([.tone(variation.frequency(semitone), 0.7, amplitude: variation.gains[semitone])],
                                                partials: variation.partials) { _ in }
                            } label: {
                                VStack(spacing: 0) {
                                    Text(verbatim: names[semitone])
                                        .font(.body.bold())
                                    Text(verbatim: String(format: "%.2f", variation.gains[semitone]))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(FillButtonStyle())
                            .frame(height: 44)
                        }
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .onDisappear(perform: tonePlayer.stop)
    }
}
#endif
