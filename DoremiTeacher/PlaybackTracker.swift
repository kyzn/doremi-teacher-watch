import Foundation

/// The bookkeeping half of `TonePlayer`, kept free of AVFoundation so it can be unit tested.
///
/// Guarantees:
/// 1. Every `begin` delivers exactly one outcome to its completion.
/// 2. A new `begin` or a `cancel` makes every older generation stale, so late buffer callbacks
///    and watchdogs from an earlier sound are ignored.
/// 3. Re-entrancy: the previous owner's `.cancelled` is delivered before the new completion is
///    stored. If that callback starts another sound, the newer sound wins and this `begin`
///    reports `.cancelled` to its own completion instead of overwriting the newer one.
@MainActor
final class PlaybackTracker {
    enum WatchdogAction: Equatable {
        /// The sound already ended, or a newer one replaced it.
        case ignore
        /// First stall: restart the engine and play again with the same completion.
        case retry
        /// The retry stalled too.
        case fail
    }

    private(set) var generation: UInt64 = 0
    private var completion: ((PlaybackOutcome) -> Void)?

    var isActive: Bool { completion != nil }

    func isCurrent(_ generation: UInt64) -> Bool {
        generation == self.generation && completion != nil
    }

    /// Takes ownership for a new sound. Returns its generation, or nil when a newer sound was
    /// started from inside the previous owner's cancellation (the completion has then already
    /// received `.cancelled`).
    func begin(_ completion: @escaping (PlaybackOutcome) -> Void) -> UInt64? {
        let previous = detach()
        let mine = generation
        previous?(.cancelled)
        guard generation == mine, self.completion == nil else {
            completion(.cancelled)
            return nil
        }
        self.completion = completion
        return mine
    }

    /// Delivers `outcome` if `generation` is still current. Returns whether it was delivered.
    @discardableResult
    func finish(_ outcome: PlaybackOutcome, generation: UInt64) -> Bool {
        guard isCurrent(generation) else { return false }
        let pending = detach()
        pending?(outcome)
        return true
    }

    func cancel() {
        let pending = detach()
        pending?(.cancelled)
    }

    func watchdogFired(generation: UInt64, isRetry: Bool) -> WatchdogAction {
        guard isCurrent(generation) else { return .ignore }
        return isRetry ? .fail : .retry
    }

    /// Ends the current generation and hands back its completion without calling it. Used by
    /// the stall retry, which passes the same completion to the replayed sound.
    func detach() -> ((PlaybackOutcome) -> Void)? {
        generation &+= 1
        let pending = completion
        completion = nil
        return pending
    }
}
