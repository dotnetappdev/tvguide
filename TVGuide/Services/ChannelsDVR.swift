import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A Channels DVR server (https://getchannels.com) on the home network.
///
/// Channels DVR turns a tuner such as an HDHomeRun Freeview box into HLS
/// streams that Apple TV can play, and serves the guide it reads from the
/// aerial. This client uses three of its endpoints:
/// - `/devices/ANY/channels.m3u?format=hls` – channel list with HLS streams
/// - `/devices/ANY/guide?time=…&duration=…` – guide data as JSON
struct ChannelsDVRClient {
    let server: URL
    var session: URLSession = .shared

    static let defaultPort = 8089

    /// Accepts "192.168.1.20", "192.168.1.20:8089" or a full URL.
    static func serverURL(from input: String) -> URL? {
        var text = input.trimmed
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard var components = URLComponents(string: text), components.host?.isEmpty == false else { return nil }
        if components.port == nil { components.port = defaultPort }
        components.path = ""
        components.query = nil
        return components.url
    }

    var playlistURL: URL {
        var components = URLComponents(url: server.appendingPathComponent("devices/ANY/channels.m3u"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "format", value: "hls")]
        return components.url!
    }

    func checkReachable() async throws {
        let request = URLRequest(url: playlistURL, timeoutInterval: 8)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              String(decoding: data.prefix(16), as: UTF8.self).hasPrefix("#EXTM3U") else {
            throw URLError(.cannotConnectToHost)
        }
    }

    /// Guide data for `duration` seconds from `start`, fetched in 8 hour
    /// blocks (the size the Channels apps use).
    func guide(from start: Date, duration: TimeInterval) async throws -> [GuideChannel] {
        var merged: [String: GuideChannel] = [:]
        var order: [String] = []
        var blockStart = start
        let end = start.addingTimeInterval(duration)
        while blockStart < end {
            let block = min(8 * 3600, end.timeIntervalSince(blockStart))
            var components = URLComponents(url: server.appendingPathComponent("devices/ANY/guide"),
                                           resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "time", value: String(Int(blockStart.timeIntervalSince1970))),
                                     URLQueryItem(name: "duration", value: String(Int(block)))]
            let (data, _) = try await session.data(from: components.url!)
            for channel in try Self.decodeGuide(data) {
                let key = channel.channel.number ?? channel.channel.name ?? UUID().uuidString
                if merged[key] == nil { order.append(key); merged[key] = channel }
                else { merged[key]!.airings += channel.airings }
            }
            blockStart = blockStart.addingTimeInterval(block)
        }
        return order.compactMap { merged[$0] }
    }

    // MARK: Guide JSON

    struct GuideChannel: Decodable {
        struct Info: Decodable {
            let number: String?
            let name: String?
            let callSign: String?

            enum CodingKeys: String, CodingKey { case number = "Number", name = "Name", callSign = "CallSign" }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                number = c.flexibleString(.number)
                name = c.flexibleString(.name)
                callSign = c.flexibleString(.callSign)
            }
        }

        struct Airing: Decodable {
            let time: Double?
            let duration: Double?
            let title: String?
            let episodeTitle: String?
            let summary: String?
            let image: String?
            let seasonNumber: Int?
            let episodeNumber: Int?
            let tags: [String]?

            enum CodingKeys: String, CodingKey {
                case time = "Time", duration = "Duration", title = "Title", episodeTitle = "EpisodeTitle",
                     summary = "Summary", image = "Image", seasonNumber = "SeasonNumber",
                     episodeNumber = "EpisodeNumber", tags = "Tags"
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                time = c.flexibleDouble(.time)
                duration = c.flexibleDouble(.duration)
                title = c.flexibleString(.title)
                episodeTitle = c.flexibleString(.episodeTitle)
                summary = c.flexibleString(.summary)
                image = c.flexibleString(.image)
                seasonNumber = c.flexibleDouble(.seasonNumber).map { Int($0) }
                episodeNumber = c.flexibleDouble(.episodeNumber).map { Int($0) }
                tags = try? c.decodeIfPresent([String].self, forKey: .tags)
            }
        }

        let channel: Info
        var airings: [Airing]

        enum CodingKeys: String, CodingKey { case channel = "Channel", airings = "Airings" }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            channel = try c.decode(Info.self, forKey: .channel)
            airings = (try? c.decodeIfPresent([Airing].self, forKey: .airings)) ?? []
        }
    }

    static func decodeGuide(_ data: Data) throws -> [GuideChannel] {
        try JSONDecoder().decode([GuideChannel].self, from: data)
    }

    /// Maps the server's guide onto the app's channels by name.
    static func programmes(from guide: [GuideChannel], matching channels: [Channel]) -> [String: [Programme]] {
        let matcher = ChannelMatcher(channels: channels)
        var result: [String: [Programme]] = [:]
        for entry in guide {
            guard let name = entry.channel.name ?? entry.channel.callSign,
                  let channel = matcher.match(name: name), result[channel.id] == nil else { continue }
            var seen = Set<Date>()
            result[channel.id] = entry.airings.compactMap { airing -> Programme? in
                guard let time = airing.time, let duration = airing.duration, duration > 0 else { return nil }
                let start = Date(timeIntervalSince1970: time)
                guard seen.insert(start).inserted else { return nil }
                let episode: String? = switch (airing.seasonNumber, airing.episodeNumber) {
                case let (s?, e?) where s > 0 && s < 1900: "S\(s) E\(e)"
                case let (_, e?) where e > 0: "Ep \(e)"
                default: nil
                }
                return Programme(channelID: channel.id,
                                 title: airing.title?.nilIfEmpty ?? "Untitled",
                                 subtitle: airing.episodeTitle?.nilIfEmpty,
                                 synopsis: airing.summary?.nilIfEmpty,
                                 start: start, end: start.addingTimeInterval(duration),
                                 imageURL: airing.image.flatMap(URL.init(string:)),
                                 episode: episode,
                                 isNew: airing.tags?.contains("New") ?? false)
            }.sorted { $0.start < $1.start }
        }
        return result
    }
}

private extension KeyedDecodingContainer {
    func flexibleString(_ key: Key) -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) { return string }
        if let int = try? decodeIfPresent(Int.self, forKey: key) { return String(int) }
        if let double = try? decodeIfPresent(Double.self, forKey: key) { return String(double) }
        return nil
    }

    func flexibleDouble(_ key: Key) -> Double? {
        if let double = try? decodeIfPresent(Double.self, forKey: key) { return double }
        if let string = try? decodeIfPresent(String.self, forKey: key) { return Double(string) }
        return nil
    }
}
