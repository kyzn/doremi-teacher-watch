import SwiftUI

/// A button that grows to whatever frame it is given, so a screen can divide its height
/// between controls instead of scrolling. Mirrors the system look: rounded, gray by default,
/// tinted when it is the primary action, dimmed when disabled or pressed.
struct FillButtonStyle: ButtonStyle {
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        FillButtonBody(configuration: configuration, tint: tint)
    }
}

private struct FillButtonBody: View {
    @Environment(\.isEnabled) private var isEnabled
    let configuration: ButtonStyle.Configuration
    let tint: Color?

    var body: some View {
        configuration.label
            .foregroundColor(tint ?? .primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.map { $0.opacity(0.22) } ?? Color(white: 0.22))
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
