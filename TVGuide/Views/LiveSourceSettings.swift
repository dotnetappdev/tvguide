import SwiftUI

/// Settings for where live TV streams come from: an M3U playlist URL.
struct LiveSourceSettings: View {
    @Environment(GuideStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var isSaving = false

    var body: some View {
        ZStack {
            GuideBackground()
            VStack(alignment: .leading, spacing: 30) {
                Text("Live TV")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(Theme.accent)

                Text("Enter the address of an M3U playlist of HLS streams – for example from Channels DVR (http://<server>:8089/devices/ANY/channels.m3u?format=hls), Jellyfin, Plex, TVHeadend or your IPTV provider. Channels are matched to the guide by tvg-id or name.")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: 1300, alignment: .leading)

                TextField("http://", text: $urlText)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(maxWidth: 1300)

                HStack(spacing: 30) {
                    Button {
                        isSaving = true
                        Task {
                            await store.setLiveSource(urlText)
                            isSaving = false
                        }
                    } label: {
                        Label(isSaving ? "Loading…" : "Save", systemImage: "checkmark")
                    }
                    .disabled(isSaving)

                    if store.liveSourceURL != nil {
                        Button(role: .destructive) {
                            urlText = ""
                            Task { await store.setLiveSource("") }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }

                    Button { dismiss() } label: { Label("Done", systemImage: "xmark") }
                }

                if let status = store.liveSourceStatus {
                    Label(status, systemImage: store.streams.isEmpty ? "exclamationmark.triangle" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(store.streams.isEmpty ? Color.orange : Theme.accent)
                }

                Text("Without a playlist, choosing a channel offers to open the broadcaster's own app (BBC iPlayer, ITVX, Channel 4, 5, U) where available.")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: 1300, alignment: .leading)
            }
            .padding(100)
        }
        .onAppear { urlText = store.liveSourceURL?.absoluteString ?? "" }
    }
}
