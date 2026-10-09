import SwiftUI

/// Pops up a Sky style "starting soon" alert for due reminders, with an
/// option to switch straight over. Applied to the guide and the live player;
/// only the screen currently on top (`isActive`) shows it.
struct ReminderAlerts: ViewModifier {
    @Environment(GuideStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    let isActive: Bool
    @State private var current: Reminder?

    func body(content: Content) -> some View {
        content
            .onChange(of: store.now, initial: true) { _, now in check(now) }
            .onChange(of: isActive) { _, _ in check(store.now) }
            .alert(current.map { "Reminder: \($0.title)" } ?? "Reminder",
                   isPresented: Binding(get: { current != nil }, set: { if !$0 { current = nil } }),
                   presenting: current) { reminder in
                Button("Watch \(reminder.channelDisplayNumber) \(reminder.channelName)") {
                    if let channel = store.channel(id: reminder.channelID) { store.tune(channel) }
                }
                Button("Dismiss", role: .cancel) {}
            } message: { reminder in
                Text(reminder.start > store.now
                     ? "Starts at \(Fmt.time(reminder.start)) on \(reminder.channelDisplayNumber) \(reminder.channelName)."
                     : "Started at \(Fmt.time(reminder.start)) on \(reminder.channelDisplayNumber) \(reminder.channelName).")
            }
    }

    private func check(_ now: Date) {
        guard isActive, current == nil, let due = reminders.due(at: now) else { return }
        reminders.markAlerted(due)
        current = due
    }
}

extension View {
    func reminderAlerts(isActive: Bool = true) -> some View { modifier(ReminderAlerts(isActive: isActive)) }
}

/// List of upcoming reminders.
struct RemindersView: View {
    @Environment(GuideStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            GuideBackground()
            VStack(alignment: .leading, spacing: 30) {
                HStack(spacing: 18) {
                    Image(systemName: "bell.fill")
                    Text("Reminders")
                }
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Theme.accent)

                if reminders.reminders.isEmpty {
                    Text("No reminders set. Press and hold a programme later in the guide and choose Set reminder.")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.secondaryText)
                    Button("Back to guide") { dismiss() }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(reminders.reminders, id: \.programmeID) { reminder in
                                Button {
                                    reminders.remove(reminder)
                                } label: {
                                    ReminderRow(reminder: reminder, now: store.now)
                                }
                                .buttonStyle(ReminderRowStyle())
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .scrollClipDisabled()
                    Text("Select a reminder to cancel it.")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 100)
            .padding(.vertical, 70)
        }
    }
}

private struct ReminderRow: View {
    let reminder: Reminder
    let now: Date

    var body: some View {
        HStack(spacing: 30) {
            Text("\(reminder.channelDisplayNumber)")
                .font(.system(size: 34, weight: .heavy))
                .monospacedDigit()
                .frame(width: 100, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title).font(.system(size: 30, weight: .bold)).lineLimit(1)
                Text("\(Fmt.day(reminder.start, relativeTo: now)) · \(Fmt.time(reminder.start)) – \(Fmt.time(reminder.end)) · \(reminder.channelName)")
                    .font(.system(size: 22, weight: .medium))
                    .opacity(0.75)
            }
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 26))
                .opacity(0.7)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
        .frame(maxWidth: 1400)
    }
}

private struct ReminderRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration)
    }

    private struct RowBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .foregroundStyle(isFocused ? Theme.ink : .white)
                .background(isFocused ? Theme.accent : Theme.cell,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(isFocused ? 1.02 : 1)
                .animation(.easeOut(duration: 0.12), value: isFocused)
        }
    }
}
