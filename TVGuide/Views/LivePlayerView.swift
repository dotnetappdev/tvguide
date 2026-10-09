import AVKit
import Combine
import MediaPlayer
import SwiftUI

/// Full screen live TV. Swipe/press up and down to change channel, like the
/// channel +/- buttons on a Sky remote; a now & next banner appears on every
/// channel change. Menu returns to the guide. Radio stations play audio-only
/// with a Sky style "now playing" screen.
struct LivePlayerView: View {
    @Environment(GuideStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var player = AVPlayer()
    @State private var showBanner = true
    @State private var bannerTask: Task<Void, Never>?
    @State private var isBuffering = false
    @State private var playbackError: String?
    @State private var appMessage: String?
    /// Which of the channel's streams is playing (radio stations can have several).
    @State private var streamIndex = 0

    var body: some View {
        let channel = store.tunedChannel
        let candidates = channel.map(store.streams(for:)) ?? []
        let stream = candidates.indices.contains(streamIndex) ? candidates[streamIndex] : candidates.first

        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            if let channel {
                if stream != nil, playbackError == nil, channel.isRadio {
                    RadioNowPlaying(channel: channel, isBuffering: isBuffering)
                } else if stream != nil, playbackError == nil {
                    VideoSurface(player: player).ignoresSafeArea()
                    if isBuffering {
                        ProgressView().scaleEffect(1.6).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    NoStreamPanel(channel: channel,
                                  hasLiveSource: store.liveSourceURL != nil,
                                  error: playbackError,
                                  message: appMessage,
                                  openApp: { openBroadcasterApp(for: channel) })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if showBanner, !channel.isRadio {
                    ChannelBanner(channel: channel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        // Take focus ourselves unless the "Watch in app" button is on screen.
        .focusable((stream != nil && playbackError == nil) || channel.flatMap { Broadcaster.for($0) } == nil)
        .onMoveCommand { direction in
            switch direction {
            case .up: zap(by: 1)
            case .down: zap(by: -1)
            default: flashBanner()
            }
        }
        .onTapGesture { flashBanner() }
        .onPlayPauseCommand {
            if player.timeControlStatus == .paused { player.play() } else { player.pause() }
        }
        .channelNumberEntry()
        .reminderAlerts()
        .animation(.easeInOut(duration: 0.25), value: showBanner)
        .task(id: "\(store.tunedChannelID ?? "")|\(stream?.absoluteString ?? "")") { play(stream) }
        .onReceive(player.publisher(for: \.timeControlStatus)) { status in
            isBuffering = status == .waitingToPlayAtSpecifiedRate
        }
        .onReceive(player.publisher(for: \.currentItem?.status)) { status in
            guard status == .failed else { return }
            if streamIndex + 1 < candidates.count {
                streamIndex += 1 // try the station's next stream
            } else {
                playbackError = player.currentItem?.error?.localizedDescription ?? "The stream couldn't be played."
            }
        }
        .task(id: "\(store.tunedChannelID ?? "")|\(channel.flatMap(store.current(on:))?.id ?? "")") {
            updateNowPlaying(channel)
        }
        .onChange(of: store.tunedChannelID) { _, _ in streamIndex = 0 }
        .onChange(of: scenePhase) { _, phase in
            // Radio keeps playing in the background (like the Music app); TV pauses.
            if phase == .background, channel?.isRadio != true { player.pause() }
        }
        .onDisappear {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
            store.tunedChannelID = nil
        }
    }

    private func play(_ url: URL?) {
        playbackError = nil
        appMessage = nil
        flashBanner()
        guard let url else {
            player.replaceCurrentItem(with: nil)
            return
        }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
    }

    /// Station and programme for the system Now Playing screen (shown when radio plays in the background).
    private func updateNowPlaying(_ channel: Channel?) {
        guard let channel, channel.isRadio else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let programme = store.current(on: channel)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: programme?.title ?? channel.name,
            MPMediaItemPropertyArtist: channel.name,
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
    }

    private func zap(by offset: Int) {
        guard let current = store.tunedChannel, let next = store.channel(after: current, offset: offset) else { return }
        store.tune(next)
    }

    private func flashBanner() {
        showBanner = true
        bannerTask?.cancel()
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            showBanner = false
        }
    }

    /// Tries each of the broadcaster's deep links in turn.
    private func openBroadcasterApp(for channel: Channel) {
        guard let broadcaster = Broadcaster.for(channel) else { return }
        func attempt(_ links: ArraySlice<URL>) {
            guard let url = links.first else {
                appMessage = "Install the \(broadcaster.appName) app from the App Store to watch \(channel.name)."
                return
            }
            openURL(url) { accepted in
                if !accepted { attempt(links.dropFirst()) }
            }
        }
        attempt(broadcaster.links[...])
    }
}

/// Sky style now & next banner shown when changing channel.
private struct ChannelBanner: View {
    @Environment(GuideStore.self) private var store
    let channel: Channel

    var body: some View {
        let now = store.current(on: channel)
        let next = store.next(on: channel)

        HStack(alignment: .center, spacing: 36) {
            VStack(spacing: 10) {
                Text("\(channel.displayNumber)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                ChannelLogo(channel: channel, height: 44)
            }
            .frame(width: 200)

            VStack(alignment: .leading, spacing: 16) {
                bannerLine(label: "Now", programme: now, showProgress: true)
                Divider().overlay(.white.opacity(0.2))
                bannerLine(label: "Next", programme: next, showProgress: false)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 12) {
                Text(Fmt.time(store.now))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Label("Channel up / down", systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.horizontal, 50)
        .padding(.vertical, 30)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Theme.backgroundBottom.opacity(0.96), Theme.backgroundTop.opacity(0.96)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.accent).frame(height: 4).padding(.horizontal, 28)
                }
                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        }
        .padding(.horizontal, 80)
        .padding(.bottom, 60)
        .foregroundStyle(.white)
    }

    private func bannerLine(label: String, programme: Programme?, showProgress: Bool) -> some View {
        HStack(spacing: 20) {
            Text(label.uppercased())
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(width: 80)
                .padding(.vertical, 4)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 6))
            if let programme {
                Text(Fmt.time(programme.start))
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryText)
                Text(programme.title)
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(1)
                if showProgress {
                    ProgrammeProgress(progress: programme.progress(at: store.now), tint: Theme.accent)
                        .frame(width: 200)
                    Text(Fmt.remaining(programme, at: store.now))
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                Text("No information").font(.system(size: 28)).foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

/// Shown when there's no stream for the channel: offers the broadcaster's app
/// and explains how to add a live TV source.
private struct NoStreamPanel: View {
    let channel: Channel
    let hasLiveSource: Bool
    let error: String?
    let message: String?
    let openApp: () -> Void

    private var explanation: String {
        if let error { return error }
        if channel.isRadio {
            return "This station doesn't have a public internet stream that Apple TV can play."
        }
        if !hasLiveSource {
            return "Connect a TV tuner under Live TV in the guide's sidebar (an HDHomeRun with Channels DVR, or a Jellyfin, TVHeadend or IPTV playlist) to watch here."
        }
        if channel.id.hasPrefix("sky:") {
            return "Sky channels come by satellite, so a Freeview tuner can't receive them. Watch them in the NOW app."
        }
        return "Your live TV source doesn't include this channel."
    }

    var body: some View {
        ZStack {
            GuideBackground()
            VStack(spacing: 28) {
                ChannelLogo(channel: channel, height: 90)
                Text(error == nil ? "\(channel.name) isn't streaming in TV Guide" : "Couldn't play \(channel.name)")
                    .font(.system(size: 44, weight: .bold))
                Text(explanation)
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 1100)

                if let broadcaster = Broadcaster.for(channel) {
                    Button(action: openApp) {
                        Label("Watch in \(broadcaster.appName)", systemImage: "arrow.up.forward.app")
                    }
                }
                if let message {
                    Text(message).font(.system(size: 22)).foregroundStyle(Theme.accent)
                }
            }
            .padding(.bottom, 200)
        }
    }
}

/// Bare AVPlayerLayer host – no transport bar, so the remote's directional
/// presses can be used for channel up / down.
struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        view.playerLayer.player = player
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// Sky style radio screen: big station logo and number, what's on, a moving
/// level meter, and what's next.
private struct RadioNowPlaying: View {
    @Environment(GuideStore.self) private var store
    let channel: Channel
    let isBuffering: Bool

    var body: some View {
        let now = store.current(on: channel)
        let next = store.next(on: channel)

        ZStack {
            GuideBackground()
            HStack(alignment: .center, spacing: 90) {
                VStack(spacing: 26) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: channel.brandHex), Theme.backgroundTop],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        AsyncImage(url: channel.logoURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFit().padding(70)
                            } else {
                                Text(channel.name)
                                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.5)
                                    .padding(40)
                            }
                        }
                    }
                    .frame(width: 460, height: 460)
                    .overlay {
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 30, y: 16)

                    Text(channel.displayNumber)
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        Label("RADIO", systemImage: "radio")
                            .font(.system(size: 20, weight: .heavy))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .foregroundStyle(Theme.ink)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                        Text(channel.name)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }

                    Text(now?.title ?? channel.name)
                        .font(.system(size: 62, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    if let track = store.nowPlaying[channel.id] {
                        Label(track, systemImage: "music.note")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }

                    if let synopsis = now?.synopsis {
                        Text(synopsis)
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(4)
                    }

                    if let now {
                        HStack(spacing: 18) {
                            Text(Fmt.range(now)).font(.system(size: 24, weight: .semibold)).monospacedDigit()
                            ProgrammeProgress(progress: now.progress(at: store.now), tint: Theme.accent, height: 8)
                                .frame(width: 360)
                            Text(Fmt.remaining(now, at: store.now))
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }

                    LevelMeter(isActive: !isBuffering)
                        .frame(height: 70)
                        .padding(.vertical, 6)

                    if let next {
                        HStack(spacing: 18) {
                            Text("NEXT")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 80)
                                .padding(.vertical, 4)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 6))
                            Text(Fmt.time(next.start))
                                .font(.system(size: 26, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.secondaryText)
                            Text(next.title)
                                .font(.system(size: 28, weight: .bold))
                                .lineLimit(1)
                        }
                    }

                    Label("Up / down for the next station · Menu for the guide", systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 10)
                }
                .frame(maxWidth: 1000, alignment: .leading)
            }
            .padding(.horizontal, 120)
            .foregroundStyle(.white)
            .id(channel.id)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.3), value: channel.id)
        .task(id: channel.id) {
            // Keep the song title current while the station is on screen.
            while !Task.isCancelled {
                await store.refreshNowPlaying(for: channel)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}

/// Bouncing level bars while audio is playing.
private struct LevelMeter: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !isActive)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<24, id: \.self) { index in
                    let phase = Double(index) * 0.7
                    let level = isActive ? 0.25 + 0.75 * abs(sin(t * (2.1 + Double(index % 5) * 0.37) + phase)) : 0.12
                    Capsule()
                        .fill(index % 6 == 0 ? Theme.accent : Theme.accent.opacity(0.65))
                        .frame(width: 14)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .scaleEffect(x: 1, y: level, anchor: .bottom)
                }
            }
        }
    }
}
