#if true // sound-lab branch: lab in TestFlight builds too
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

    static let overtones: [Float] = ToneSynth.partials
    /// More and stronger harmonics: more of the energy lands where the speaker is efficient.
    static let rich: [Float] = [1.0, 0.9, 0.7, 0.5, 0.3]
    /// Second harmonic loudest; the ear still hears the fundamental's pitch.
    static let weakFundamental: [Float] = [0.5, 1.0, 0.8, 0.5, 0.3]

    static let medium: [Float] = [1.00, 0.88, 0.77, 0.68, 0.60, 0.53, 0.47, 0.42, 0.38, 0.34, 0.31, 0.28]
    static let gentle: [Float] = [1.00, 0.94, 0.88, 0.82, 0.76, 0.71, 0.66, 0.62, 0.58, 0.54, 0.52, 0.50]
    static let flat: [Float] = Array(repeating: 1.0, count: 12)

    static let all: [SoundLabVariation] = [
        SoundLabVariation(name: "1 Current (1.0)", baseMidi: 72, gains: PlaybackRegister.gainTable, partials: overtones),
        SoundLabVariation(name: "2 Rich, current table", baseMidi: 72, gains: PlaybackRegister.gainTable, partials: rich),
        SoundLabVariation(name: "3 Rich, medium table", baseMidi: 72, gains: medium, partials: rich),
        SoundLabVariation(name: "4 Rich, gentle table", baseMidi: 72, gains: gentle, partials: rich),
        SoundLabVariation(name: "5 Weak fund., gentle", baseMidi: 72, gains: gentle, partials: weakFundamental),
        SoundLabVariation(name: "6 Weak fund., flat", baseMidi: 72, gains: flat, partials: weakFundamental),
    ]

    func frequency(_ semitone: Int) -> Double {
        PitchMath.frequency(midi: baseMidi + Double(semitone))
    }
}

struct SoundLabView: View {
    @EnvironmentObject private var tonePlayer: TonePlayer

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Button {
                    tonePlayer.play([.tone(750, 0.7, amplitude: 1.0)], partials: [1.0, 0.6, 0.3]) { _ in }
                } label: {
                    Text(verbatim: "Ref: Morse 1.1 beep")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                }
                .tint(.orange)
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
