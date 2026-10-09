import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
    /// Channels DVR server used for live TV and as a backup guide from the aerial.
    private(set) var channelsServer: URL?
    private var tunerSchedules: [String: [Programme]] = [:]
    private var internetSchedules: [String: [Programme]] = [:]

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
        // Sky channels are on unless the viewer has switched them off.
        self.includesSkyChannels = defaults.object(forKey: Keys.sky) as? Bool ?? true
        self.windowStart = SampleSchedule.alignedDown(Date(), minutes: 30)
        self.channels = ChannelLineup.channels(for: region)
        self.liveSourceURL = defaults.string(forKey: Keys.liveSource).flatMap(URL.init(string:))
        self.channelsServer = defaults.string(forKey: Keys.channelsServer).flatMap(URL.init(string:))
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
        // Sky listings download alongside the Freeview feed.
        async let sky: Void = loadSkyIfEnabled()
        do {
            apply(try await service.load(channelIDs: ids, forceRefresh: forceRefresh))
        } catch {
            if !tunerSchedules.isEmpty {
                // No internet listings: the tuner's guide from the aerial covers the free channels.
                internetSchedules = [:]
                assembleSchedules()
                state = .ready(.tuner)
            } else if internetSchedules.isEmpty || state == .ready(.sample) {
                internetSchedules = SampleSchedule.make(for: ChannelLineup.channels(for: region), around: now)
                assembleSchedules()
                state = .ready(.sample)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
        await sky
    }

    func apply(_ snapshot: EPGSnapshot) {
        logos = snapshot.logos
        internetSchedules = snapshot.programmes
        assembleSchedules()
        applyLogos()
        state = .ready(snapshot.source)
    }

    /// Internet listings first, then Sky's, then the tuner's guide for any
    /// channel still without listings.
    private func assembleSchedules() {
        var merged = internetSchedules.merging(skySchedules) { a, _ in a }
        for (id, listings) in tunerSchedules where merged[id]?.isEmpty ?? true {
            merged[id] = listings
        }
        schedules = merged
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
            skySchedules = [:]
            assembleSchedules()
            rebuildChannels()
        }
    }

    private func loadSkyIfEnabled() async {
        if includesSkyChannels { await loadSky() }
    }

    private func loadSky() async {
        let used = Set(ChannelLineup.channels(for: region).map(\.number))
        guard let result = try? await skyService.load(excludingNumbers: used, around: now) else { return }
        skyChannels = result.channels
        skySchedules = result.programmes
        assembleSchedules()
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

    /// Uses a Channels DVR server for live TV: its HLS playlist for streams and
    /// its guide (read from the aerial) as backup listings. Pass `nil` to remove.
    func setChannelsServer(_ server: URL?) async throws {
        if let server {
            try await ChannelsDVRClient(server: server).checkReachable()
        }
        channelsServer = server
        defaults.set(server?.absoluteString, forKey: Keys.channelsServer)
        liveSourceURL = server.map { ChannelsDVRClient(server: $0).playlistURL }
        defaults.set(liveSourceURL?.absoluteString, forKey: Keys.liveSource)
        if server == nil { tunerSchedules = [:]; assembleSchedules() }
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
            liveSourceStatus = "\(streams.count) of \(channels.count) channels can play live"
        } catch {
            liveSourceStatus = "Couldn't reach your live TV source: \(error.localizedDescription)"
        }
        await loadTunerGuide()
    }

    /// Backup listings from the tuner: Channels DVR's guide, or the XMLTV guide
    /// a playlist advertises in its header.
    private func loadTunerGuide() async {
        var listings: [String: [Programme]] = [:]
        if let server = channelsServer,
           let guide = try? await ChannelsDVRClient(server: server).guide(from: now.addingTimeInterval(-3600),
                                                                          duration: 24 * 3600) {
            listings = ChannelsDVRClient.programmes(from: guide, matching: channels)
        } else if let guideURL = playlist?.guideURL,
                  let (data, _) = try? await URLSession.shared.data(from: guideURL) {
            listings = XMLTVParser.parseMatchingNames(data: data, channels: channels)
        }
        tunerSchedules = listings
        if !listings.isEmpty, state == .ready(.sample) {
            // Real listings from the aerial beat generated sample ones.
            internetSchedules = [:]
            state = .ready(.tuner)
        }
        assembleSchedules()
        if !listings.isEmpty, let status = liveSourceStatus {
            liveSourceStatus = status + " · guide for \(listings.count) channels from your tuner"
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
        static let channelsServer = "guide.channelsServer"
    }
}
