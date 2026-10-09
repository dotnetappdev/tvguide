import SwiftUI

/// Sky style direct channel entry: type 1-0-1 and BBC One comes on.
///
/// Digits come from a keyboard / universal remote via `onKeyPress`, or from
/// the on-screen `NumberPad` for the Siri Remote. After three digits, or a
/// short pause, the channel is tuned.
struct ChannelNumberEntry: ViewModifier {
    @Environment(GuideStore.self) private var store
    @State private var digits = ""
    @State private var message: String?
    @State private var commitTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onKeyPress(characters: .decimalDigits, phases: .down) { press in
                append(press.characters)
                return .handled
            }
            .overlay(alignment: .topTrailing) {
                if !digits.isEmpty || message != nil {
                    NumberDisplay(text: message ?? digits.padding(toLength: 3, withPad: "–", startingAt: 0),
                                  isError: message != nil)
                        .padding(.top, 50)
                        .padding(.trailing, 80)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: digits)
            .animation(.easeOut(duration: 0.15), value: message)
    }

    private func append(_ characters: String) {
        message = nil
        digits = String((digits + characters.filter(\.isNumber)).suffix(3))
        commitTask?.cancel()
        if digits.count == 3 {
            commit()
        } else {
            commitTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                commit()
            }
        }
    }

    private func commit() {
        guard let number = Int(digits) else { digits = ""; return }
        digits = ""
        if !store.tune(number: number) {
            message = "No channel \(number)"
            commitTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                message = nil
            }
        }
    }
}

extension View {
    func channelNumberEntry() -> some View { modifier(ChannelNumberEntry()) }
}

/// Yellow-on-blue digits, like the Sky box's channel entry.
struct NumberDisplay: View {
    let text: String
    var isError = false

    var body: some View {
        Text(text)
            .font(.system(size: isError ? 30 : 56, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .tracking(isError ? 0 : 8)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Theme.backgroundTop.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.6), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}

/// On-screen keypad so channel numbers can be entered with the Siri Remote.
struct NumberPad: View {
    @Environment(GuideStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    @State private var error: String?
    let onTune: (Channel) -> Void

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]

    var body: some View {
        ZStack {
            GuideBackground()
            VStack(spacing: 40) {
                Text("Enter a channel number")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.accent)

                NumberDisplay(text: error ?? digits.padding(toLength: 3, withPad: "–", startingAt: 0),
                              isError: error != nil)

                Text(preview ?? " ")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(150), spacing: 30), count: 3), spacing: 30) {
                    ForEach(keys, id: \.self) { key in
                        Button { press(key) } label: {
                            Text(key)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .frame(width: 150, height: 100)
                        }
                        .buttonStyle(KeyButtonStyle())
                    }
                }
            }
        }
    }

    private var preview: String? {
        guard let number = Int(digits), let channel = store.channels.first(where: { $0.number == number }) else { return nil }
        return channel.name
    }

    private func press(_ key: String) {
        error = nil
        switch key {
        case "⌫": digits = String(digits.dropLast())
        case "OK": tune()
        default:
            digits = String((digits + key).suffix(3))
            if digits.count == 3 { tune() }
        }
    }

    private func tune() {
        guard let number = Int(digits), let channel = store.channels.first(where: { $0.number == number }) else {
            error = digits.isEmpty ? nil : "No channel \(digits)"
            digits = ""
            return
        }
        dismiss()
        onTune(channel)
    }

    private struct KeyButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            KeyBody(configuration: configuration)
        }

        private struct KeyBody: View {
            let configuration: ButtonStyleConfiguration
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .foregroundStyle(isFocused ? Theme.ink : .white)
                    .background(isFocused ? Theme.accent : Theme.cell,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .scaleEffect(isFocused ? 1.08 : 1)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
                    .animation(.easeOut(duration: 0.12), value: isFocused)
            }
        }
    }
}
