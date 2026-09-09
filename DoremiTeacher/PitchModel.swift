import Foundation

/// A pitch class expressed in cents above C, normalised into [0, 1200). Twelve-tone pitches
/// are multiples of 100; a future 24-note set adds multiples of 50 without changing this type.
struct PitchClass: Hashable, Codable, Comparable {
    let centsAboveC: Int

    init(centsAboveC: Int) {
        self.centsAboveC = ((centsAboveC % 1200) + 1200) % 1200
    }

    static func + (lhs: PitchClass, cents: Int) -> PitchClass {
        PitchClass(centsAboveC: lhs.centsAboveC + cents)
    }

    static func - (lhs: PitchClass, rhs: PitchClass) -> Int {
        ((lhs.centsAboveC - rhs.centsAboveC) % 1200 + 1200) % 1200
    }

    static func < (lhs: PitchClass, rhs: PitchClass) -> Bool {
        lhs.centsAboveC < rhs.centsAboveC
    }

    static let twelve: [PitchClass] = (0..<12).map { PitchClass(centsAboveC: $0 * 100) }
}

/// The seven unaltered names. Written cents are the same in every naming system; what
/// changes between systems is which concert sound each name points at.
enum NaturalName: Int, CaseIterable, Codable {
    case c, d, e, f, g, a, b

    var writtenCents: Int {
        [0, 200, 400, 500, 700, 900, 1100][rawValue]
    }

    var written: PitchClass { PitchClass(centsAboveC: writtenCents) }

    var letter: String { ["C", "D", "E", "F", "G", "A", "B"][rawValue] }
    var syllable: String { ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"][rawValue] }
    var katakana: String { ["ド", "レ", "ミ", "ファ", "ソ", "ラ", "シ"][rawValue] }

    static func natural(at pitch: PitchClass) -> NaturalName? {
        allCases.first { $0.writtenCents == pitch.centsAboveC }
    }

    /// The natural just below a pitch (for sharp spelling) or just above (for flat spelling).
    static func below(_ pitch: PitchClass) -> NaturalName {
        allCases.last { $0.writtenCents <= pitch.centsAboveC } ?? .b
    }

    static func above(_ pitch: PitchClass) -> NaturalName {
        allCases.first { $0.writtenCents >= pitch.centsAboveC } ?? .c
    }
}

/// Which written pitches a quiz draws from. Defined in written space, so under an instrument
/// mapping "seven notes" means the seven unaltered names, not the concert white keys.
enum NoteSet: String, Codable, CaseIterable {
    case seven
    case twelve

    var writtenPitches: [PitchClass] {
        switch self {
        case .seven: return NaturalName.allCases.map(\.written)
        case .twelve: return PitchClass.twelve
        }
    }
}

/// Sounding register for the quiz: one octave starting at C5. Chosen on the wrist, where
/// octave 4 was barely audible on the watch speaker and octave 6 cracked.
enum PlaybackRegister {
    static let baseMidi: Double = 72   // C5

    static func frequency(for concert: PitchClass) -> Double {
        PitchMath.frequency(midi: baseMidi + Double(concert.centsAboveC) / 100)
    }

    /// The watch speaker gets louder with frequency across this octave, so the low end is
    /// pushed harder and the top end pulled back to even out perceived loudness.
    static func amplitude(forFrequency hz: Double) -> Float {
        let low = 523.25, high = 987.77
        let t = min(max((hz - low) / (high - low), 0), 1)
        return Float(1.0 - 0.4 * t)
    }
}
