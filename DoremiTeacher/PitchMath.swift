import Foundation

/// Frequency and cents conversions around concert A4 = 440 Hz. Full precision inside;
/// round only for display. See docs/PITCH_REFERENCE.md.
enum PitchMath {
    static let concertA4Hz: Double = 440

    static func frequency(centsFromA4 cents: Double) -> Double {
        concertA4Hz * pow(2, cents / 1200)
    }

    /// Nil for zero, negative, or non-finite input.
    static func cents(fromA4 frequencyHz: Double) -> Double? {
        guard frequencyHz.isFinite, frequencyHz > 0 else { return nil }
        return 1200 * log2(frequencyHz / concertA4Hz)
    }

    /// Conventional MIDI numbering, possibly fractional. 69 is A4.
    static func frequency(midi: Double) -> Double {
        concertA4Hz * pow(2, (midi - 69) / 12)
    }

    /// Signed error of a measurement against a target, in cents.
    static func errorCents(measuredHz: Double, targetHz: Double) -> Double? {
        guard measuredHz.isFinite, targetHz.isFinite, measuredHz > 0, targetHz > 0 else { return nil }
        return 1200 * log2(measuredHz / targetHz)
    }

    /// The same error folded into one octave, so E3 against E4 reads as 0 cents.
    static func classErrorCents(measuredHz: Double, targetHz: Double) -> Double? {
        guard let error = errorCents(measuredHz: measuredHz, targetHz: targetHz) else { return nil }
        return error - 1200 * (error / 1200).rounded()
    }
}
