import SwiftUI

/// Full screen programme page: artwork backdrop, synopsis and what's on later.
struct ProgrammeDetailView: View {
    @Environment(GuideStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    let highlight: Highlight
    let onWatch: (Channel) -> Void

    var body: some View {
        let channel = highlight.channel
        let programme = highlight.programme

        ZStack(alignment: .bottomLeading) {
            GuideBackground()
            Artwork(url: programme?.imageURL, channel: channel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .overlay {
                    LinearGradient(colors: [Theme.backgroundTop.opacity(0.98), Theme.backgroundTop.opacity(0.7), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .ignoresSafeArea()
                }
                .overlay {
                    LinearGradient(colors: [.clear, Theme.backgroundTop.opacity(0.95)],
                                   startPoint: .center, endPoint: .bottom)
                        .ignoresSafeArea()
                }

            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    ChannelLogo(channel: channel, height: 54)
                    Text("\(channel.displayNumber)")
                        .font(.system(size: 34, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                    Text(channel.name)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }

                Text(programme?.title ?? "No information available")
                    .font(.system(size: 76, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                if let programme, !programme.isPlaceholder {
                    if let subtitle = programme.subtitle {
                        Text(subtitle).font(.system(size: 32, weight: .semibold))
                    }
                    HStack(spacing: 16) {
                        Text("\(Fmt.day(programme.start, relativeTo: store.now)) · \(Fmt.range(programme)) · \(Fmt.duration(programme.duration))")
                            .font(.system(size: 28, weight: .medium))
                        ForEach(programme.badges(on: channel), id: \.self) { Badge(text: $0) }
                        if programme.isNew { Badge(text: "NEW", filled: true, tint: Theme.accent) }
                    }
                    if programme.isOn(at: store.now) {
                        HStack(spacing: 16) {
                            ProgrammeProgress(progress: programme.progress(at: store.now), tint: Theme.live, height: 8)
                                .frame(width: 420)
                            Text(Fmt.remaining(programme, at: store.now))
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    if let synopsis = programme.synopsis {
                        Text(synopsis)
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(5)
                            .frame(maxWidth: 1100, alignment: .leading)
                    }
                }

                HStack(spacing: 30) {
                    Button { onWatch(channel) } label: {
                        Label(programme?.isOn(at: store.now) == true ? "Watch now" : "Watch \(channel.name)",
                              systemImage: "play.fill")
                    }
                    if let programme, programme.start > store.now, !programme.isPlaceholder {
                        Button { reminders.toggle(programme, on: channel) } label: {
                            Label(reminders.isSet(for: programme) ? "Reminder set" : "Remind me",
                                  systemImage: reminders.isSet(for: programme) ? "bell.fill" : "bell")
                        }
                    }
                    Button {
                        store.toggleFavourite(channel)
                    } label: {
                        Label(store.isFavourite(channel) ? "Favourite" : "Add to favourites",
                              systemImage: store.isFavourite(channel) ? "heart.fill" : "heart")
                    }
                    Button { dismiss() } label: { Label("Back to guide", systemImage: "square.grid.3x3") }
                }
                .padding(.top, 10)

                if let programme {
                    LaterOn(channel: channel, programmes: store.upcoming(after: programme))
                }
            }
            .padding(.horizontal, 90)
            .padding(.bottom, 60)
        }
        .foregroundStyle(.white)
    }
}

private struct LaterOn: View {
    let channel: Channel
    let programmes: [Programme]

    var body: some View {
        if !programmes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Later on \(channel.name)")
                    .font(.system(size: 26, weight: .bold))
                ScrollView(.horizontal) {
                    HStack(spacing: 24) {
                        ForEach(programmes) { programme in
                            Button {} label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(Fmt.time(programme.start))
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                    Text(programme.title)
                                        .font(.system(size: 24, weight: .semibold))
                                        .lineLimit(2)
                                    Spacer(minLength: 0)
                                    if let episode = programme.episode {
                                        Text(episode).font(.system(size: 18)).opacity(0.7)
                                    }
                                }
                                .padding(20)
                                .frame(width: 320, height: 150, alignment: .topLeading)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .scrollClipDisabled()
            }
            .padding(.top, 20)
        }
    }
}
