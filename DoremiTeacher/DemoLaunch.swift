import Foundation
import SwiftUI

/// Debug-only deep links for screenshots and layout checks, same idea as Morse Teacher.
///
///     SIMCTL_CHILD_DEMO_SCREEN=feedback-wrong xcrun simctl launch <udid> <bundle>
enum DemoLaunch: String {
    case listening
    case feedbackCorrect = "feedback-correct"
    case feedbackWrong = "feedback-wrong"
    case settings
    case instrument
    case stats

    static var requested: DemoLaunch? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["DEMO_SCREEN"].flatMap(DemoLaunch.init(rawValue:))
        #else
        return nil
        #endif
    }

    /// `DEMO_STATS=tc,tw,lc,lw[,tc,tw,lc,lw]`: seven-note counters, then optional twelve-note.
    @MainActor
    static func demoStats() -> StatsStore? {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["DEMO_STATS"] else { return nil }
        let numbers = raw.split(separator: ",").compactMap { Int($0) }
        guard numbers.count == 4 || numbers.count == 8 else { return nil }
        return StatsStore.demo(seven: Array(numbers[..<4]), twelve: numbers.count == 8 ? Array(numbers[4...]) : [0, 0, 0, 0])
        #else
        return nil
        #endif
    }

    /// `DEMO_PROFILE=letters` uses A B C names; `saz` the Re-sounds-E instrument profile;
    /// `twelve` the twelve-note set; `saz-twelve` both. In-memory only.
    @MainActor
    static func demoSettings() -> SettingsStore? {
        #if DEBUG
        guard let profile = ProcessInfo.processInfo.environment["DEMO_PROFILE"] else { return nil }
        let suite = UserDefaults(suiteName: "doremi.demo.settings")!
        suite.removePersistentDomain(forName: "doremi.demo.settings")
        let store = SettingsStore(defaults: suite)
        switch profile {
        case "letters":
            store.settings.naming.style = .letters
        case "saz":
            store.settings.naming.relationship = .instrument(reference: .d, soundsLike: PitchClass(centsAboveC: 400))
        case "twelve":
            store.settings.noteSet = .twelve
        case "saz-twelve":
            store.settings.naming.relationship = .instrument(reference: .d, soundsLike: PitchClass(centsAboveC: 400))
            store.settings.noteSet = .twelve
        default:
            break
        }
        return store
        #else
        return nil
        #endif
    }

    static var statsPage: Int? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["DEMO_STATS_PAGE"].flatMap { Int($0) }
        #else
        return nil
        #endif
    }

    static var sizeCategory: ContentSizeCategory? {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["DEMO_TEXT_SIZE"] {
        case "xl": return .extraLarge
        case "xxxl": return .extraExtraExtraLarge
        case "accessibility1": return .accessibilityMedium
        case "accessibility3": return .accessibilityExtraLarge
        case "accessibility5": return .accessibilityExtraExtraExtraLarge
        default: return nil
        }
        #else
        return nil
        #endif
    }
}
