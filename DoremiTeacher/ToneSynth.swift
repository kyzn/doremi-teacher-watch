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
enum ToneSynth {
    static let rampDuration: TimeInterval = 0.008
    static let trailingSilenceDuration: TimeInterval = 0.080

    static func totalDuration(_ segments: [ToneSegment]) -> TimeInterval {
        segments.reduce(0) { $0 + $1.duration } + trailingSilenceDuration
    }

    static func samples(for segments: [ToneSegment], sampleRate: Double) -> [Float] {
        var output: [Float] = []
        output.reserveCapacity(Int(totalDuration(segments) * sampleRate) + 1)
        let rampFrames = max(1, Int(rampDuration * sampleRate))

        for segment in segments {
            let frames = Int((segment.duration * sampleRate).rounded())
            guard let frequency = segment.frequencyHz else {
                output.append(contentsOf: repeatElement(0, count: frames))
                continue
            }
            let phaseStep = 2 * Double.pi * frequency / sampleRate
            for frame in 0..<frames {
                let envelope: Float
                if frame < rampFrames {
                    envelope = Float(frame) / Float(rampFrames)
                } else if frame >= frames - rampFrames {
                    envelope = Float(frames - frame) / Float(rampFrames)
                } else {
                    envelope = 1
                }
                output.append(Float(sin(phaseStep * Double(frame))) * segment.amplitude * envelope)
            }
        }
        output.append(contentsOf: repeatElement(0, count: Int(trailingSilenceDuration * sampleRate)))
        return output
    }
}
