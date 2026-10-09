import SwiftUI

/// Search across channels and the next week of listings.
///
/// Uses tvOS's built-in search screen: the A–Z keyboard row, plus dictation
/// (hold the microphone button on the Siri Remote and speak, e.g. "Traitors"
/// or "Match of the Day").
struct SearchView: View {
    @Environment(GuideStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    /// Opens a programme's info page once this screen has closed.
    let onOpen: (Highlight) -> Void

    var body: some View {
        let results = store.search(query)

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 40) {
                    if query.trimmed.isEmpty {
                        hint
                    } else if results.isEmpty {
                        Text("No results for “\(query)”")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }

                    if !results.channels.isEmpty {
                        section("Channels") {
                            ForEach(results.channels) { channel in
                                Button { tune(channel) } label: { ChannelResult(channel: channel) }
                                    .buttonStyle(.card)
                            }
                        }
                    }
                    if !results.onNow.isEmpty {
                        section("On now") {
                            ForEach(results.onNow) { programme in
                                programmeButton(programme)
                            }
                        }
                    }
                    if !results.later.isEmpty {
                        section("Coming up") {
                            ForEach(results.later) { programme in
                                programmeButton(programme)
                            }
                        }
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
            .searchable(text: $query, prompt: "Programmes, channels or numbers")
            .background(GuideBackground())
        }
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search the TV guide")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("Type with the keyboard above, or hold the microphone button on your Siri Remote and say a programme or channel name.")
                .font(.system(size: 24))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 30, weight: .bold))
            ScrollView(.horizontal) {
                LazyHStack(spacing: 36) { content() }
                    .padding(.vertical, 20)
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func programmeButton(_ programme: Programme) -> some View {
        if let channel = store.channel(id: programme.channelID) {
            Button {
                if programme.isOn(at: store.now) { tune(channel) } else { open(Highlight(channel: channel, programme: programme)) }
            } label: {
                ProgrammeResult(programme: programme, channel: channel, now: store.now,
                                hasReminder: reminders.isSet(for: programme))
            }
            .buttonStyle(.card)
            .contextMenu {
                if programme.start > store.now {
                    Button { reminders.toggle(programme, on: channel) } label: {
                        Label(reminders.isSet(for: programme) ? "Cancel reminder" : "Set reminder",
                              systemImage: reminders.isSet(for: programme) ? "bell.slash" : "bell")
                    }
                }
                Button { open(Highlight(channel: channel, programme: programme)) } label: {
                    Label("Programme info", systemImage: "info.circle")
                }
            }
        }
    }

    private func tune(_ channel: Channel) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { store.tune(channel) }
    }

    private func open(_ highlight: Highlight) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onOpen(highlight) }
    }
}

private struct ChannelResult: View {
    let channel: Channel

    var body: some View {
        HStack(spacing: 16) {
            Text("\(channel.displayNumber)")
                .font(.system(size: 30, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
            ChannelLogo(channel: channel, height: 44)
            Text(channel.name).font(.system(size: 24, weight: .semibold)).lineLimit(1)
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
    }
}

private struct ProgrammeResult: View {
    let programme: Programme
    let channel: Channel
    let now: Date
    let hasReminder: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Artwork(url: programme.imageURL, channel: channel)
                .frame(width: 400, height: 225)
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(programme.title).font(.system(size: 24, weight: .bold)).lineLimit(1)
                Text(programme.isOn(at: now)
                     ? "Now · \(channel.displayNumber) \(channel.name)"
                     : "\(Fmt.day(programme.start, relativeTo: now)) \(Fmt.time(programme.start)) · \(channel.displayNumber) \(channel.name)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(16)
        }
        .overlay(alignment: .topTrailing) {
            if hasReminder {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(10)
                    .background(Theme.accent, in: Circle())
                    .padding(12)
            }
        }
        .frame(width: 400, height: 225)
        .foregroundStyle(.white)
    }
}
