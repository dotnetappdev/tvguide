import SwiftUI

/// Sky Q style "info panel": details of whatever is focused, with artwork
/// that fades into the background on the right.
struct HeroPanel: View {
    @Environment(GuideStore.self) private var store
    let highlight: Highlight?

    var body: some View {
        ZStack(alignment: .leading) {
            if let highlight {
                artwork(for: highlight)
                details(for: highlight)
                    .id(highlight.id)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: highlight?.id)
        .padding(.horizontal, 80)
    }

    private func artwork(for highlight: Highlight) -> some View {
        HStack {
            Spacer()
            Artwork(url: highlight.programme?.imageURL, channel: highlight.channel)
                .frame(width: 560, height: 315)
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                                           .init(color: .black, location: 0.35),
                                           .init(color: .black, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                }
                .mask {
                    LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom)
                }
                .id(highlight.programme?.imageURL ?? URL(string: "about:\(highlight.channel.id)"))
                .transition(.opacity)
        }
        .padding(.trailing, -80)
    }

    private func details(for highlight: Highlight) -> some View {
        let channel = highlight.channel
        let programme = highlight.programme
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ChannelLogo(channel: channel, height: 40)
                Text("\(channel.number)")
                    .font(.system(size: 28, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                Text(channel.name)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(programme?.title ?? "No information available")
                .font(.system(size: 52, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let programme, !programme.isPlaceholder {
                metaRow(programme, channel: channel)
                let synopsis = [programme.subtitle, programme.synopsis].compactMap { $0 }.joined(separator: " — ")
                if !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                }
            }
        }
        .frame(maxWidth: 1100, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func metaRow(_ programme: Programme, channel: Channel) -> some View {
        HStack(spacing: 14) {
            Text(Fmt.duration(programme.duration))
                .font(.system(size: 24, weight: .semibold))
            ForEach(programme.badges(on: channel), id: \.self) { Badge(text: $0) }
            if programme.isNew { Badge(text: "NEW", filled: true, tint: Theme.accent) }

            if programme.isOn(at: store.now) {
                Text("Started at \(Fmt.time(programme.start))")
                    .font(.system(size: 24, weight: .medium))
                ProgrammeProgress(progress: programme.progress(at: store.now), tint: Theme.live)
                    .frame(width: 160)
                Text(Fmt.remaining(programme, at: store.now))
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text("\(Fmt.day(programme.start, relativeTo: store.now)) \(Fmt.range(programme))")
                    .font(.system(size: 24, weight: .medium))
            }
        }
        .foregroundStyle(.white)
    }
}
