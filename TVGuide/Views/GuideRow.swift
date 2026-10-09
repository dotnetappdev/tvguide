import SwiftUI

/// One channel's row in the timeline: channel badge plus the programmes that
/// fall inside the visible 2 hour window, sized by duration.
struct GuideRow: View {
    @Environment(GuideStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    let channel: Channel
    let gridWidth: CGFloat
    var focusedCell: FocusState<String?>.Binding
    let onSelect: (Programme) -> Void
    let onInfo: (Programme) -> Void

    var body: some View {
        let segments = store.segments(for: channel)

        HStack(spacing: Theme.rowSpacing) {
            ChannelCell(channel: channel, isFavourite: store.isFavourite(channel))

            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, programme in
                    Button { onSelect(programme) } label: {
                        ProgrammeCellLabel(programme: programme,
                                           continuesBefore: programme.start < store.windowStart,
                                           continuesAfter: programme.end > store.windowEnd,
                                           hasReminder: reminders.isSet(for: programme),
                                           width: width(of: programme))
                    }
                    .buttonStyle(ProgrammeCellStyle(isOnNow: programme.isOn(at: store.now),
                                                    isPlaceholder: programme.isPlaceholder))
                    .frame(width: width(of: programme))
                    .focused(focusedCell, equals: programme.id)
                    .onMoveCommand { direction in
                        handleMove(direction, from: programme,
                                   isFirst: index == 0, isLast: index == segments.count - 1)
                    }
                    .contextMenu {
                        Button { store.tune(channel) } label: {
                            Label("Watch \(channel.displayNumber) \(channel.name)", systemImage: "play.fill")
                        }
                        if programme.start > store.now, !programme.isPlaceholder {
                            Button { reminders.toggle(programme, on: channel) } label: {
                                Label(reminders.isSet(for: programme) ? "Cancel reminder" : "Set reminder",
                                      systemImage: reminders.isSet(for: programme) ? "bell.slash" : "bell")
                            }
                        }
                        Button { onInfo(programme) } label: { Label("Programme info", systemImage: "info.circle") }
                        Button {
                            store.toggleFavourite(channel)
                        } label: {
                            Label(store.isFavourite(channel) ? "Remove \(channel.name) from favourites"
                                                             : "Add \(channel.name) to favourites",
                                  systemImage: store.isFavourite(channel) ? "heart.slash" : "heart")
                        }
                        Button { store.jumpToNow() } label: { Label("Back to now", systemImage: "clock") }
                    }
                }
            }
            .frame(width: gridWidth, height: Theme.rowHeight, alignment: .leading)
            .overlay(alignment: .topLeading) { timeOverlay }
        }
    }

    // MARK: Layout

    private func width(of programme: Programme) -> CGFloat {
        let start = max(programme.start, store.windowStart)
        let end = min(programme.end, store.windowEnd)
        return max(0, CGFloat(end.timeIntervalSince(start) / GuideStore.windowSpan) * gridWidth)
    }

    /// Dims the part of the window that is already in the past and draws the "now" line.
    @ViewBuilder
    private var timeOverlay: some View {
        let offset = store.now.timeIntervalSince(store.windowStart)
        if offset > 0, offset < GuideStore.windowSpan {
            let x = CGFloat(offset / GuideStore.windowSpan) * gridWidth
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .frame(width: x, height: Theme.rowHeight)
                Rectangle()
                    .fill(Theme.live)
                    .frame(width: 3, height: Theme.rowHeight + Theme.rowSpacing)
                    .shadow(color: Theme.live.opacity(0.6), radius: 6)
                    .offset(x: x - 1.5)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: Timeline paging

    /// Pressing right on the last cell (or left on the first) pages the
    /// window by 30 minutes, then moves focus to the newly revealed listing.
    private func handleMove(_ direction: MoveCommandDirection, from programme: Programme,
                            isFirst: Bool, isLast: Bool) {
        switch direction {
        case .right where isLast:
            let wasFullyVisible = programme.end <= store.windowEnd
            let moved = withAnimation(.easeInOut(duration: 0.25)) { store.shiftWindow(slots: 1) }
            guard moved, wasFullyVisible else { return }
            if let next = store.segments(for: channel).first(where: { $0.start >= programme.end }) {
                DispatchQueue.main.async { focusedCell.wrappedValue = next.id }
            }
        case .left where isFirst:
            let wasFullyVisible = programme.start >= store.windowStart
            let moved = withAnimation(.easeInOut(duration: 0.25)) { store.shiftWindow(slots: -1) }
            guard moved, wasFullyVisible else { return }
            if let previous = store.segments(for: channel).last(where: { $0.end <= programme.start }) {
                DispatchQueue.main.async { focusedCell.wrappedValue = previous.id }
            }
        default:
            break
        }
    }
}

/// Channel number, logo and name at the start of each row.
private struct ChannelCell: View {
    let channel: Channel
    let isFavourite: Bool

    var body: some View {
        HStack(spacing: 14) {
            ChannelLogo(channel: channel, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(channel.displayNumber)")
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                Text(channel.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isFavourite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: Theme.channelColumnWidth, height: Theme.rowHeight)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProgrammeCellLabel: View {
    let programme: Programme
    let continuesBefore: Bool
    let continuesAfter: Bool
    let hasReminder: Bool
    let width: CGFloat

    var body: some View {
        if width > 34 {
            HStack(spacing: 6) {
                if continuesBefore {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).opacity(0.7)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(programme.title)
                        .font(.system(size: 24, weight: programme.isPlaceholder ? .regular : .semibold))
                        .italic(programme.isPlaceholder)
                        .lineLimit(1)
                    if width > 190, !programme.isPlaceholder {
                        Text(Fmt.range(programme))
                            .font(.system(size: 18, weight: .medium))
                            .monospacedDigit()
                            .opacity(0.65)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if hasReminder, width > 90 {
                    Image(systemName: "bell.fill").font(.system(size: 16, weight: .bold))
                }
                if programme.isNew, width > 280 {
                    Text("NEW")
                        .font(.system(size: 14, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.9), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(Theme.ink)
                }
                if continuesAfter {
                    Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).opacity(0.7)
                }
            }
            .padding(.horizontal, 14)
        } else {
            Color.clear
        }
    }
}

/// Classic Sky cell: blue at rest, solid Sky yellow when focused.
private struct ProgrammeCellStyle: ButtonStyle {
    let isOnNow: Bool
    let isPlaceholder: Bool

    func makeBody(configuration: Configuration) -> some View {
        CellBody(configuration: configuration, isOnNow: isOnNow, isPlaceholder: isPlaceholder)
    }

    private struct CellBody: View {
        let configuration: ButtonStyleConfiguration
        let isOnNow: Bool
        let isPlaceholder: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .foregroundStyle(isFocused ? Theme.ink : .white.opacity(isPlaceholder ? 0.5 : 0.95))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(fill)
                        .shadow(color: .black.opacity(isFocused ? 0.4 : 0), radius: 16, y: 8)
                }
                .padding(.horizontal, 3)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .zIndex(isFocused ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: isFocused)
        }

        private var fill: Color {
            if isFocused { return Theme.accent }
            if isOnNow { return Theme.cellNow }
            return isPlaceholder ? .white.opacity(0.04) : Theme.cell
        }
    }
}
