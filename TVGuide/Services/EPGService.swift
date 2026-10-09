import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Where the listings currently on screen came from.
enum EPGSource: Equatable {
    case live(updated: Date)
    case cached(updated: Date)
    case sample
}

struct EPGSnapshot {
    var programmes: [String: [Programme]]
    var logos: [String: URL]
    var source: EPGSource
}

enum EPGError: LocalizedError {
    case unavailable(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .unavailable(let error):
            "TV listings are unavailable right now." + (error.map { " (\($0.localizedDescription))" } ?? "")
        }
    }
}

/// Downloads and caches the UK Freeview XMLTV feed.
///
/// The feed is a community maintained, 7-day XMLTV export of the Freeview EPG
/// (https://github.com/dp247/Freeview-EPG). It is cached on disk and refreshed
/// at most every `maxAge` seconds.
actor EPGService {
    static let feedURL = URL(string: "https://raw.githubusercontent.com/dp247/Freeview-EPG/master/epg.xml")!

    private let session: URLSession
    private let cacheURL: URL
    private let maxAge: TimeInterval

    init(session: URLSession = .shared, maxAge: TimeInterval = 4 * 3600) {
        self.session = session
        self.maxAge = maxAge
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.cacheURL = caches.appendingPathComponent("freeview-epg.xml")
    }

    /// Loads listings for `channelIDs`, using the disk cache when it is fresh.
    func load(channelIDs: Set<String>, forceRefresh: Bool = false) async throws -> EPGSnapshot {
        let cachedAt = cacheDate()
        let isFresh = cachedAt.map { Date().timeIntervalSince($0) < maxAge } ?? false

        if !forceRefresh, isFresh, let cachedAt, let doc = parseCache(channelIDs) {
            return EPGSnapshot(programmes: doc.programmes, logos: doc.logos, source: .cached(updated: cachedAt))
        }

        do {
            try await download()
            if let doc = parseCache(channelIDs) {
                return EPGSnapshot(programmes: doc.programmes, logos: doc.logos, source: .live(updated: Date()))
            }
            throw EPGError.unavailable(underlying: nil)
        } catch {
            // Fall back to stale listings rather than an empty guide.
            if let cachedAt, let doc = parseCache(channelIDs), !doc.programmes.isEmpty {
                return EPGSnapshot(programmes: doc.programmes, logos: doc.logos, source: .cached(updated: cachedAt))
            }
            throw EPGError.unavailable(underlying: error)
        }
    }

    private func download() async throws {
        var request = URLRequest(url: Self.feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard data.count > 1024 else { throw URLError(.zeroByteResource) }
        try data.write(to: cacheURL, options: .atomic)
    }

    private func parseCache(_ channelIDs: Set<String>) -> XMLTVDocument? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        return XMLTVParser.parse(contentsOf: cacheURL, channelIDs: channelIDs)
    }

    private func cacheDate() -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: cacheURL.path)
        return attributes?[.modificationDate] as? Date
    }
}
