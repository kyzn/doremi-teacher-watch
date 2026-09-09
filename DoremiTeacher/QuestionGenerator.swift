import Foundation

/// One Hear → Guess round. Carries its own frozen naming so a settings change after the
/// question was drawn cannot change what the buttons mean.
struct ListeningQuestion: Identifiable, Equatable {
    let id: UUID
    let naming: NoteNaming
    let referenceSoundOn: Bool
    let reference: NaturalName
    /// Written pitch the learner must name.
    let target: PitchClass
    /// Four written pitches including the target, already shuffled. Distinct sounds by
    /// construction: one spelling per pitch class, so no C♯/D♭ pair can appear together.
    let choices: [PitchClass]

    func label(for choice: PitchClass, script: SyllableScript = .latin) -> String {
        naming.label(forWritten: choice, script: script)
    }

    var targetFrequency: Double { naming.frequency(forWritten: target) }
    var referenceFrequency: Double { naming.frequency(forWritten: reference.written) }
}

/// Picks targets and distractors from the active note set. Generic over the random source so
/// tests can seed it.
struct QuestionGenerator<RNG: RandomNumberGenerator> {
    static var choiceCount: Int { 4 }

    private(set) var rng: RNG

    init(rng: RNG) {
        self.rng = rng
    }

    /// A written pitch from the set that differs from `previous`.
    mutating func target(from set: NoteSet, avoiding previous: PitchClass?) -> PitchClass {
        let pool = set.writtenPitches.filter { $0 != previous }
        return pool.randomElement(using: &rng)!
    }

    mutating func listeningQuestion(settings: PracticeSettings, avoiding previous: PitchClass?) -> ListeningQuestion {
        let pitches = settings.noteSet.writtenPitches
        precondition(pitches.count >= Self.choiceCount)
        let target = target(from: settings.noteSet, avoiding: previous)
        let distractors = pitches.filter { $0 != target }.shuffled(using: &rng).prefix(Self.choiceCount - 1)
        let choices = ([target] + distractors).shuffled(using: &rng)
        return ListeningQuestion(
            id: UUID(),
            naming: settings.naming,
            referenceSoundOn: settings.referenceSoundOn,
            reference: settings.referenceNatural,
            target: target,
            choices: choices
        )
    }
}
