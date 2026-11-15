import AVFoundation
import Combine
import Foundation
import os

enum PlaybackOutcome: Equatable {
    /// The whole buffer reached the output.
    case finished
    /// Stopped by `cancel()`/`stop()`, a scene change, or an audio interruption before it finished.
    case cancelled
    case failed(String)

    var errorMessage: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}

/// Anything that can play a tone sequence. `TonePlayer` in the app, a fake in tests.
@MainActor
protocol TonePlaying: AnyObject {
    func play(_ segments: [ToneSegment], completion: @escaping (PlaybackOutcome) -> Void)
    /// Cancels the current sound but keeps the audio path warm. Use between rounds.
    func cancel()
    /// Cancels and releases the audio session. Use when leaving a screen or going inactive.
    func stop()
}

/// Which output the sound goes to. Any Bluetooth or wired output counts as headphones: the
/// port type cannot tell AirPods from other earbuds. Same rule as the Metronome app.
enum AudioOutputKind: Equatable {
    case watchSpeaker
    case headphones

    /// Raw values of `AVAudioSession.Port`; a test checks they still match.
    static let headphonePorts: Set<String> = [
        "BluetoothA2DPOutput", "BluetoothLE", "BluetoothHFP", "Headphones"
    ]

    init(port: String?) {
        self = port.map(Self.headphonePorts.contains) == true ? .headphones : .watchSpeaker
    }
}

/// Timing rules for the stall watchdog and the Bluetooth start-up retries. Pure, so tests can
/// pin them down.
enum PlaybackTiming {
    /// Grace period after the buffer should have ended before the watchdog intervenes.
    static let watchdogGrace: TimeInterval = 1.5
    /// Extra grace on headphones: a Bluetooth link that was idle or just switched can take a
    /// second or two to start rendering, and the watchdog must not restart a sound that is
    /// merely slow to arrive.
    static let headphoneGrace: TimeInterval = 2.5
    /// Engine start is retried this often while a Bluetooth route settles.
    static let startAttempts = 3
    static let startRetryDelay: TimeInterval = 0.5

    static func watchdogDelay(duration: TimeInterval, outputLatency: TimeInterval, output: AudioOutputKind) -> TimeInterval {
        duration + max(0, outputLatency) + watchdogGrace + (output == .headphones ? headphoneGrace : 0)
    }
}

/// Plays one finite PCM buffer through `AVAudioEngine`.
///
/// The engine and node are retained for life and the session stays active between sounds,
/// because tearing the session down and straight back up left the engine reporting
/// `isRunning` while rendering nothing: the buffer's completion then arrived only when the
/// system killed the session 10–15 s later. A watchdog guards against any repeat of that.
///
/// Output changes (AirPods connecting or dropping) stop the engine. While a practice screen
/// has the session active, the player restarts the engine at once and plays a short silence,
/// so the Bluetooth link is awake before the learner taps Play instead of after.
@MainActor
final class TonePlayer: ObservableObject, TonePlaying {
    @Published private(set) var isPlaying = false
    /// Drives the headphones badge on the volume control.
    @Published private(set) var output: AudioOutputKind

    private static let logger = Logger(subsystem: "com.hoshinosoftware.doremiteacher", category: "audio")

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let tracker = PlaybackTracker()
    /// The stall watchdog, or a pending engine-start retry. Cancelled by any new play or stop.
    private var watchdog: DispatchWorkItem?
    private var warmUpItem: DispatchWorkItem?
    /// True from a successful activation until `stop()`; warm-up only happens while it is set.
    private var sessionActive = false
    /// The node may be rendering (a tone or the warm-up silence) and needs stopping.
    private var nodeBusy = false
    private var observers: [NSObjectProtocol] = []

    init() {
        output = AudioOutputKind(port: AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType.rawValue)
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Self.logger.notice("audio interruption began")
            MainActor.assumeIsolated { self?.stop() }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
            Self.logger.notice("route change, reason \(reason)")
            MainActor.assumeIsolated { self?.refreshOutput() }
        })
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            // Route or format changed; the engine has stopped. Cancel the current sound and
            // stop the engine explicitly so the next play restarts it instead of trusting
            // a stale `isRunning`. Then wake the new route up front.
            Self.logger.notice("engine configuration change")
            MainActor.assumeIsolated {
                guard let self else { return }
                self.cancelCurrent()
                self.engine.stop()
                self.refreshOutput()
                self.warmUp(attemptsLeft: PlaybackTiming.startAttempts)
            }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func play(_ segments: [ToneSegment], completion: @escaping (PlaybackOutcome) -> Void) {
        play(segments, completion: completion, isRetry: false)
    }

    private func play(_ segments: [ToneSegment], completion: @escaping (PlaybackOutcome) -> Void, isRetry: Bool) {
        stopNode()
        guard let currentGeneration = tracker.begin(completion) else { return }

        guard let buffer = makeBuffer(for: segments) else {
            finish(.failed("Could not build the sound."), generation: currentGeneration)
            return
        }
        start(buffer, segments: segments, generation: currentGeneration, isRetry: isRetry,
              attemptsLeft: PlaybackTiming.startAttempts, requested: Date())
    }

    /// Activates the session and engine, then schedules the buffer. While a Bluetooth route
    /// settles the engine can refuse to start for a moment; retry a few times before failing.
    private func start(_ buffer: AVAudioPCMBuffer, segments: [ToneSegment], generation currentGeneration: UInt64,
                       isRetry: Bool, attemptsLeft: Int, requested: Date) {
        guard tracker.isCurrent(currentGeneration) else { return }
        do {
            try activate()
        } catch {
            Self.logger.error("audio setup failed (\(attemptsLeft) left): \(error.localizedDescription, privacy: .public)")
            guard attemptsLeft > 1 else {
                finish(.failed("Sound is unavailable. Check volume and Silent Mode."), generation: currentGeneration)
                return
            }
            let item = DispatchWorkItem { [weak self] in
                self?.start(buffer, segments: segments, generation: currentGeneration, isRetry: isRetry,
                            attemptsLeft: attemptsLeft - 1, requested: requested)
            }
            watchdog = item
            DispatchQueue.main.asyncAfter(deadline: .now() + PlaybackTiming.startRetryDelay, execute: item)
            return
        }

        isPlaying = true
        nodeBusy = true
        let duration = ToneSynth.totalDuration(segments)
        let output = self.output
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.tracker.isCurrent(currentGeneration) else { return }
                // Played-back time minus the sound's own length is roughly how long it took to
                // start, including Bluetooth latency. Visible in Console.app (category "audio").
                let lag = Date().timeIntervalSince(requested) - duration
                Self.logger.notice("tone finished; start-up lag \(lag, format: .fixed(precision: 2)) s on \(String(describing: output), privacy: .public)")
                self.finish(.finished, generation: currentGeneration)
            }
        }
        playerNode.play()

        // If the completion never comes, the engine was not really rendering. Restart it and
        // replay once; report a failure if that does not help either.
        let delay = PlaybackTiming.watchdogDelay(
            duration: duration,
            outputLatency: AVAudioSession.sharedInstance().outputLatency,
            output: output
        )
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let action = self.tracker.watchdogFired(generation: currentGeneration, isRetry: isRetry)
            guard action != .ignore else { return }
            Self.logger.error("playback stalled (retry: \(isRetry)); restarting engine")
            self.stopNode()
            self.engine.stop()
            if action == .fail {
                self.finish(.failed("Sound stalled. Tap to try again."), generation: currentGeneration)
            } else if let pending = self.tracker.detach() {
                self.play(segments, completion: pending, isRetry: true)
            }
        }
        watchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        sessionActive = true
        refreshOutput()
        if !engine.isRunning {
            try engine.start()
            Self.logger.debug("engine started")
        }
    }

    func cancel() {
        cancelCurrent()
    }

    func stop() {
        cancelCurrent()
        warmUpItem?.cancel()
        warmUpItem = nil
        sessionActive = false
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func refreshOutput() {
        let port = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType.rawValue
        let kind = AudioOutputKind(port: port)
        if kind != output {
            Self.logger.notice("output now \(port ?? "none", privacy: .public)")
            output = kind
        }
    }

    /// After an output change on a practice screen: restart the engine and play a short
    /// silence so the new route (typically AirPods) is already streaming when the learner
    /// taps Play. Does nothing off a practice screen or while a sound is playing.
    private func warmUp(attemptsLeft: Int) {
        warmUpItem?.cancel()
        warmUpItem = nil
        guard sessionActive, !tracker.isActive else { return }
        do {
            try activate()
        } catch {
            Self.logger.error("warm-up start failed (\(attemptsLeft) left): \(error.localizedDescription, privacy: .public)")
            guard attemptsLeft > 1 else { return }
            let item = DispatchWorkItem { [weak self] in self?.warmUp(attemptsLeft: attemptsLeft - 1) }
            warmUpItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + PlaybackTiming.startRetryDelay, execute: item)
            return
        }
        guard let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate * 0.3)) else { return }
        silence.frameLength = silence.frameCapacity   // zero-filled
        nodeBusy = true
        playerNode.scheduleBuffer(silence, at: nil, options: [], completionHandler: nil)
        playerNode.play()
        Self.logger.notice("warm-up silence scheduled")
    }

    private func cancelCurrent() {
        stopNode()
        tracker.cancel()
    }

    /// Silences the node and disarms the watchdog. Buffer callbacks that `stop()` fires carry
    /// an old generation by the time they reach the main actor, so the tracker drops them.
    private func stopNode() {
        watchdog?.cancel()
        watchdog = nil
        warmUpItem?.cancel()
        warmUpItem = nil
        if nodeBusy {
            playerNode.stop()
            nodeBusy = false
        }
        if isPlaying { isPlaying = false }
    }

    private func finish(_ outcome: PlaybackOutcome, generation: UInt64) {
        guard tracker.isCurrent(generation) else { return }
        watchdog?.cancel()
        watchdog = nil
        isPlaying = false
        tracker.finish(outcome, generation: generation)
    }

    private func makeBuffer(for segments: [ToneSegment]) -> AVAudioPCMBuffer? {
        let samples = ToneSynth.samples(for: segments, sampleRate: format.sampleRate)
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }
        return buffer
    }
}
