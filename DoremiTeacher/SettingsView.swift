import SwiftUI

/// Root settings list. Each row shows its current value and pushes a picker.
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    private let script = SyllableScript.forCurrentLocale()

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                NavigationLink(destination: OptionPicker(
                    selection: $settings.settings.naming.style,
                    options: [(.syllables, syllableSample), (.letters, Text(verbatim: "A B C"))]
                )) {
                    SettingRow(title: "Note names", value: settings.settings.naming.style == .letters ? Text(verbatim: "A B C") : syllableSample)
                }

                // Instrument naming exists for syllables only; letters always mean concert pitch.
                if settings.settings.naming.style == .syllables {
                    NavigationLink(destination: NamesFollowPicker()) {
                        SettingRow(title: "Names follow", value: namesFollowValue)
                    }
                }

                if case .instrument = settings.settings.naming.relationship {
                    NavigationLink(destination: InstrumentView()) {
                        SettingRow(title: "My instrument", value: instrumentSummary)
                    }
                }

                NavigationLink(destination: OptionPicker(
                    selection: $settings.settings.noteSet,
                    options: [(.seven, Text("Seven notes")), (.twelve, Text("With sharps/flats"))]
                )) {
                    SettingRow(title: "Notes to practice", value: settings.settings.noteSet == .seven ? Text("Seven notes") : Text("With sharps/flats"))
                }

                if settings.settings.noteSet == .twelve {
                    NavigationLink(destination: OptionPicker(
                        selection: $settings.settings.naming.accidentals,
                        options: [(.sharps, Text("Prefer sharps")), (.flats, Text("Prefer flats"))]
                    )) {
                        SettingRow(title: "Accidentals", value: settings.settings.naming.accidentals == .sharps ? Text(verbatim: "♯") : Text(verbatim: "♭"))
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private var syllableSample: Text {
        Text(verbatim: script == .katakana ? "ドレミ" : "Do Re Mi")
    }

    private var namesFollowValue: Text {
        switch settings.settings.naming.relationship {
        case .standard: return Text("Standard")
        case .instrument: return Text("My instrument")
        }
    }

    private var instrumentSummary: Text {
        guard case let .instrument(reference, _) = settings.settings.naming.relationship else { return Text(verbatim: "") }
        let naming = settings.settings.naming
        return Text(verbatim: "\(naming.label(forWritten: reference.written, script: script)) → \(naming.concertLabel(forWritten: reference.written))")
    }
}

/// Title above, current value below. Two lines because the titles do not fit beside their
/// values on a 40mm screen.
struct SettingRow: View {
    let title: LocalizedStringKey
    let value: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
            value
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

/// A list of options with a checkmark on the selected one. Tapping selects and pops.
struct OptionPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, Text)]
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    let selected = option.0 == selection
                    Button {
                        selection = option.0
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack {
                            option.1
                            Spacer()
                            if selected { Image(systemName: "checkmark") }
                        }
                        .padding(.horizontal, 8)
                    }
                    .tint(selected ? .accentColor : nil)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}

/// Standard vs My instrument. Choosing My instrument keeps the last reference, defaulting to
/// the saz example Re sounds E.
struct NamesFollowPicker: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                row(Text("Standard"), selected: settings.settings.naming.relationship == .standard) {
                    settings.settings.naming.relationship = .standard
                }
                row(Text("My instrument"), selected: isInstrument) {
                    if !isInstrument {
                        settings.settings.naming.relationship = .instrument(reference: .d, soundsLike: PitchClass(centsAboveC: 400))
                    }
                }
                Text("Standard: Do sounds C. My instrument: you say which note one name sounds like, and every name shifts with it.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var isInstrument: Bool {
        if case .instrument = settings.settings.naming.relationship { return true }
        return false
    }

    private func row(_ label: Text, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            presentationMode.wrappedValue.dismiss()
        } label: {
            HStack {
                label
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 8)
        }
        .tint(selected ? .accentColor : nil)
    }
}

/// "My Re sounds like ‹ E ›" plus the resulting map of all seven names.
struct InstrumentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var tonePlayer: TonePlayer
    private let script = SyllableScript.forCurrentLocale()

    private var reference: NaturalName {
        if case let .instrument(reference, _) = settings.settings.naming.relationship { return reference }
        return .d
    }

    private var soundsLike: PitchClass {
        if case let .instrument(_, pitch) = settings.settings.naming.relationship { return pitch }
        return PitchClass(centsAboveC: 400)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("My \(settings.settings.naming.label(forWritten: reference.written, script: script)) sounds like")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    stepButton("chevron.left", cents: -100)
                    Button {
                        preview(soundsLike)
                    } label: {
                        Text(verbatim: settings.settings.naming.concertLabel(forWritten: reference.written))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(FillButtonStyle(tint: .accentColor))
                    .accessibilityLabel(Text("Play"))
                    stepButton("chevron.right", cents: 100)
                }
                .frame(height: 44)

                NavigationLink(destination: OptionPicker(
                    selection: Binding(
                        get: { reference },
                        set: { settings.settings.naming.relationship = .instrument(reference: $0, soundsLike: soundsLike) }
                    ),
                    options: NaturalName.allCases.map { natural in
                        (natural, Text(verbatim: settings.settings.naming.label(forWritten: natural.written, script: script)))
                    }
                )) {
                    SettingRow(title: "Reference name", value: Text(verbatim: settings.settings.naming.label(forWritten: reference.written, script: script)))
                }

                VStack(spacing: 2) {
                    ForEach(settings.settings.naming.previewRows(script: script)) { row in
                        HStack {
                            Text(verbatim: row.written)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(verbatim: row.concert)
                                .font(.body.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                    }
                }
                .font(.body.monospacedDigit())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .onDisappear(perform: tonePlayer.stop)
    }

    private func stepButton(_ symbol: String, cents: Int) -> some View {
        Button {
            let next = soundsLike + cents
            settings.settings.naming.relationship = .instrument(reference: reference, soundsLike: next)
            preview(next)
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
        }
        .buttonStyle(FillButtonStyle())
        .frame(width: 44)
        .accessibilityLabel(Text(cents < 0 ? "Lower" : "Higher"))
    }

    private func preview(_ concert: PitchClass) {
        tonePlayer.play([.tone(PlaybackRegister.frequency(for: concert), 0.6)]) { _ in }
    }
}
