import SwiftUI

/// Horizontal rail of preview tiles: what's on now on each channel, with
/// artwork, progress and what's next.
struct NowTilesRow: View {
    @Environment(GuideStore.self) private var store
    @Binding var highlight: Highlight?
    @Binding var detail: Highlight?
    @FocusState private var focusedTile: String?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 36) {
                ForEach(store.visibleChannels) { channel in
                    let current = store.current(on: channel)
                    Button {
                        store.tune(channel)
                    } label: {
                        NowTile(channel: channel, current: current, next: store.next(on: channel), now: store.now)
                    }
                    .buttonStyle(.card)
                    .focused($focusedTile, equals: channel.id)
                    .contextMenu {
                        Button { detail = Highlight(channel: channel, programme: current) } label: {
                            Label("Programme info", systemImage: "info.circle")
                        }
                        Button { store.toggleFavourite(channel) } label: {
                            Label(store.isFavourite(channel) ? "Remove from favourites" : "Add to favourites",
                                  systemImage: store.isFavourite(channel) ? "heart.slash" : "heart")
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .scrollClipDisabled()
        .onChange(of: focusedTile) { _, id in
            guard let id, let channel = store.channel(id: id) else { return }
            highlight = Highlight(channel: channel, programme: store.current(on: channel))
        }
    }
}

private struct NowTile: View {
    let channel: Channel
    let current: Programme?
    let next: Programme?
    let now: Date

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Artwork(url: current?.imageURL, channel: channel)
                .frame(width: 400, height: 225)

            LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                Text(current?.title ?? "No information")
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(1)
                if let next {
                    Text("Next \(Fmt.time(next.start))  \(next.title)")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                if let current {
                    ProgrammeProgress(progress: current.progress(at: now), tint: Theme.live, height: 5)
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 10) {
                ChannelLogo(channel: channel, height: 34)
                Text("\(channel.number)")
                    .font(.system(size: 24, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .shadow(radius: 4)
            }
            .padding(14)
        }
        .frame(width: 400, height: 225)
        .foregroundStyle(.white)
    }
}
