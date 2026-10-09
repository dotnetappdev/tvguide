import SwiftUI

/// Top level screen: header, hero preview, sidebar and the scrolling guide.
struct GuideRootView: View {
    @Environment(GuideStore.self) private var store
    @State private var highlight: Highlight?
    @State private var detail: Highlight?
    @State private var isGridFocused = false
    @State private var showingRegions = false

    var body: some View {
        ZStack {
            GuideBackground()

            VStack(spacing: 0) {
                TopBar()
                HeroPanel(highlight: highlight ?? fallbackHighlight)
                    .frame(height: Theme.heroHeight)

                HStack(alignment: .top, spacing: 0) {
                    GuideSidebar(showingRegions: $showingRegions,
                                 isLocked: isGridFocused && !store.isAtNow)
                        .frame(width: Theme.sidebarWidth)

                    GuideContent(highlight: $highlight,
                                 detail: $detail,
                                 isGridFocused: $isGridFocused)
                }
            }

            if case .loading = store.state, store.schedules.isEmpty {
                LoadingOverlay()
            }
        }
        .fullScreenCover(item: $detail) { item in
            ProgrammeDetailView(highlight: item)
                .environment(store)
        }
        .sheet(isPresented: $showingRegions) {
            RegionPicker()
                .environment(store)
        }
    }

    private var fallbackHighlight: Highlight? {
        guard let channel = store.visibleChannels.first ?? store.channels.first else { return nil }
        return Highlight(channel: channel, programme: store.current(on: channel))
    }
}

/// Brand, date, data status and clock.
private struct TopBar: View {
    @Environment(GuideStore.self) private var store

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 14) {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.glow],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("TV Guide")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }

            Text(Fmt.longDay(store.now))
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.secondaryText)

            Spacer()

            StatusChip(state: store.state, region: store.region.name)

            Text(Fmt.time(store.now))
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.default, value: Fmt.time(store.now))
        }
        .padding(.horizontal, 80)
        .padding(.top, 40)
        .padding(.bottom, 8)
    }
}

private struct StatusChip: View {
    let state: GuideStore.LoadState
    let region: String

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
        }
        .font(.system(size: 22, weight: .semibold))
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: Capsule())
    }

    private var label: String {
        switch state {
        case .loading: "Loading listings…"
        case .ready(.live(let date)), .ready(.cached(let date)): "Freeview · \(region) · updated \(Fmt.time(date))"
        case .ready(.sample): "Sample listings · offline"
        case .failed: "Couldn't refresh listings"
        }
    }

    private var color: Color {
        switch state {
        case .loading: .yellow
        case .ready(.sample), .failed: .orange
        case .ready: .green
        }
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
            Text("Fetching the Freeview guide…")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(60)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}
