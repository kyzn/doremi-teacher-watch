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
                NavigationLink(destination: SoundLabTunerView()) {
                    Text(verbatim: "7 Tune by ear (crown)")
                        .font(.footnote)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                }
                NavigationLink(destination: SoundLabTunedValuesView()) {
                    Text(verbatim: "Tuned values")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
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

/// Rich overtones, one note at a time: the crown sets the selected note's gain, starting from
/// the medium table. Values persist so they can be read off "Tuned values".
enum SoundLabTuning {
    static let key = "soundLabTunedGains"
    static let names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B"]

    static func decode(_ stored: String) -> [Double] {
        let values = stored.split(separator: ",").compactMap { Double($0) }
        return values.count == 12 ? values : SoundLabVariation.medium.map(Double.init)
    }

    static func encode(_ gains: [Double]) -> String {
        gains.map { String(format: "%.2f", $0) }.joined(separator: ",")
    }

    static func frequency(_ semitone: Int) -> Double {
        PitchMath.frequency(midi: 72 + Double(semitone))
    }
}

struct SoundLabTunerView: View {
    @EnvironmentObject private var tonePlayer: TonePlayer
    @AppStorage(SoundLabTuning.key) private var stored = ""
    @State private var gains: [Double] = SoundLabTuning.decode("")
    @State private var note = 0

    private var gain: Binding<Double> {
        Binding(get: { gains[note] }, set: { value in
            gains[note] = (value * 100).rounded() / 100
            stored = SoundLabTuning.encode(gains)
        })
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Button { note = (note + 11) % 12 } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(FillButtonStyle())
                    .frame(width: 34)
                VStack(spacing: 0) {
                    Text(verbatim: SoundLabTuning.names[note])
                        .font(.title3.bold())
                    Text(verbatim: String(format: "%.2f", gains[note]))
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .focusable()
                .digitalCrownRotation(gain, from: 0.05, through: 1.0, by: 0.01,
                                      sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
                Button { note = (note + 1) % 12 } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(FillButtonStyle())
                    .frame(width: 34)
            }
            .frame(height: 40)
            HStack(spacing: 6) {
                Button { play([note]) } label: { Text(verbatim: "Note") }
                    .buttonStyle(FillButtonStyle(tint: .accentColor))
                Button { play([0, note]) } label: { Text(verbatim: "C, note") }
                    .buttonStyle(FillButtonStyle())
            }
            .frame(height: 40)
            Button { play(Array(0..<12)) } label: { Label("Play all", systemImage: "play.fill") }
                .buttonStyle(FillButtonStyle())
                .frame(height: 36)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .onAppear { gains = SoundLabTuning.decode(stored) }
        .onDisappear(perform: tonePlayer.stop)
    }

    private func play(_ notes: [Int]) {
        var segments: [ToneSegment] = []
        for semitone in notes {
            segments.append(.tone(SoundLabTuning.frequency(semitone), 0.6, amplitude: Float(gains[semitone])))
            segments.append(.rest(0.25))
        }
        tonePlayer.play(segments, partials: SoundLabVariation.rich) { _ in }
    }
}

struct SoundLabTunedValuesView: View {
    @AppStorage(SoundLabTuning.key) private var stored = ""

    var body: some View {
        let gains = SoundLabTuning.decode(stored)
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<12, id: \.self) { semitone in
                    Text(verbatim: "\(SoundLabTuning.names[semitone])  \(String(format: "%.2f", gains[semitone]))")
                        .font(.footnote.monospacedDigit())
                }
                Button(role: .destructive) { stored = "" } label: { Text(verbatim: "Reset to medium") }
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
