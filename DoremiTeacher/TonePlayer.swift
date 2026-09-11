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

/// Plays one finite PCM buffer through `AVAudioEngine`.
///
/// The engine and node are retained for life and the session stays active between sounds,
/// because tearing the session down and straight back up left the engine reporting
/// `isRunning` while rendering nothing: the buffer's completion then arrived only when the
/// system killed the session 10–15 s later. A watchdog guards against any repeat of that.
@MainActor
final class TonePlayer: ObservableObject, TonePlaying {
    @Published private(set) var isPlaying = false

    private static let logger = Logger(subsystem: "com.hoshinosoftware.doremiteacher", category: "audio")
    /// Grace period after the buffer should have ended before the watchdog intervenes.
    static let watchdogGrace: TimeInterval = 1.5

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var generation: UInt64 = 0
    private var completion: ((PlaybackOutcome) -> Void)?
    private var watchdog: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Self.logger.notice("audio interruption began")
            MainActor.assumeIsolated { self?.stop() }
        })
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            // Route or format changed; the engine has stopped. Cancel the current sound and
            // stop the engine explicitly so the next play restarts it instead of trusting
            // a stale `isRunning`.
            Self.logger.notice("engine configuration change")
            MainActor.assumeIsolated {
                self?.cancelCurrent()
                self?.engine.stop()
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
        cancelCurrent()
        generation &+= 1
        let currentGeneration = generation
        self.completion = completion

        guard let buffer = makeBuffer(for: segments) else {
            finish(.failed("Could not build the sound."), generation: currentGeneration)
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            if !engine.isRunning {
                try engine.start()
                Self.logger.debug("engine started")
            }
        } catch {
            Self.logger.error("audio setup failed: \(error.localizedDescription, privacy: .public)")
            finish(.failed("Sound is unavailable. Check volume and Silent Mode."), generation: currentGeneration)
            return
        }

        isPlaying = true
        let expected = ToneSynth.totalDuration(segments)
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                self?.finish(.finished, generation: currentGeneration)
            }
        }
        playerNode.play()

        // If the completion never comes, the engine was not really rendering. Restart it and
        // replay once; report a failure if that does not help either.
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.generation == currentGeneration, self.isPlaying else { return }
            Self.logger.error("playback stalled (retry: \(isRetry)); restarting engine")
            self.playerNode.stop()
            self.engine.stop()
            self.isPlaying = false
            if isRetry {
                self.finish(.failed("Sound stalled. Tap to try again."), generation: currentGeneration)
            } else {
                let pending = self.completion
                self.completion = nil
                self.play(segments, completion: pending ?? { _ in }, isRetry: true)
            }
        }
        watchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + expected + Self.watchdogGrace, execute: item)
    }

    func cancel() {
        cancelCurrent()
    }

    func stop() {
        cancelCurrent()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cancelCurrent() {
        generation &+= 1
        watchdog?.cancel()
        watchdog = nil
        let pending = completion
        completion = nil
        if isPlaying {
            playerNode.stop()
            isPlaying = false
        }
        pending?(.cancelled)
    }

    private func finish(_ outcome: PlaybackOutcome, generation expected: UInt64) {
        guard generation == expected else { return }
        watchdog?.cancel()
        watchdog = nil
        let pending = completion
        completion = nil
        isPlaying = false
        pending?(outcome)
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
