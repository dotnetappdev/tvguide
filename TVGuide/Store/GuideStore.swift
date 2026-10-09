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

    /// Channel currently being watched full screen (Sky style "tuned" channel).
    var tunedChannelID: String?
    /// M3U playlist providing live streams, e.g. from Channels DVR or Jellyfin.
    private(set) var liveSourceURL: URL?
    private(set) var liveSourceStatus: String?
    private(set) var streams: [String: URL] = [:]
    private var playlist: M3UPlaylist?

    /// "I have Sky / NOW": adds Sky Cinema, Sky Sports and Sky entertainment channels.
    private(set) var includesSkyChannels: Bool
    private let service: EPGService
    private let skyService = SkyEPGService()
    private var skyChannels: [Channel] = []
    private var skySchedules: [String: [Programme]] = [:]
    private let defaults: UserDefaults
    private var clockTask: Task<Void, Never>?
    private var logos: [String: URL] = [:]

    init(service: EPGService = EPGService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        self.region = Region.with(id: defaults.string(forKey: Keys.region))
        self.favourites = Set(defaults.stringArray(forKey: Keys.favourites) ?? [])
        self.includesSkyChannels = defaults.bool(forKey: Keys.sky)
        self.windowStart = SampleSchedule.alignedDown(Date(), minutes: 30)
        self.channels = ChannelLineup.channels(for: region)
        self.liveSourceURL = defaults.string(forKey: Keys.liveSource).flatMap(URL.init(string:))
    }

    // MARK: Loading

    func start() async {
        startClock()
        async let listings: Void = load()
        async let live: Void = loadLiveSource()
        _ = await (listings, live)
    }

    func load(forceRefresh: Bool = false) async {
        if schedules.isEmpty { state = .loading }
        let ids = Set(ChannelLineup.channels(for: region).map(\.id))
        if includesSkyChannels { await loadSky() }
        do {
            apply(try await service.load(channelIDs: ids, forceRefresh: forceRefresh))
        } catch {
            if schedules.isEmpty || state == .ready(.sample) {
                schedules = SampleSchedule.make(for: ChannelLineup.channels(for: region), around: now)
                    .merging(skySchedules) { a, _ in a }
                state = .ready(.sample)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func apply(_ snapshot: EPGSnapshot) {
        logos = snapshot.logos
        schedules = snapshot.programmes.merging(skySchedules) { a, _ in a }
        applyLogos()
        state = .ready(snapshot.source)
    }

    func setRegion(_ region: Region) async {
        guard region != self.region else { return }
        self.region = region
        defaults.set(region.id, forKey: Keys.region)
        rebuildChannels()
        await load()
    }

    func setIncludesSkyChannels(_ enabled: Bool) async {
        guard enabled != includesSkyChannels else { return }
        includesSkyChannels = enabled
        defaults.set(enabled, forKey: Keys.sky)
        if enabled {
            await loadSky()
        } else {
            skyChannels = []
            for key in skySchedules.keys { schedules[key] = nil }
            skySchedules = [:]
            rebuildChannels()
        }
    }

    private func loadSky() async {
        let used = Set(ChannelLineup.channels(for: region).map(\.number))
        guard let result = try? await skyService.load(excludingNumbers: used, around: now) else { return }
        skyChannels = result.channels
        skySchedules = result.programmes
        schedules.merge(result.programmes) { _, new in new }
        rebuildChannels()
    }

    /// Free-to-air line-up for the region plus any Sky channels, in number order.
    private func rebuildChannels() {
        channels = (ChannelLineup.channels(for: region) + skyChannels).sorted { $0.number < $1.number }
        applyLogos()
        streams = playlist?.streams(for: channels) ?? [:]
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

    // MARK: Live TV

    func setLiveSource(_ string: String) async {
        let trimmed = string.trimmed
        liveSourceURL = trimmed.isEmpty ? nil : URL(string: trimmed)
        defaults.set(liveSourceURL?.absoluteString, forKey: Keys.liveSource)
        await loadLiveSource()
    }

    func loadLiveSource() async {
        guard let url = liveSourceURL else {
            playlist = nil
            streams = [:]
            liveSourceStatus = nil
            return
        }
        do {
            let playlist = try await M3UPlaylist.load(from: url)
            self.playlist = playlist
            streams = playlist.streams(for: channels)
            liveSourceStatus = "\(streams.count) of \(channels.count) channels available"
        } catch {
            liveSourceStatus = "Couldn't load playlist: \(error.localizedDescription)"
        }
    }

    func stream(for channel: Channel) -> URL? { streams[channel.id] }

    var tunedChannel: Channel? { tunedChannelID.flatMap(channel(id:)) }

    func tune(_ channel: Channel) { tunedChannelID = channel.id }

    /// Tunes to a channel by its number, Sky style. Returns `false` if no channel has that number.
    @discardableResult
    func tune(number: Int) -> Bool {
        guard let channel = channels.first(where: { $0.number == number }) else { return false }
        tune(channel)
        return true
    }

    /// Channel up / down, wrapping around the full line-up.
    func channel(after channel: Channel, offset: Int) -> Channel? {
        guard !channels.isEmpty, let index = channels.firstIndex(where: { $0.id == channel.id }) else { return nil }
        let next = (index + offset % channels.count + channels.count) % channels.count
        return channels[next]
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

    // MARK: Search

    struct SearchResults {
        var channels: [Channel] = []
        var onNow: [Programme] = []
        var later: [Programme] = []
        var isEmpty: Bool { channels.isEmpty && onNow.isEmpty && later.isEmpty }
    }

    /// Finds channels by name or number and programmes by title (words in any
    /// order, ignoring case and accents). Past programmes are left out.
    func search(_ query: String, limit: Int = 60) -> SearchResults {
        let terms = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return SearchResults() }
        func matches(_ text: String) -> Bool {
            let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return terms.allSatisfy { folded.contains($0) }
        }

        var results = SearchResults()
        results.channels = channels.filter { matches($0.name) || String($0.number) == query.trimmed }
        var seen = Set<String>()
        for channel in channels {
            for programme in schedules[channel.id] ?? [] where programme.end > now && matches(programme.title) {
                guard seen.insert(programme.id).inserted else { continue }
                if programme.isOn(at: now) { results.onNow.append(programme) } else { results.later.append(programme) }
            }
        }
        results.onNow.sort { (channel(id: $0.channelID)?.number ?? 0) < (channel(id: $1.channelID)?.number ?? 0) }
        results.later.sort { $0.start < $1.start }
        results.later = Array(results.later.prefix(limit))
        return results
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
        static let liveSource = "guide.liveSource"
        static let sky = "guide.includesSky"
    }
}
