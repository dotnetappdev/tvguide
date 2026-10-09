import SwiftUI

/// Top level screen: header, hero preview, sidebar and the scrolling guide.
struct GuideRootView: View {
    @Environment(GuideStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @State private var highlight: Highlight?
    @State private var detail: Highlight?
    @State private var isGridFocused = false
    @State private var showingRegions = false
    @State private var showingLiveSettings = false
    @State private var showingNumberPad = false
    @State private var showingSearch = false
    @State private var showingReminders = false

    var body: some View {
        ZStack {
            GuideBackground()

            VStack(spacing: 0) {
                TopBar()
                    .sheet(isPresented: $showingRegions) {
                        RegionPicker().environment(store)
                    }
                    .fullScreenCover(isPresented: $showingReminders) {
                        RemindersView().environment(store).environment(reminders)
                    }
                HeroPanel(highlight: highlight ?? fallbackHighlight)
                    .frame(height: Theme.heroHeight)
                    .fullScreenCover(isPresented: $showingNumberPad) {
                        NumberPad(onTune: tuneAfterDismiss).environment(store)
                    }

                HStack(alignment: .top, spacing: 0) {
                    GuideSidebar(showingRegions: $showingRegions,
                                 showingLiveSettings: $showingLiveSettings,
                                 showingNumberPad: $showingNumberPad,
                                 showingSearch: $showingSearch,
                                 showingReminders: $showingReminders,
                                 isLocked: isGridFocused && !store.isAtNow)
                        .frame(width: Theme.sidebarWidth)
                        .fullScreenCover(isPresented: $showingLiveSettings) {
                            LiveSourceSettings().environment(store)
                        }

                    GuideContent(highlight: $highlight,
                                 detail: $detail,
                                 isGridFocused: $isGridFocused)
                        .fullScreenCover(isPresented: $showingSearch) {
                            SearchView(onOpen: { detail = $0 }).environment(store).environment(reminders)
                        }
                }
            }
            .fullScreenCover(isPresented: isWatching) {
                LivePlayerView().environment(store).environment(reminders)
            }

            if case .loading = store.state, store.schedules.isEmpty {
                LoadingOverlay()
            }
        }
        .fullScreenCover(item: $detail) { item in
            ProgrammeDetailView(highlight: item, onWatch: tuneAfterDismiss)
                .environment(store)
                .environment(reminders)
        }
        .channelNumberEntry()
        .reminderAlerts(isActive: store.tunedChannelID == nil && detail == nil && !isShowingOverlay)
    }

    /// Any full screen page on top of the guide (reminder alerts wait until it closes).
    private var isShowingOverlay: Bool {
        showingSearch || showingReminders || showingNumberPad || showingLiveSettings || showingRegions
    }

    /// Full screen live TV is shown whenever a channel is tuned.
    private var isWatching: Binding<Bool> {
        Binding(get: { store.tunedChannelID != nil },
                set: { if !$0 { store.tunedChannelID = nil } })
    }

    /// Tunes once the presenting screen has finished closing.
    private func tuneAfterDismiss(_ channel: Channel) {
        detail = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { store.tune(channel) }
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
                    .foregroundStyle(Theme.accent)
                Text("TV Guide")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            Text(Fmt.longDay(store.now))
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.secondaryText)

            Spacer()

            StatusChip(state: store.state,
                       region: store.region.name + (store.includesSkyChannels ? " + Sky" : ""))

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
        case .ready(.tuner): "Guide from your tuner · \(region)"
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
