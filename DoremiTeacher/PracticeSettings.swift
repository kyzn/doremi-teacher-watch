import Combine
import Foundation

/// Everything the learner can configure. Frozen into a round at question time so a change
/// mid-round cannot relabel a sound that already played.
struct PracticeSettings: Equatable, Codable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var naming = NoteNaming()
    var noteSet: NoteSet = .seven
    /// The learner's last instrument mapping, kept while naming is Standard or A B C so that
    /// choosing My instrument again restores it. Optional on purpose: synthesized Codable
    /// ignores default values, so a non-optional field would fail to decode 1.0 settings.
    var lastInstrument: InstrumentMapping?

    static let `default` = PracticeSettings()
    /// The saz example offered the first time: Re sounds E.
    static let defaultInstrument = InstrumentMapping(reference: .d, soundsLike: PitchClass(centsAboveC: 400))

    /// Instrument naming is a syllable feature: letters always mean concert pitches. Called
    /// whenever settings change: it remembers the current instrument mapping, then makes a
    /// switch to letters drop back to standard naming.
    mutating func normalize() {
        if case let .instrument(reference, soundsLike) = naming.relationship {
            lastInstrument = InstrumentMapping(reference: reference, soundsLike: soundsLike)
            if naming.style == .letters {
                naming.relationship = .standard
            }
        }
    }

    /// Names follow → My instrument: the last mapping, or the saz example the first time.
    mutating func useInstrumentNaming() {
        let mapping = lastInstrument ?? Self.defaultInstrument
        naming.relationship = .instrument(reference: mapping.reference, soundsLike: mapping.soundsLike)
    }
}

struct InstrumentMapping: Equatable, Codable {
    var reference: NaturalName
    var soundsLike: PitchClass
}

@MainActor
final class SettingsStore: ObservableObject {
    static let defaultsKey = "doremi.settings.snapshot"

    @Published var settings: PracticeSettings {
        didSet {
            var normalized = settings
            normalized.normalize()
            if normalized != settings {
                settings = normalized   // re-enters didSet once, then matches
                return
            }
            save()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode(PracticeSettings.self, from: data),
           stored.schemaVersion == PracticeSettings.currentSchemaVersion {
            var normalized = stored
            normalized.normalize()   // property observers do not run in init
            settings = normalized
        } else {
            settings = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
