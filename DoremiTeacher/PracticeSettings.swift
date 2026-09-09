import Combine
import Foundation

/// Everything the learner can configure. Frozen into a round at question time so a change
/// mid-round cannot relabel a sound that already played.
struct PracticeSettings: Equatable, Codable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var naming = NoteNaming()
    var noteSet: NoteSet = .seven
    /// Play the named anchor before the hidden target.
    var referenceSoundOn = true

    static let `default` = PracticeSettings()

    /// Instrument naming is a syllable feature: letters always mean concert pitches. Called
    /// whenever settings change so a switch to letters drops back to standard naming.
    mutating func normalize() {
        if naming.style == .letters, case .instrument = naming.relationship {
            naming.relationship = .standard
        }
    }

    /// The anchor for Hear → Guess: Do in standard naming, the declared reference otherwise.
    var referenceNatural: NaturalName {
        switch naming.relationship {
        case .standard: return .c
        case let .instrument(reference, _): return reference
        }
    }
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
            settings = stored
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
