import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Station details from Rayo (formerly Bauer Media: Absolute Radio, KISS,
/// Magic, Greatest Hits Radio, Hits Radio, Cool FM, Clyde 1 …) via the station
/// list its own apps use. Gives each station's current stream, logo, brand
/// colour, the show on air and the song playing now.
///
/// It isn't a documented public API, so it may change. Rayo's streams only
/// play in the UK.
actor RayoService {
    static let base = URL(string: "https://listenapi.planetradio.co.uk/api9.2/")!

    struct Station {
        let code: String
        let streams: [URL]
        let logo: URL?
        let colourHex: String?
        let strapline: String?
        let onAir: Programme?
        let nowPlaying: String?
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Details for `codes`: one request for Rayo's main stations, then one per
    /// regional station (Rayo only returns those when asked individually).
    func stations(codes: Set<String>, channelIDs: [String: String]) async -> [String: Station] {
        var result: [String: Station] = [:]
        if let main = try? await fetch(query: nil) {
            for raw in main where codes.contains(raw.stationCode) {
                result[raw.stationCode] = Self.station(raw, channelID: channelIDs[raw.stationCode])
            }
        }
        let missing = codes.subtracting(result.keys)
        await withTaskGroup(of: (String, Station?).self) { group in
            for code in missing {
                group.addTask {
                    let raw = try? await self.fetch(query: code)?.first { $0.stationCode == code }
                    return (code, raw.map { Self.station($0, channelID: channelIDs[code]) })
                }
            }
            for await (code, station) in group {
                if let station { result[code] = station }
            }
        }
        return result
    }

    /// The song playing now on one station, e.g. "Tom Petty – I Won't Back Down".
    func nowPlaying(code: String) async -> String? {
        guard let raw = try? await fetch(query: code)?.first(where: { $0.stationCode == code }) else { return nil }
        return Self.track(raw.stationNowPlaying)
    }

    private func fetch(query code: String?) async throws -> [RawStation]? {
        var components = URLComponents(url: Self.base.appendingPathComponent("stations/GB"), resolvingAgainstBaseURL: false)!
        if let code { components.queryItems = [URLQueryItem(name: "StationCode[]", value: code)] }
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode([Lenient<RawStation>].self, from: data).compactMap(\.value)
    }

    // MARK: Mapping

    static func station(_ raw: RawStation, channelID: String?) -> Station {
        let free = (raw.stationStreams ?? []).filter { $0.streamPremium != true && $0.streamUsersOnly != true }
        // HLS first (Apple's native format), then AAC/MP3 Icecast streams.
        let ordered = free.filter { $0.streamType == "hls" } + free.filter { $0.streamType != "hls" }
        var onAir: Programme?
        if let show = raw.stationOnAir, let channelID, let title = show.episodeTitle?.nilIfEmpty,
           let start = show.episodeStart.flatMap(ukDate), let duration = show.episodeDuration, duration > 0 {
            onAir = Programme(channelID: channelID, title: title, synopsis: show.episodeDescription?.nilIfEmpty,
                              start: start, end: start.addingTimeInterval(duration),
                              imageURL: show.episodeImageUrl.flatMap(URL.init(string:)))
        }
        return Station(code: raw.stationCode,
                       streams: ordered.compactMap { URL(string: $0.streamUrl) },
                       logo: raw.stationListenBarLogo.flatMap(URL.init(string:)),
                       colourHex: raw.stationBrandColour.map { $0.replacingOccurrences(of: "#", with: "") },
                       strapline: raw.stationStrapline?.nilIfEmpty,
                       onAir: onAir,
                       nowPlaying: track(raw.stationNowPlaying))
    }

    static func track(_ now: RawStation.NowPlaying?) -> String? {
        guard let title = now?.nowPlayingTrack?.nilIfEmpty else { return nil }
        if let artist = now?.nowPlayingArtist?.nilIfEmpty { return "\(artist) – \(title)" }
        return title
    }

    /// Rayo times are UK local time, e.g. "2026-10-09 16:00:00".
    static func ukDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: string)
    }

    // MARK: JSON

    struct RawStation: Decodable {
        struct Stream: Decodable {
            let streamUrl: String
            let streamType: String?
            let streamPremium: Bool?
            let streamUsersOnly: Bool?
        }
        struct OnAir: Decodable {
            let episodeTitle: String?
            let episodeDescription: String?
            let episodeStart: String?
            let episodeDuration: Double?
            let episodeImageUrl: String?
        }
        struct NowPlaying: Decodable {
            let nowPlayingTrack: String?
            let nowPlayingArtist: String?
        }

        let stationCode: String
        let stationName: String?
        let stationListenBarLogo: String?
        let stationBrandColour: String?
        let stationStrapline: String?
        let stationStreams: [Stream]?
        let stationOnAir: OnAir?
        let stationNowPlaying: NowPlaying?

        enum CodingKeys: String, CodingKey {
            case stationCode, stationName, stationListenBarLogo, stationBrandColour, stationStrapline,
                 stationStreams, stationOnAir, stationNowPlaying
        }

        // Lenient: an odd value in one field (e.g. an empty array for "nothing on air")
        // shouldn't lose the whole station.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            stationCode = try c.decode(String.self, forKey: .stationCode)
            stationName = try? c.decodeIfPresent(String.self, forKey: .stationName)
            stationListenBarLogo = try? c.decodeIfPresent(String.self, forKey: .stationListenBarLogo)
            stationBrandColour = try? c.decodeIfPresent(String.self, forKey: .stationBrandColour)
            stationStrapline = try? c.decodeIfPresent(String.self, forKey: .stationStrapline)
            stationStreams = (try? c.decodeIfPresent([Lenient<Stream>].self, forKey: .stationStreams))?.compactMap(\.value)
            stationOnAir = try? c.decodeIfPresent(OnAir.self, forKey: .stationOnAir)
            stationNowPlaying = try? c.decodeIfPresent(NowPlaying.self, forKey: .stationNowPlaying)
        }
    }

    /// Decodes an element if it can, otherwise `nil`, so one bad entry doesn't fail a whole list.
    struct Lenient<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
    }
}
