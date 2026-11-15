import AVFoundation
import XCTest
@testable import Doremi_Teacher_Watch_App

final class AudioOutputTests: XCTestCase {
    func testHeadphonePortNamesMatchTheSystem() {
        let system: Set<String> = [
            AVAudioSession.Port.bluetoothA2DP.rawValue,
            AVAudioSession.Port.bluetoothLE.rawValue,
            AVAudioSession.Port.bluetoothHFP.rawValue,
            AVAudioSession.Port.headphones.rawValue,
        ]
        XCTAssertEqual(AudioOutputKind.headphonePorts, system)
    }

    func testOutputKind() {
        XCTAssertEqual(AudioOutputKind(port: AVAudioSession.Port.bluetoothA2DP.rawValue), .headphones)
        XCTAssertEqual(AudioOutputKind(port: AVAudioSession.Port.builtInSpeaker.rawValue), .watchSpeaker)
        XCTAssertEqual(AudioOutputKind(port: nil), .watchSpeaker)
    }

    /// The watchdog must outwait Bluetooth start-up, or it restarts a sound that is merely
    /// slow to arrive and makes the delay longer.
    func testWatchdogAllowsForBluetoothStartUp() {
        let speaker = PlaybackTiming.watchdogDelay(duration: 0.85, outputLatency: 0.01, output: .watchSpeaker)
        let airPods = PlaybackTiming.watchdogDelay(duration: 0.85, outputLatency: 0.25, output: .headphones)
        XCTAssertEqual(speaker, 0.85 + 0.01 + 1.5, accuracy: 1e-9)
        XCTAssertEqual(airPods, 0.85 + 0.25 + 1.5 + 2.5, accuracy: 1e-9)
        XCTAssertEqual(PlaybackTiming.watchdogDelay(duration: 1, outputLatency: -1, output: .watchSpeaker), 2.5, accuracy: 1e-9)
    }
}
