import SwiftUI
import WatchKit

/// Puts the system volume control on screen so the Digital Crown adjusts playback volume.
/// Same approach as the Metronome app: the control must be in the hierarchy and focused,
/// and focus is re-asserted on a timer because navigation can silently take it back.
struct VolumeView: WKInterfaceObjectRepresentable {
    final class Coordinator {
        var timer: Timer?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        let control = WKInterfaceVolumeControl(origin: .local)
        control.focus()
        context.coordinator.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak control] _ in
            control?.focus()
        }
        return control
    }

    func updateWKInterfaceObject(_ control: WKInterfaceVolumeControl, context: Context) {
        control.focus()
    }

    static func dismantleWKInterfaceObject(_ control: WKInterfaceVolumeControl, coordinator: Coordinator) {
        coordinator.timer?.invalidate()
        coordinator.timer = nil
    }
}

extension View {
    /// Compact crown-volume indicator sized to sit beside a button row.
    func volumeIndicatorFrame() -> some View {
        frame(width: 34, height: 34)
            .scaleEffect(0.75)
            .frame(width: 30)
    }
}
