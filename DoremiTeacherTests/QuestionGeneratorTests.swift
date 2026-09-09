import XCTest
@testable import Doremi_Teacher_Watch_App

final class QuestionGeneratorTests: XCTestCase {
    private func settings(_ set: NoteSet, naming: NoteNaming = NoteNaming()) -> PracticeSettings {
        var s = PracticeSettings()
        s.noteSet = set
        s.naming = naming
        return s
    }

    func testChoicesAreFourUniqueSoundsIncludingTarget() {
        var generator = QuestionGenerator(rng: SeededRandomNumberGenerator(seed: 1))
        for set in NoteSet.allCases {
            for _ in 0..<200 {
                let q = generator.listeningQuestion(settings: settings(set, naming: sazNaming), avoiding: nil)
                XCTAssertEqual(q.choices.count, 4)
                XCTAssertEqual(Set(q.choices).count, 4)
                XCTAssertTrue(q.choices.contains(q.target))
                XCTAssertTrue(q.choices.allSatisfy { set.writtenPitches.contains($0) })
                let sounds = q.choices.map { q.naming.concertPitch(forWritten: $0) }
                XCTAssertEqual(Set(sounds).count, 4, "no enharmonic duplicates")
                let labels = q.choices.map { q.label(for: $0) }
                XCTAssertEqual(Set(labels).count, 4)
            }
        }
    }

    func testTargetNeverRepeatsImmediately() {
        var generator = QuestionGenerator(rng: SeededRandomNumberGenerator(seed: 2))
        var previous: PitchClass? = nil
        for _ in 0..<300 {
            let q = generator.listeningQuestion(settings: settings(.seven), avoiding: previous)
            XCTAssertNotEqual(q.target, previous)
            previous = q.target
        }
    }

    func testTargetPositionIsShuffled() {
        var generator = QuestionGenerator(rng: SeededRandomNumberGenerator(seed: 3))
        var positions = Set<Int>()
        for _ in 0..<100 {
            let q = generator.listeningQuestion(settings: settings(.twelve), avoiding: nil)
            positions.insert(q.choices.firstIndex(of: q.target)!)
        }
        XCTAssertEqual(positions, [0, 1, 2, 3])
    }

    func testQuestionFreezesNamingAndReference() {
        var generator = QuestionGenerator(rng: SeededRandomNumberGenerator(seed: 4))
        let q = generator.listeningQuestion(settings: settings(.seven, naming: sazNaming), avoiding: nil)
        XCTAssertEqual(q.naming, sazNaming)
        XCTAssertEqual(q.reference, .d)
        XCTAssertEqual(q.referenceFrequency, 659.26, accuracy: 0.01)
        XCTAssertEqual(q.targetFrequency, sazNaming.frequency(forWritten: q.target))

        let standard = generator.listeningQuestion(settings: settings(.seven), avoiding: nil)
        XCTAssertEqual(standard.reference, .c)
        XCTAssertEqual(standard.referenceFrequency, 523.25, accuracy: 0.01)
    }
}
