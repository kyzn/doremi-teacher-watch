import Foundation

/// How names relate to concert sounds. Kept as data so a settings screen can preview it and a
/// round can freeze it. Movable Do is deferred (TODO.md) and would be a third case here.
enum NamingRelationship: Equatable, Codable {
    /// C = Do sounds concert C.
    case standard
    /// One named note is declared to sound like a concert pitch; every other name shifts by
    /// the same amount. The saz example: Re sounds E, so the whole collection is +200 cents.
    case instrument(reference: NaturalName, soundsLike: PitchClass)
}

enum NameStyle: String, Codable, CaseIterable {
    case letters
    case syllables
}

enum AccidentalPreference: String, Codable, CaseIterable {
    case sharps
    case flats
}

/// Script used for syllables. Japanese learners read ドレミ; everyone else reads Do Re Mi.
enum SyllableScript {
    case latin
    case katakana

    static func forCurrentLocale() -> SyllableScript {
        // `Locale.language` needs watchOS 9; preferredLanguages works on the 8.0 floor.
        (Locale.preferredLanguages.first ?? "").hasPrefix("ja") ? .katakana : .latin
    }
}

/// Translates between written pitches, display labels, and concert sounds. Pure value type;
/// nothing here touches audio or persistence.
struct NoteNaming: Equatable, Codable {
    var style: NameStyle = .syllables
    var relationship: NamingRelationship = .standard
    var accidentals: AccidentalPreference = .sharps

    /// Cents added to a written pitch to reach its concert sound.
    var transpositionCents: Int {
        switch relationship {
        case .standard:
            return 0
        case let .instrument(reference, soundsLike):
            return soundsLike - reference.written
        }
    }

    func concertPitch(forWritten written: PitchClass) -> PitchClass {
        written + transpositionCents
    }

    func writtenPitch(forConcert concert: PitchClass) -> PitchClass {
        concert + (-transpositionCents)
    }

    func frequency(forWritten written: PitchClass) -> Double {
        PlaybackRegister.frequency(for: concertPitch(forWritten: written))
    }

    // MARK: Labels

    /// The name the learner sees for a written pitch, in the selected style.
    func label(forWritten written: PitchClass, script: SyllableScript = .latin) -> String {
        spelled(written) { natural in
            switch style {
            case .letters: return natural.letter
            case .syllables: return script == .katakana ? natural.katakana : natural.syllable
            }
        }
    }

    /// The concert sound as a letter name, whatever the style. Used for "Sounds like E".
    func concertLabel(forWritten written: PitchClass) -> String {
        spelled(concertPitch(forWritten: written)) { $0.letter }
    }

    /// Spoken form for VoiceOver: "Re sharp", "E flat".
    func spokenLabel(forWritten written: PitchClass, script: SyllableScript = .latin) -> String {
        spelled(written, sharp: " sharp", flat: " flat") { natural in
            switch style {
            case .letters: return natural.letter
            case .syllables: return script == .katakana ? natural.katakana : natural.syllable
            }
        }
    }

    /// Both spellings of an altered pitch, for feedback text such as "also called Mi♭".
    func alternateLabel(forWritten written: PitchClass, script: SyllableScript = .latin) -> String? {
        guard NaturalName.natural(at: written) == nil else { return nil }
        var flipped = self
        flipped.accidentals = accidentals == .sharps ? .flats : .sharps
        return flipped.label(forWritten: written, script: script)
    }

    private func spelled(_ pitch: PitchClass, sharp: String = "♯", flat: String = "♭", name: (NaturalName) -> String) -> String {
        if let natural = NaturalName.natural(at: pitch) {
            return name(natural)
        }
        switch accidentals {
        case .sharps: return name(NaturalName.below(pitch)) + sharp
        case .flats: return name(NaturalName.above(pitch)) + flat
        }
    }

    // MARK: Settings preview

    struct PreviewRow: Equatable, Identifiable {
        let natural: NaturalName
        let written: String
        let concert: String
        var id: Int { natural.rawValue }
    }

    /// One row per natural: "Do → D", "Re → E", … so a transposition is understandable without
    /// knowing the number of cents.
    func previewRows(script: SyllableScript = .latin) -> [PreviewRow] {
        NaturalName.allCases.map { natural in
            PreviewRow(
                natural: natural,
                written: label(forWritten: natural.written, script: script),
                concert: concertLabel(forWritten: natural.written)
            )
        }
    }
}
