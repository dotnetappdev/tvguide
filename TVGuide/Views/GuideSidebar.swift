import SwiftUI

/// Left hand menu: channel filters, quick time jumps and settings.
struct GuideSidebar: View {
    @Environment(GuideStore.self) private var store
    @Binding var showingRegions: Bool
    @Binding var showingLiveSettings: Bool
    @Binding var showingNumberPad: Bool
    @Binding var showingSearch: Bool
    @Binding var showingReminders: Bool
    /// While the user pages back through the timeline the sidebar steps aside,
    /// so pressing left keeps scrolling time instead of jumping into the menu.
    let isLocked: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("TV guide")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                Button { showingSearch = true } label: { Label("Search", systemImage: "magnifyingglass") }
                    .buttonStyle(SidebarButtonStyle(isSelected: false))

                ForEach(ChannelCategory.filters) { category in
                    Button {
                        store.category = category
                    } label: {
                        Label(category.title, systemImage: category.symbol)
                    }
                    .buttonStyle(SidebarButtonStyle(isSelected: store.category == category))
                }

                sectionTitle("Watch")
                Button { showingNumberPad = true } label: {
                    Label("Channel number", systemImage: "number")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: false))
                Button { showingReminders = true } label: { Label("Reminders", systemImage: "bell") }
                    .buttonStyle(SidebarButtonStyle(isSelected: false))
                Button { showingLiveSettings = true } label: {
                    Label("Live TV", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: false))

                sectionTitle("Jump to")
                Button { store.jumpToNow() } label: { Label("Now", systemImage: "clock") }
                    .buttonStyle(SidebarButtonStyle(isSelected: false))
                Button { store.jump(to: primeTime(dayOffset: 0)) } label: {
                    Label("Tonight", systemImage: "moon.stars")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: false))
                Button { store.jump(to: primeTime(dayOffset: 1)) } label: {
                    Label("Tomorrow", systemImage: "sunrise")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: false))

                sectionTitle("Settings")
                Button { showingRegions = true } label: {
                    Label(store.region.name, systemImage: "mappin.and.ellipse")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: false))
                Button { Task { await store.setIncludesSkyChannels(!store.includesSkyChannels) } } label: {
                    Label(store.includesSkyChannels ? "Sky channels: On" : "Sky channels: Off",
                          systemImage: store.includesSkyChannels ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: store.includesSkyChannels))
                Button { Task { await store.load(forceRefresh: true) } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: false))
            }
            .padding(.leading, 50)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .disabled(isLocked)
        .focusSection()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 18, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 4)
    }

    /// 7pm on the given day (tonight / tomorrow night).
    private func primeTime(dayOffset: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: dayOffset, to: store.now) ?? store.now
        return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day) ?? day
    }
}

struct SidebarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        SidebarButtonBody(configuration: configuration, isSelected: isSelected)
    }

    private struct SidebarButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let isSelected: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .labelStyle(SidebarLabelStyle())
                .font(.system(size: 24, weight: isSelected || isFocused ? .semibold : .regular))
                .foregroundStyle(isFocused ? Theme.ink : (isSelected ? Theme.accent : .white.opacity(0.85)))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isFocused ? Theme.accent : (isSelected ? Color.white.opacity(0.10) : .clear))
                }
                .scaleEffect(isFocused ? 1.04 : 1)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .shadow(color: .black.opacity(isFocused ? 0.35 : 0), radius: 14, y: 8)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }

    private struct SidebarLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 16) {
                configuration.icon.frame(width: 32)
                configuration.title.lineLimit(1)
            }
        }
    }
}
