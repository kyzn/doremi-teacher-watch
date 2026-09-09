import Foundation
@testable import Doremi_Teacher_Watch_App

/// SplitMix64: tiny, deterministic, good enough to make shuffles repeatable.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension PitchClass {
    static let c = PitchClass(centsAboveC: 0)
    static let cSharp = PitchClass(centsAboveC: 100)
    static let d = PitchClass(centsAboveC: 200)
    static let e = PitchClass(centsAboveC: 400)
    static let f = PitchClass(centsAboveC: 500)
    static let fSharp = PitchClass(centsAboveC: 600)
    static let g = PitchClass(centsAboveC: 700)
    static let a = PitchClass(centsAboveC: 900)
    static let b = PitchClass(centsAboveC: 1100)
}

/// The user's saz profile: Re sounds concert E.
let sazNaming = NoteNaming(style: .syllables, relationship: .instrument(reference: .d, soundsLike: .e), accidentals: .sharps)
