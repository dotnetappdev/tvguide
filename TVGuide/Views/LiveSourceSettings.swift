import SwiftUI

/// Live TV setup: connect a Channels DVR server (found automatically on the
/// home network, or by address), or use any M3U playlist of HLS streams.
struct LiveSourceSettings: View {
    @Environment(GuideStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var discovery = LiveTVDiscovery()
    @State private var serverText = ""
    @State private var playlistText = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            GuideBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    header
                    status
                    channelsDVRSection
                    tunersSection
                    playlistSection
                    Button { dismiss() } label: { Label("Done", systemImage: "checkmark") }
                }
                .padding(.horizontal, 100)
                .padding(.vertical, 70)
                .frame(maxWidth: 1500, alignment: .leading)
            }
            .scrollClipDisabled()
        }
        .onAppear {
            serverText = store.channelsServer.map { $0.host ?? $0.absoluteString } ?? ""
            playlistText = store.channelsServer == nil ? store.liveSourceURL?.absoluteString ?? "" : ""
            discovery.start()
        }
        .onDisappear { discovery.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live TV")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("Apple TV has no aerial input, so live pictures come from a TV tuner on your network. The easiest setup is an HDHomeRun Freeview tuner with Channels DVR, which streams every channel to Apple TV and supplies the guide from the aerial.")
                .font(.system(size: 24))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder
    private var status: some View {
        if let message = error ?? store.liveSourceStatus {
            Label(message, systemImage: error != nil || store.streams.isEmpty ? "exclamationmark.triangle" : "dot.radiowaves.left.and.right")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(error != nil || store.streams.isEmpty ? Color.orange : Theme.accent)
        }
    }

    // MARK: Channels DVR

    private var channelsDVRSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Channels DVR", detail: "Recommended")

            if let server = store.channelsServer {
                HStack(spacing: 24) {
                    Label("Connected to \(server.host ?? server.absoluteString)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                    Button(role: .destructive) { run { try await store.setChannelsServer(nil) } } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            }

            HStack(spacing: 16) {
                Text(discovery.isSearching ? "Looking for servers on your network…" : "Servers on your network")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                if discovery.isSearching { ProgressView() }
            }
            if discovery.servers.isEmpty, !discovery.isSearching {
                Text("None found. Enter its address below (shown in Channels DVR's settings, usually port 8089).")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.secondaryText)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 24) {
                    ForEach(discovery.servers) { server in
                        Button { connect(server.url) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(server.name, systemImage: "server.rack").font(.system(size: 24, weight: .semibold))
                                Text(server.url.absoluteString).font(.system(size: 18)).opacity(0.7)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollClipDisabled()

            HStack(spacing: 24) {
                TextField("Server address, e.g. 192.168.1.20", text: $serverText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(width: 800)
                Button {
                    guard let url = ChannelsDVRClient.serverURL(from: serverText) else {
                        error = "That doesn't look like an address."
                        return
                    }
                    connect(url)
                } label: {
                    Label(busy ? "Connecting…" : "Connect", systemImage: "link")
                }
                .disabled(busy)
            }
        }
    }

    // MARK: HDHomeRun

    @ViewBuilder
    private var tunersSection: some View {
        if !discovery.tuners.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Tuners found", detail: nil)
                ForEach(discovery.tuners) { tuner in
                    Label("\(tuner.friendlyName ?? "HDHomeRun") at \(tuner.localIP ?? "your network")",
                          systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 24, weight: .semibold))
                }
                Text("HDHomeRun tuners send a stream format Apple TV can't play on its own. Add the tuner to Channels DVR (on a Mac, PC or NAS) and connect to that server above.")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    // MARK: Playlist

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Other live TV source", detail: "M3U playlist")
            Text("Jellyfin, Plex, TVHeadend or an IPTV service: enter an M3U playlist of HLS streams. Channels are matched by name; if the playlist links an XMLTV guide, it's used for any channel the internet guide is missing.")
                .font(.system(size: 22))
                .foregroundStyle(Theme.secondaryText)
            HStack(spacing: 24) {
                TextField("http://…/playlist.m3u", text: $playlistText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(width: 800)
                Button {
                    run {
                        if store.channelsServer != nil { try await store.setChannelsServer(nil) }
                        await store.setLiveSource(playlistText)
                    }
                } label: { Label("Use playlist", systemImage: "list.bullet") }
                .disabled(busy)
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String, detail: String?) -> some View {
        HStack(spacing: 14) {
            Text(title).font(.system(size: 32, weight: .bold))
            if let detail {
                Text(detail.uppercased())
                    .font(.system(size: 16, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(Theme.ink)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private func connect(_ url: URL) {
        serverText = url.host ?? url.absoluteString
        run { try await store.setChannelsServer(url) }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            do { try await action() } catch {
                self.error = "Couldn't connect: \(error.localizedDescription). Check the address and that Channels DVR is running."
            }
            busy = false
        }
    }
}
