import Foundation
import Observation

/// Single source of truth for the guide: channel line-up, listings, the
/// visible timeline window and user preferences.
@MainActor
@Observable
final class GuideStore {
    enum LoadState: Equatable {
        case loading
        case ready(EPGSource)
        case failed(String)
    }

    /// Width of the visible timeline, matching the Sky Q style 2 hour view.
    static let windowSpan: TimeInterval = 2 * 3600
    /// Step used when paging the timeline left or right.
    static let slot: TimeInterval = 30 * 60

    // MARK: State

    private(set) var region: Region
    private(set) var channels: [Channel] = []
    private(set) var schedules: [String: [Programme]] = [:]
    private(set) var state: LoadState = .loading
    private(set) var now = Date()
    private(set) var favourites: Set<String>
    var category: ChannelCategory = .all
    private(set) var windowStart: Date

    private let service: EPGService
    private let defaults: UserDefaults
    private var clockTask: Task<Void, Never>?
    private var logos: [String: URL] = [:]

    init(service: EPGService = EPGService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        self.region = Region.with(id: defaults.string(forKey: Keys.region))
        self.favourites = Set(defaults.stringArray(forKey: Keys.favourites) ?? [])
        self.windowStart = SampleSchedule.alignedDown(Date(), minutes: 30)
        self.channels = ChannelLineup.channels(for: region)
    }

    // MARK: Loading

    func start() async {
        startClock()
        await load()
    }

    func load(forceRefresh: Bool = false) async {
        if schedules.isEmpty { state = .loading }
        let ids = Set(channels.map(\.id))
        do {
            apply(try await service.load(channelIDs: ids, forceRefresh: forceRefresh))
        } catch {
            if schedules.isEmpty || state == .ready(.sample) {
                schedules = SampleSchedule.make(for: channels, around: now)
                state = .ready(.sample)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func apply(_ snapshot: EPGSnapshot) {
        logos = snapshot.logos
        schedules = snapshot.programmes
        applyLogos()
        state = .ready(snapshot.source)
    }

    func setRegion(_ region: Region) async {
        guard region != self.region else { return }
        self.region = region
        defaults.set(region.id, forKey: Keys.region)
        channels = ChannelLineup.channels(for: region)
        applyLogos()
        await load()
    }

    private func applyLogos() {
        channels = channels.map { channel in
            var channel = channel
            channel.logoURL = logos[channel.id]
            return channel
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { return }
                self.tick(Date())
            }
        }
    }

    func tick(_ date: Date) {
        let previousEarliest = earliestWindowStart
        now = date
        // Keep the window pinned to "now" if the user hasn't scrolled away.
        if windowStart == previousEarliest { windowStart = earliestWindowStart }
        if windowStart < earliestWindowStart { windowStart = earliestWindowStart }
    }

    // MARK: Channels

    var visibleChannels: [Channel] {
        switch category {
        case .all: channels
        case .favourites: channels.filter { favourites.contains($0.id) }
        default: channels.filter { $0.category == category }
        }
    }

    func channel(id: String) -> Channel? { channels.first { $0.id == id } }

    func isFavourite(_ channel: Channel) -> Bool { favourites.contains(channel.id) }

    func toggleFavourite(_ channel: Channel) {
        if favourites.contains(channel.id) { favourites.remove(channel.id) } else { favourites.insert(channel.id) }
        defaults.set(Array(favourites), forKey: Keys.favourites)
    }

    // MARK: Listings

    func current(on channel: Channel) -> Programme? {
        schedules[channel.id]?.first { $0.isOn(at: now) }
    }

    func next(on channel: Channel) -> Programme? {
        schedules[channel.id]?.first { $0.start >= now }
    }

    /// Programmes after `programme` on the same channel.
    func upcoming(after programme: Programme, limit: Int = 5) -> [Programme] {
        guard let list = schedules[programme.channelID] else { return [] }
        return Array(list.filter { $0.start >= programme.end }.prefix(limit))
    }

    // MARK: Timeline window

    var windowEnd: Date { windowStart.addingTimeInterval(Self.windowSpan) }

    var earliestWindowStart: Date { SampleSchedule.alignedDown(now, minutes: 30) }

    var latestWindowStart: Date {
        let lastEnd = schedules.values.compactMap { $0.last?.end }.max() ?? now.addingTimeInterval(86_400)
        return max(earliestWindowStart, SampleSchedule.alignedDown(lastEnd.addingTimeInterval(-Self.windowSpan), minutes: 30))
    }

    var isAtNow: Bool { windowStart <= earliestWindowStart }

    /// Moves the window by whole 30 minute slots. Returns `true` if it moved.
    @discardableResult
    func shiftWindow(slots: Int) -> Bool {
        let target = windowStart.addingTimeInterval(Double(slots) * Self.slot)
        let clamped = min(max(target, earliestWindowStart), latestWindowStart)
        guard clamped != windowStart else { return false }
        windowStart = clamped
        return true
    }

    func jump(to date: Date) {
        let aligned = SampleSchedule.alignedDown(date, minutes: 30)
        windowStart = min(max(aligned, earliestWindowStart), latestWindowStart)
    }

    func jumpToNow() { windowStart = earliestWindowStart }

    /// The listings shown in a grid row for the current window, with any holes
    /// in the data filled by placeholder cells so every slot can take focus.
    func segments(for channel: Channel) -> [Programme] {
        let start = windowStart, end = windowEnd
        let listings = (schedules[channel.id] ?? []).filter { $0.overlaps(start, end) }

        var result: [Programme] = []
        var cursor = start
        var holeStart: Date? = nil // `nil` means the hole began before the window
        for programme in listings {
            if programme.start > cursor {
                result += placeholders(channel.id, from: holeStart, visible: cursor, to: programme.start)
            }
            result.append(programme)
            cursor = max(cursor, programme.end)
            holeStart = cursor
        }
        if cursor < end {
            result += placeholders(channel.id, from: holeStart, visible: cursor, to: end)
        }
        return result
    }

    /// Splits a hole into placeholder cells on the absolute 30 minute grid so
    /// their ids stay stable as the window pages (keeping focus intact).
    private func placeholders(_ channelID: String, from holeStart: Date?, visible: Date, to end: Date) -> [Programme] {
        var cells: [Programme] = []
        var slotStart = SampleSchedule.alignedDown(visible, minutes: 30)
        while slotStart < end {
            let slotEnd = slotStart.addingTimeInterval(Self.slot)
            let cellStart = max(slotStart, holeStart ?? slotStart)
            let cellEnd = min(slotEnd, end)
            if cellEnd > max(cellStart, visible) {
                cells.append(.placeholder(channelID: channelID, start: cellStart, end: cellEnd))
            }
            slotStart = slotEnd
        }
        return cells
    }

    private enum Keys {
        static let region = "guide.region"
        static let favourites = "guide.favourites"
    }
}
