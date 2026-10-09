import SwiftUI

/// The scrolling body of the guide: "On now" preview tiles followed by the
/// channel timeline grid (whose time header pins to the top while scrolling).
struct GuideContent: View {
    @Environment(GuideStore.self) private var store
    @Binding var highlight: Highlight?
    @Binding var detail: Highlight?
    @Binding var isGridFocused: Bool

    @FocusState private var focusedCell: String?

    var body: some View {
        GeometryReader { proxy in
            let gridWidth = max(400, proxy.size.width - Theme.channelColumnWidth - Theme.rowSpacing - 80)

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        NowTilesRow(highlight: $highlight, detail: $detail)
                            .padding(.bottom, 28)
                    } header: {
                        sectionHeader("On now")
                    }

                    Section {
                        if store.visibleChannels.isEmpty {
                            EmptyCategoryView(category: store.category)
                        }
                        ForEach(store.visibleChannels) { channel in
                            GuideRow(channel: channel,
                                     gridWidth: gridWidth,
                                     focusedCell: $focusedCell,
                                     onSelect: { detail = Highlight(channel: channel, programme: $0) })
                                .padding(.bottom, Theme.rowSpacing)
                        }
                    } header: {
                        TimelineHeader(gridWidth: gridWidth)
                    }
                }
                .padding(.trailing, 80)
                .padding(.bottom, 60)
            }
            .scrollClipDisabled()
            .focusSection()
        }
        .onChange(of: focusedCell) { _, id in
            isGridFocused = id != nil
            guard let id, let match = lookup(id) else { return }
            highlight = Highlight(channel: match.channel, programme: match.programme)
        }
        .onPlayPauseCommand { jumpToNow() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Finds the channel and listing for a grid cell id (`channelID|start`).
    private func lookup(_ id: String) -> (channel: Channel, programme: Programme)? {
        guard let channelID = id.split(separator: "|").first.map(String.init),
              let channel = store.channel(id: channelID),
              let programme = store.segments(for: channel).first(where: { $0.id == id })
        else { return nil }
        return (channel, programme)
    }

    /// Play/Pause snaps the timeline back to now, keeping the same channel focused.
    private func jumpToNow() {
        let channelID = focusedCell?.split(separator: "|").first.map(String.init)
        store.jumpToNow()
        guard let channelID, let channel = store.channel(id: channelID) else { return }
        let target = store.segments(for: channel).first { $0.isOn(at: store.now) }
        DispatchQueue.main.async { focusedCell = target?.id }
    }
}

/// Day label plus half-hour markers for the visible window, with a "now" pill.
private struct TimelineHeader: View {
    @Environment(GuideStore.self) private var store
    let gridWidth: CGFloat

    var body: some View {
        HStack(spacing: Theme.rowSpacing) {
            HStack(spacing: 10) {
                Text(Fmt.day(store.windowStart, relativeTo: store.now))
                    .font(.system(size: 26, weight: .bold))
                if !store.isAtNow {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(width: Theme.channelColumnWidth, alignment: .leading)
            .padding(.leading, 4)

            ZStack(alignment: .leading) {
                ForEach(0..<slotCount, id: \.self) { index in
                    let date = store.windowStart.addingTimeInterval(Double(index) * GuideStore.slot)
                    HStack(spacing: 10) {
                        Rectangle().fill(.white.opacity(0.35)).frame(width: 2, height: 22)
                        Text(Fmt.time(date))
                            .font(.system(size: 24, weight: .semibold))
                            .monospacedDigit()
                    }
                    .offset(x: CGFloat(index) * slotWidth)
                }

                if let nowX {
                    Text("NOW")
                        .font(.system(size: 16, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.live, in: Capsule())
                        .offset(x: nowX - 24, y: 22)
                }
            }
            .frame(width: gridWidth, height: 44, alignment: .leading)
        }
        .padding(.vertical, 12)
        .background(alignment: .bottom) {
            // Opaque strip so rows scrolling underneath stay hidden.
            Rectangle()
                .fill(Theme.backgroundTop.opacity(0.92))
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
                .padding(.trailing, -80)
        }
        .animation(.easeInOut(duration: 0.25), value: store.windowStart)
    }

    private var slotCount: Int { Int(GuideStore.windowSpan / GuideStore.slot) }
    private var slotWidth: CGFloat { gridWidth / CGFloat(slotCount) }

    private var nowX: CGFloat? {
        let offset = store.now.timeIntervalSince(store.windowStart)
        guard offset >= 0, offset <= GuideStore.windowSpan else { return nil }
        return CGFloat(offset / GuideStore.windowSpan) * gridWidth
    }
}

private struct EmptyCategoryView: View {
    let category: ChannelCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category == .favourites ? "No favourites yet" : "No channels")
                .font(.system(size: 30, weight: .semibold))
            Text(category == .favourites
                 ? "Press and hold a channel or programme in the guide to add it to your favourites."
                 : "There are no channels in this category.")
                .font(.system(size: 24))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .focusable()
    }
}
