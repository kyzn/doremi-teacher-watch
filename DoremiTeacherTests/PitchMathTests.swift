import XCTest
@testable import Doremi_Teacher_Watch_App

final class PitchMathTests: XCTestCase {
    func testReferenceOctaveMatchesTable() {
        // From docs/PITCH_REFERENCE.md, rounded to two decimals.
        let table: [(Double, Double)] = [
            (60, 261.63), (61, 277.18), (62, 293.66), (63, 311.13), (64, 329.63), (65, 349.23),
            (66, 369.99), (67, 392.00), (68, 415.30), (69, 440.00), (70, 466.16), (71, 493.88), (72, 523.25),
        ]
        for (midi, hz) in table {
            XCTAssertEqual(PitchMath.frequency(midi: midi), hz, accuracy: 0.005, "midi \(midi)")
        }
    }

    func testCentsRoundTrip() {
        for cents in stride(from: -2400.0, through: 2400.0, by: 50) {
            let hz = PitchMath.frequency(centsFromA4: cents)
            XCTAssertEqual(PitchMath.cents(fromA4: hz)!, cents, accuracy: 1e-9)
        }
    }

    func testQuarterToneExamples() {
        XCTAssertEqual(PitchMath.frequency(centsFromA4: -50), 427.47, accuracy: 0.005)
        XCTAssertEqual(PitchMath.frequency(centsFromA4: 50), 452.89, accuracy: 0.005)
    }

    func testOctaveFoldedError() {
        let e4 = PitchMath.frequency(midi: 64)
        let e3 = PitchMath.frequency(midi: 52)
        XCTAssertEqual(PitchMath.classErrorCents(measuredHz: e3, targetHz: e4)!, 0, accuracy: 1e-9)
        let slightlySharpE3 = PitchMath.frequency(centsFromA4: PitchMath.cents(fromA4: e3)! + 20)
        XCTAssertEqual(PitchMath.classErrorCents(measuredHz: slightlySharpE3, targetHz: e4)!, 20, accuracy: 1e-6)
    }

    func testInvalidInputIsNil() {
        XCTAssertNil(PitchMath.cents(fromA4: 0))
        XCTAssertNil(PitchMath.cents(fromA4: -5))
        XCTAssertNil(PitchMath.cents(fromA4: .nan))
        XCTAssertNil(PitchMath.errorCents(measuredHz: 100, targetHz: 0))
    }
}

final class ToneSynthTests: XCTestCase {
    func testSampleCountMatchesDuration() {
        let segments: [ToneSegment] = [.tone(440, 0.5), .rest(0.25), .tone(330, 0.5)]
        let samples = ToneSynth.samples(for: segments, sampleRate: 8_000)
        XCTAssertEqual(samples.count, 4_000 + 2_000 + 4_000 + Int(ToneSynth.trailingSilenceDuration * 8_000))
    }

    func testLowNotesGetMoreGainThanHighNotes() {
        let low = ToneSynth.samples(for: [.tone(523.25, 0.2)], sampleRate: 8_000).map(abs).max()!
        let high = ToneSynth.samples(for: [.tone(987.77, 0.2)], sampleRate: 8_000).map(abs).max()!
        XCTAssertEqual(low, 1.0, accuracy: 0.02)
        XCTAssertEqual(high, PlaybackRegister.gainTable.last!, accuracy: 0.02)
        XCTAssertEqual(PlaybackRegister.amplitude(forFrequency: 100), 1.0)
        XCTAssertEqual(PlaybackRegister.amplitude(forFrequency: 5_000), PlaybackRegister.gainTable.last!)
        // Each semitone in the register reads its own table entry, and the table only falls.
        let gains = PitchClass.twelve.map { PlaybackRegister.amplitude(forFrequency: PlaybackRegister.frequency(for: $0)) }
        for (gain, entry) in zip(gains, PlaybackRegister.gainTable) {
            XCTAssertEqual(gain, entry, accuracy: 0.001)
        }
        XCTAssertEqual(gains, gains.sorted(by: >))
        // Halfway between two semitones interpolates.
        let quarterTone = PitchMath.frequency(centsFromA4: PitchMath.cents(fromA4: 523.25)! + 50)
        XCTAssertEqual(PlaybackRegister.amplitude(forFrequency: quarterTone), (1.00 + 0.88) / 2, accuracy: 0.01)
    }

    func testRestsAreSilentAndTonesRamp() {
        let samples = ToneSynth.samples(for: [.tone(440, 0.5), .rest(0.25)], sampleRate: 8_000)
        XCTAssertEqual(samples.first ?? 1, 0, accuracy: 0.001)
        XCTAssertLessThan(abs(samples[3_999]), 0.05)
        XCTAssertTrue(samples[4_000..<6_000].allSatisfy { $0 == 0 })
        XCTAssertGreaterThan(samples[1_000..<1_100].map(abs).max()!, 0.5)
    }
}
