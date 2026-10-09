import AVKit
import Combine
import SwiftUI

/// Full screen live TV. Swipe/press up and down to change channel, like the
/// channel +/- buttons on a Sky remote; a now & next banner appears on every
/// channel change. Menu returns to the guide.
struct LivePlayerView: View {
    @Environment(GuideStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var player = AVPlayer()
    @State private var showBanner = true
    @State private var bannerTask: Task<Void, Never>?
    @State private var isBuffering = false
    @State private var playbackError: String?
    @State private var appMessage: String?

    var body: some View {
        let channel = store.tunedChannel
        let stream = channel.flatMap(store.stream(for:))

        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            if let channel {
                if stream != nil, playbackError == nil {
                    PlayerLayerView(player: player).ignoresSafeArea()
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

                if showBanner {
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
        .animation(.easeInOut(duration: 0.25), value: showBanner)
        .task(id: "\(store.tunedChannelID ?? "")|\(stream?.absoluteString ?? "")") { play(stream) }
        .onReceive(player.publisher(for: \.timeControlStatus)) { status in
            isBuffering = status == .waitingToPlayAtSpecifiedRate
        }
        .onReceive(player.publisher(for: \.currentItem?.status)) { status in
            if status == .failed {
                playbackError = player.currentItem?.error?.localizedDescription ?? "The stream couldn't be played."
            }
        }
        .onDisappear {
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
                Text("\(channel.number)")
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

    var body: some View {
        ZStack {
            GuideBackground()
            VStack(spacing: 28) {
                ChannelLogo(channel: channel, height: 90)
                Text(error == nil ? "\(channel.name) isn't streaming in TV Guide" : "Couldn't play \(channel.name)")
                    .font(.system(size: 44, weight: .bold))
                Text(error ?? (hasLiveSource
                     ? "Your live TV playlist doesn't include this channel."
                     : "Add a live TV playlist (Channels DVR, Jellyfin, TVHeadend or IPTV) under Live TV in the guide's sidebar to watch here."))
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
private struct PlayerLayerView: UIViewRepresentable {
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
