import Foundation

/// One piece of a playback: a sine tone at a frequency, or a rest.
struct ToneSegment: Equatable {
    /// Nil means silence.
    let frequencyHz: Double?
    let duration: TimeInterval
    /// Peak level, 0…1. Defaults to the register's loudness compensation.
    let amplitude: Float

    static func tone(_ frequencyHz: Double, _ duration: TimeInterval, amplitude: Float? = nil) -> ToneSegment {
        ToneSegment(frequencyHz: frequencyHz, duration: duration,
                    amplitude: amplitude ?? PlaybackRegister.amplitude(forFrequency: frequencyHz))
    }

    static func rest(_ duration: TimeInterval) -> ToneSegment {
        ToneSegment(frequencyHz: nil, duration: duration, amplitude: 0)
    }
}

/// Pure sample rendering, kept apart from AVFoundation so it can be unit tested.
/// Every tone gets an attack and release ramp so the speaker does not click.
///
/// Tones are not pure sines. The watch speaker barely reproduces 523 Hz, so a sine C5 is far
/// quieter than a sine B5 and the volume gives the note away. Adding the same overtone mix
/// to every note moves energy up to where the speaker is efficient, which lifts the low
/// notes most, without giving any note a timbre of its own. Each tone is normalised so its
/// peak equals the requested amplitude regardless of how the partials line up.
enum ToneSynth {
    static let rampDuration: TimeInterval = 0.008
    static let trailingSilenceDuration: TimeInterval = 0.080
    /// Relative levels of the fundamental and its 2nd and 3rd harmonics.
    static let partials: [Float] = [1.0, 0.6, 0.3]

    static func totalDuration(_ segments: [ToneSegment]) -> TimeInterval {
        segments.reduce(0) { $0 + $1.duration } + trailingSilenceDuration
    }

    static func samples(for segments: [ToneSegment], sampleRate: Double, partials: [Float] = partials) -> [Float] {
        var output: [Float] = []
        output.reserveCapacity(Int(totalDuration(segments) * sampleRate) + 1)
        let rampFrames = max(1, Int(rampDuration * sampleRate))

        for segment in segments {
            let frames = Int((segment.duration * sampleRate).rounded())
            guard let frequency = segment.frequencyHz else {
                output.append(contentsOf: repeatElement(0, count: frames))
                continue
            }
            // Raw waveform first, then scale so the peak lands exactly on the amplitude.
            var raw = [Float](repeating: 0, count: frames)
            var peak: Float = 0
            for frame in 0..<frames {
                let t = Double(frame) / sampleRate
                var value: Float = 0
                for (index, level) in partials.enumerated() {
                    let harmonic = frequency * Double(index + 1)
                    // Skip partials the sample rate cannot represent.
                    guard harmonic < sampleRate / 2 else { continue }
                    value += level * Float(sin(2 * Double.pi * harmonic * t))
                }
                raw[frame] = value
                peak = max(peak, abs(value))
            }
            let scale = peak > 0 ? segment.amplitude / peak : 0
            for frame in 0..<frames {
                let envelope: Float
                if frame < rampFrames {
                    envelope = Float(frame) / Float(rampFrames)
                } else if frame >= frames - rampFrames {
                    envelope = Float(frames - frame) / Float(rampFrames)
                } else {
                    envelope = 1
                }
                output.append(raw[frame] * scale * envelope)
            }
        }
        output.append(contentsOf: repeatElement(0, count: Int(trailingSilenceDuration * sampleRate)))
        return output
    }
}
