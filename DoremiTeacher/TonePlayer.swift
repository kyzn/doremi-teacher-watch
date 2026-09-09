import AVFoundation
import Combine
import Foundation

enum PlaybackOutcome: Equatable {
    /// The whole buffer reached the output.
    case finished
    /// Stopped by `stop()`, a scene change, or an audio interruption before it finished.
    case cancelled
    case failed(String)
}

/// Anything that can play a tone sequence. `TonePlayer` in the app, a fake in tests.
@MainActor
protocol TonePlaying: AnyObject {
    func play(_ segments: [ToneSegment], completion: @escaping (PlaybackOutcome) -> Void)
    func stop()
}

/// Plays one finite PCM buffer through `AVAudioEngine`. Same shape as Morse Teacher's
/// player: engine and node retained for life, session kept active between sounds, and a
/// generation counter so a stale completion can never report on a later sound.
@MainActor
final class TonePlayer: ObservableObject, TonePlaying {
    @Published private(set) var isPlaying = false

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var generation: UInt64 = 0
    private var completion: ((PlaybackOutcome) -> Void)?
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
            MainActor.assumeIsolated { self?.stop() }
        })
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func play(_ segments: [ToneSegment], completion: @escaping (PlaybackOutcome) -> Void) {
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
            }
        } catch {
            finish(.failed("Sound is unavailable. Check volume and Silent Mode."), generation: currentGeneration)
            return
        }

        isPlaying = true
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                self?.finish(.finished, generation: currentGeneration)
            }
        }
        playerNode.play()
    }

    /// Stops any playback and releases the audio session. Call when leaving a screen or
    /// when the app goes inactive. Safe to call when idle.
    func stop() {
        cancelCurrent()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cancelCurrent() {
        generation &+= 1
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
