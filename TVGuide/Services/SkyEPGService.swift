import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Listings for Sky's pay channels (Sky Cinema, Sky Sports, TNT Sports and the
/// Sky entertainment channels) from the JSON guide behind sky.com/tv-guide.
///
/// This is the same unauthenticated feed Sky's website uses; it isn't a
/// documented public API, so it may change without notice.
actor SkyEPGService {
    static let base = URL(string: "https://awk.epgsky.com/hawk/linear/")!
    /// Sky's London HD bouquet; national channels are the same everywhere.
    static let bouquet = "4101/1"

    private let session: URLSession
    private var cachedServices: [SkyService]?

    init(session: URLSession = .shared) {
        self.session = session
    }

    struct SkyService: Decodable {
        let sid: String
        let c: String
        let t: String
        let sg: Int?
    }

    private struct ServicesResponse: Decodable { let services: [SkyService] }

    private struct ScheduleResponse: Decodable {
        struct Day: Decodable { let sid: String; let events: [Event] }
        struct Event: Decodable {
            let st: TimeInterval
            let d: TimeInterval
            let t: String
            let sy: String?
            let programmeuuid: String?
            let seasonnumber: Int?
            let episodenumber: Int?
            let new: Bool?
        }
        let schedule: [Day]
    }

    /// Loads Sky pay channels whose numbers aren't already used, plus two days of listings.
    func load(excludingNumbers used: Set<Int>, around date: Date = Date()) async throws -> (channels: [Channel], programmes: [String: [Programme]]) {
        let services = try await services()
        let channels = Self.payChannels(from: services, excluding: used)
        guard !channels.isEmpty else { return ([], [:]) }

        var programmes: [String: [Programme]] = [:]
        let sids = channels.map { String($0.id.dropFirst(4)) }
        for day in Self.dayStrings(around: date) {
            for chunk in stride(from: 0, to: sids.count, by: 20).map({ Array(sids[$0..<min($0 + 20, sids.count)]) }) {
                let url = Self.base.appendingPathComponent("schedule/\(day)/\(chunk.joined(separator: ","))")
                let (data, _) = try await session.data(from: url)
                let response = try JSONDecoder().decode(ScheduleResponse.self, from: data)
                for entry in response.schedule {
                    let id = "sky:\(entry.sid)"
                    programmes[id, default: []] += entry.events.map { Self.programme($0, channelID: id) }
                }
            }
        }
        for key in programmes.keys {
            var seen = Set<Date>()
            programmes[key] = programmes[key]!.sorted { $0.start < $1.start }.filter { seen.insert($0.start).inserted }
        }
        return (channels, programmes)
    }

    private func services() async throws -> [SkyService] {
        if let cachedServices { return cachedServices }
        let url = Self.base.appendingPathComponent("services/\(Self.bouquet)")
        let (data, _) = try await session.data(from: url)
        let services = try JSONDecoder().decode(ServicesResponse.self, from: data).services
        cachedServices = services
        return services
    }

    // MARK: Mapping (static so it can be unit tested)

    static func payChannels(from services: [SkyService], excluding used: Set<Int>) -> [Channel] {
        var numbers = used
        var result: [Channel] = []
        for service in services {
            guard let number = Int(service.c), !numbers.contains(number) else { continue }
            if service.t.contains("+1") || service.t.contains("BoxOff") { continue }
            let name = prettyName(service.t, number: number)
            let category: ChannelCategory
            switch number {
            case 106...199 where name.hasPrefix("Sky"):
                category = ["History", "Nature", "Documentaries"].contains(where: name.contains) ? .factual : .entertainment
            case 301...312 where service.sg == 6:
                category = .films
            case 401...416:
                category = .sport
            default:
                continue
            }
            numbers.insert(number)
            result.append(Channel(number, name, id: "sky:\(service.sid)", category,
                                  hd: service.t.hasSuffix("HD"), brand: brand(for: category)))
        }
        return result
    }

    /// Expands Sky's abbreviated names, e.g. "SkySpMainEvHD" → "Sky Sports Main Event".
    static func prettyName(_ raw: String, number: Int) -> String {
        var name = raw
        if name.hasSuffix("HD") { name = String(name.dropLast(2)) }
        name = name.trimmed
        let replacements: [(String, String)] = [
            ("SkySp", "Sky Sports "), ("MainEv", "Main Event"), ("F'ball", "Football"), ("PL", "Premier League"),
            ("TNTSports", "TNT Sports "), ("SkyPremiere", "Sky Cinema Premiere"), ("SkyAnimation", "Sky Cinema Animation"),
            ("SkyDocmntrs", "Sky Documentaries"), ("Disney+Cine", "Disney+ Cinema"),
        ]
        for (from, to) in replacements { name = name.replacingOccurrences(of: from, with: to) }
        name = name.replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: "Sports +", with: "Sports+").trimmed
        // Sky Cinema channels are listed as "Sky Action", "Sky Greats" … in the 3xx range.
        if (301...312).contains(number), name.hasPrefix("Sky "), !name.hasPrefix("Sky Cinema") {
            name = "Sky Cinema " + name.dropFirst(4)
        } else if (301...312).contains(number), !name.hasPrefix("Sky"), !name.contains("Disney") {
            name = "Sky Cinema " + name
        }
        return name
    }

    private static func brand(for category: ChannelCategory) -> String {
        switch category {
        case .sport: "C8102E"
        case .films: "5B2D8E"
        default: "0A6CFF"
        }
    }

    private static func programme(_ event: ScheduleResponse.Event, channelID: String) -> Programme {
        let start = Date(timeIntervalSince1970: event.st)
        let episode: String? = switch (event.seasonnumber, event.episodenumber) {
        case let (s?, e?) where s < 1900: "S\(s) E\(e)"
        case let (_, e?): "Ep \(e)"
        default: nil
        }
        return Programme(channelID: channelID, title: event.t, synopsis: event.sy?.nilIfEmpty,
                         start: start, end: start.addingTimeInterval(event.d),
                         imageURL: event.programmeuuid.flatMap {
                             URL(string: "https://images.metadata.sky.com/pd-image/\($0)/16-9/640")
                         },
                         episode: episode, isNew: event.new ?? false)
    }

    /// Today and tomorrow in UK time, as `yyyyMMdd`.
    static func dayStrings(around date: Date) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return [0, 1].compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { return nil }
            let c = calendar.dateComponents([.year, .month, .day], from: day)
            return String(format: "%04d%02d%02d", c.year!, c.month!, c.day!)
        }
    }
}
