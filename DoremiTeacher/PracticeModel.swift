import Foundation

enum PracticeMode: String, Codable, CaseIterable {
    case listening
    case humming
}

/// Exactly one of these is produced per submitted round. `bucket` records the configuration
/// the round was played under, so future breakdowns need no migration.
struct PracticeResult: Equatable {
    let questionID: UUID
    let mode: PracticeMode
    let bucket: StatsBucket
    let isCorrect: Bool
}

/// Configuration a result is filed under. Encoded as one string key in the snapshot.
struct StatsBucket: Hashable, Codable {
    let mode: PracticeMode
    let noteSet: NoteSet

    var key: String { "\(mode.rawValue)/\(noteSet.rawValue)" }

    init(mode: PracticeMode, noteSet: NoteSet) {
        self.mode = mode
        self.noteSet = noteSet
    }

    init?(key: String) {
        let parts = key.split(separator: "/")
        guard parts.count == 2, let mode = PracticeMode(rawValue: String(parts[0])),
              let set = NoteSet(rawValue: String(parts[1])) else { return nil }
        self.init(mode: mode, noteSet: set)
    }
}
