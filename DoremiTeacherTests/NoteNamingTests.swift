import XCTest
@testable import Doremi_Teacher_Watch_App

final class NoteNamingTests: XCTestCase {
    func testStandardNamingIsIdentity() {
        let naming = NoteNaming()
        XCTAssertEqual(naming.transpositionCents, 0)
        for natural in NaturalName.allCases {
            XCTAssertEqual(naming.concertPitch(forWritten: natural.written), natural.written)
            XCTAssertEqual(naming.label(forWritten: natural.written), natural.syllable)
        }
        XCTAssertEqual(naming.label(forWritten: .d), "Re")
        XCTAssertEqual(NoteNaming(style: .letters).label(forWritten: .d), "D")
    }

    func testReSoundsEShiftsEverythingUpTwoSemitones() {
        XCTAssertEqual(sazNaming.transpositionCents, 200)
        let expected: [(NaturalName, String)] = [
            (.c, "D"), (.d, "E"), (.e, "F♯"), (.f, "G"), (.g, "A"), (.a, "B"), (.b, "C♯"),
        ]
        for (natural, concert) in expected {
            XCTAssertEqual(sazNaming.concertLabel(forWritten: natural.written), concert, natural.syllable)
        }
        XCTAssertEqual(sazNaming.previewRows().map { "\($0.written) → \($0.concert)" },
                       ["Do → D", "Re → E", "Mi → F♯", "Fa → G", "Sol → A", "La → B", "Si → C♯"])
    }

    func testReverseLookupFromConcertToWritten() {
        XCTAssertEqual(sazNaming.writtenPitch(forConcert: .e), .d)
        XCTAssertEqual(sazNaming.writtenPitch(forConcert: .cSharp), .b)
        XCTAssertEqual(sazNaming.writtenPitch(forConcert: .d), .c)
        for pitch in PitchClass.twelve {
            XCTAssertEqual(sazNaming.writtenPitch(forConcert: sazNaming.concertPitch(forWritten: pitch)), pitch)
        }
    }

    func testLabelStyleDoesNotChangeFrequency() {
        var letters = sazNaming
        letters.style = .letters
        for pitch in PitchClass.twelve {
            XCTAssertEqual(sazNaming.frequency(forWritten: pitch), letters.frequency(forWritten: pitch))
        }
        XCTAssertEqual(letters.label(forWritten: .d), "D")
        XCTAssertEqual(letters.concertLabel(forWritten: .d), "E")
    }

    func testFrequenciesLandInTheC5Register() {
        XCTAssertEqual(NoteNaming().frequency(forWritten: .c), 523.25, accuracy: 0.01)
        XCTAssertEqual(NoteNaming().frequency(forWritten: .b), 987.77, accuracy: 0.01)
        // Written Re under the saz profile sounds E5.
        XCTAssertEqual(sazNaming.frequency(forWritten: .d), 659.26, accuracy: 0.01)
        // Written Si sounds C♯, which wraps back into the octave rather than above it.
        XCTAssertEqual(sazNaming.frequency(forWritten: .b), 554.37, accuracy: 0.01)
    }

    func testSevenNoteSetUnderInstrumentMappingSoundsTransposed() {
        let sounds = NoteSet.seven.writtenPitches.map { sazNaming.concertPitch(forWritten: $0) }
        XCTAssertEqual(sounds, [.d, .e, .fSharp, .g, .a, .b, .cSharp])
    }

    func testConventionalAccidentalSpelling() {
        let letters = NoteNaming(style: .letters)
        let altered = [100, 300, 600, 800, 1000].map { PitchClass(centsAboveC: $0) }
        XCTAssertEqual(altered.map { letters.label(forWritten: $0) }, ["C♯", "E♭", "F♯", "G♯", "B♭"])
        XCTAssertEqual(altered.map { letters.alternateLabel(forWritten: $0)! }, ["D♭", "D♯", "G♭", "A♭", "A♯"])
        let syllables = NoteNaming()
        XCTAssertEqual(altered.map { syllables.label(forWritten: $0) }, ["Do♯", "Mi♭", "Fa♯", "Sol♯", "Si♭"])
        XCTAssertNil(syllables.alternateLabel(forWritten: .d))
        XCTAssertEqual(syllables.spokenLabel(forWritten: .fSharp), "Fa sharp")
        XCTAssertEqual(letters.spokenLabel(forWritten: PitchClass(centsAboveC: 300)), "E flat")
        // Concert labels under a transposition use the same convention.
        XCTAssertEqual(sazNaming.concertLabel(forWritten: .e), "F♯")
        XCTAssertEqual(sazNaming.concertLabel(forWritten: .a), "B")
    }

    func testTwelveNoteSetHasOneSpellingPerSound() {
        for naming in [NoteNaming(), sazNaming] {
            let labels = NoteSet.twelve.writtenPitches.map { naming.label(forWritten: $0) }
            XCTAssertEqual(Set(labels).count, 12)
            let sounds = NoteSet.twelve.writtenPitches.map { naming.concertPitch(forWritten: $0) }
            XCTAssertEqual(Set(sounds).count, 12)
        }
    }

    func testKatakanaSyllables() {
        XCTAssertEqual(NoteNaming().label(forWritten: .d, script: .katakana), "レ")
        XCTAssertEqual(NoteNaming().label(forWritten: .f, script: .katakana), "ファ")
        XCTAssertEqual(NoteNaming().label(forWritten: .fSharp, script: .katakana), "ファ♯")
        XCTAssertEqual(NoteNaming(style: .letters).label(forWritten: .d, script: .katakana), "D")
        XCTAssertEqual(sazNaming.previewRows(script: .katakana).first?.written, "ド")
    }

    func testNamingRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(sazNaming)
        XCTAssertEqual(try JSONDecoder().decode(NoteNaming.self, from: data), sazNaming)
    }
}
