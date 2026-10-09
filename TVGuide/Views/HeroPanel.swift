import AVKit
import SwiftUI

/// Sky Q style info panel: a live preview window of the focused channel on
/// the left (it follows focus as you move up and down the guide) and the
/// focused programme's details on the right.
struct HeroPanel: View {
    @Environment(GuideStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    let highlight: Highlight?

    var body: some View {
        HStack(alignment: .top, spacing: 44) {
            if let highlight {
                LivePreview(channel: highlight.channel, programme: highlight.programme)
                    .frame(width: 448, height: 252)
                details(for: highlight)
                    .id(highlight.id)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .animation(.easeOut(duration: 0.2), value: highlight?.id)
        .padding(.horizontal, 80)
        .padding(.top, 14)
    }

    private func details(for highlight: Highlight) -> some View {
        let channel = highlight.channel
        let programme = highlight.programme
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ChannelLogo(channel: channel, height: 40)
                Text("\(channel.displayNumber)")
                    .font(.system(size: 28, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                Text(channel.name)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(programme?.title ?? "No information available")
                .font(.system(size: 46, weight: .bold))
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
    }

    private func metaRow(_ programme: Programme, channel: Channel) -> some View {
        HStack(spacing: 14) {
            Text(Fmt.duration(programme.duration))
                .font(.system(size: 24, weight: .semibold))
            ForEach(programme.badges(on: channel), id: \.self) { Badge(text: $0) }
            if programme.isNew { Badge(text: "NEW", filled: true, tint: Theme.accent) }
            if reminders.isSet(for: programme) {
                Image(systemName: "bell.fill").foregroundStyle(Theme.accent)
            }

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

/// The little TV in the corner. Plays the focused channel muted when a live
/// stream is available (after a short pause, so scrolling quickly through the
/// guide doesn't start dozens of streams); otherwise shows the programme's artwork.
struct LivePreview: View {
    @Environment(GuideStore.self) private var store
    let channel: Channel
    let programme: Programme?
    @State private var player: AVPlayer = {
        let player = AVPlayer()
        player.isMuted = true
        return player
    }()
    @State private var isPlaying = false

    var body: some View {
        let stream = store.stream(for: channel)
        // Radio has no pictures to preview (and the preview is muted), so it shows the artwork.
        let showsVideo = stream != nil && !channel.isRadio && programme?.isOn(at: store.now) != false

        ZStack(alignment: .bottomLeading) {
            Artwork(url: programme?.imageURL, channel: channel)
                .id(programme?.imageURL ?? URL(string: "about:\(channel.id)"))
                .transition(.opacity)
            if showsVideo {
                VideoSurface(player: player)
                    .opacity(isPlaying ? 1 : 0)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            HStack(spacing: 10) {
                Text("\(channel.displayNumber)")
                    .font(.system(size: 24, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                if showsVideo {
                    Text("LIVE")
                        .font(.system(size: 14, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(Theme.ink)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                if let programme, programme.isOn(at: store.now) {
                    ProgrammeProgress(progress: programme.progress(at: store.now), tint: Theme.accent, height: 5)
                        .frame(width: 120)
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .animation(.easeOut(duration: 0.25), value: isPlaying)
        .task(id: "\(channel.id)|\(stream?.absoluteString ?? "")|\(store.tunedChannelID == nil)|\(showsVideo)") {
            isPlaying = false
            // Pause while full screen TV is showing, and when there's nothing to play.
            guard showsVideo, let stream, store.tunedChannelID == nil else {
                player.pause()
                player.replaceCurrentItem(with: nil)
                return
            }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            player.replaceCurrentItem(with: AVPlayerItem(url: stream))
            player.play()
            isPlaying = true
        }
        .onDisappear { player.pause() }
    }
}
