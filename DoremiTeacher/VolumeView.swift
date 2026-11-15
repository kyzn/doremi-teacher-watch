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

/// The crown volume circle as placed beside a button row, with a headphones badge while sound
/// goes to AirPods or other headphones. watchOS draws the speaker glyph inside the circle and
/// offers no way to change it, and it keeps a separate volume per output, so the badge tells
/// the learner which of the two levels the crown is setting.
struct VolumeIndicator: View {
    @EnvironmentObject private var tonePlayer: TonePlayer

    var body: some View {
        VolumeView()
            .volumeIndicatorFrame()
            .overlay(alignment: .topTrailing) {
                if tonePlayer.output == .headphones {
                    Image(systemName: "headphones")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                        .padding(2)
                        .background(Circle().fill(Color.black))
                        .offset(x: 3, y: -3)
                        .accessibilityLabel(Text("Headphones"))
                }
            }
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
