import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Result of parsing an XMLTV document.
struct XMLTVDocument {
    var programmes: [String: [Programme]] = [:]
    var logos: [String: URL] = [:]
}

/// Streaming XMLTV parser. Only keeps listings for the requested channel ids,
/// which keeps memory low even though the full UK feed is ~20 MB.
final class XMLTVParser: NSObject, XMLParserDelegate {
    private let wanted: Set<String>
    private var document = XMLTVDocument()

    // Current element state.
    private var text = ""
    private var channelID: String?
    private var inChannel = false
    private var inProgramme = false
    private var start: Date?
    private var stop: Date?
    private var title: String?
    private var subtitle: String?
    private var desc: String?
    private var icon: URL?
    private var onscreenEpisode: String?
    private var nsEpisode: String?
    private var episodeSystem: String?
    private var isNew = false

    init(channelIDs: Set<String>) {
        self.wanted = channelIDs
    }

    static func parse(data: Data, channelIDs: Set<String>) -> XMLTVDocument {
        let delegate = XMLTVParser(channelIDs: channelIDs)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        return delegate.finish()
    }

    static func parse(contentsOf url: URL, channelIDs: Set<String>) -> XMLTVDocument? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let delegate = XMLTVParser(channelIDs: channelIDs)
        parser.delegate = delegate
        _ = parser.parse()
        return delegate.finish()
    }

    private func finish() -> XMLTVDocument {
        for (key, list) in document.programmes {
            // Sort and drop listings that overlap an earlier one so grid rows never collide.
            var cleaned: [Programme] = []
            for programme in list.sorted(by: { $0.start < $1.start }) {
                if let last = cleaned.last, programme.start < last.end { continue }
                cleaned.append(programme)
            }
            document.programmes[key] = cleaned
        }
        return document
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        switch element {
        case "channel":
            channelID = attributes["id"]
            inChannel = channelID.map(wanted.contains) ?? false
        case "programme":
            guard let id = attributes["channel"], wanted.contains(id) else {
                inProgramme = false
                return
            }
            inProgramme = true
            channelID = id
            start = attributes["start"].flatMap(Self.date(from:))
            stop = attributes["stop"].flatMap(Self.date(from:))
            title = nil; subtitle = nil; desc = nil; icon = nil
            onscreenEpisode = nil; nsEpisode = nil; isNew = false
        case "icon":
            let url = attributes["src"].flatMap(URL.init(string:))
            if inProgramme { icon = url } else if inChannel, let id = channelID, let url {
                document.logos[id] = url
            }
        case "episode-num":
            episodeSystem = attributes["system"]
        case "premiere", "new":
            if inProgramme { isNew = true }
        default:
            break
        }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inProgramme { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch element {
        case "channel":
            inChannel = false
        case "title" where inProgramme:
            title = text.trimmed
        case "sub-title" where inProgramme:
            subtitle = text.trimmed
        case "desc" where inProgramme:
            desc = text.trimmed
        case "episode-num" where inProgramme:
            if episodeSystem == "onscreen" { onscreenEpisode = text.trimmed }
            else if episodeSystem == "xmltv_ns" { nsEpisode = text.trimmed }
        case "programme" where inProgramme:
            inProgramme = false
            guard let id = channelID, let start, let stop, stop > start else { return }
            let (fullTitle, synopsis) = Self.rejoinTitle(title?.nilIfEmpty ?? "Untitled", desc?.nilIfEmpty)
            let programme = Programme(
                channelID: id,
                title: fullTitle,
                subtitle: subtitle?.nilIfEmpty,
                synopsis: synopsis,
                start: start,
                end: stop,
                imageURL: icon,
                episode: Self.episodeLabel(onscreen: onscreenEpisode, xmltvNS: nsEpisode),
                isNew: isNew)
            document.programmes[id, default: []].append(programme)
        default:
            break
        }
    }

    // MARK: Helpers

    /// Parses XMLTV timestamps such as `20261008220000 +0100`.
    static func date(from string: String) -> Date? {
        let chars = Array(string.utf8)
        guard chars.count >= 14 else { return nil }
        func number(_ from: Int, _ length: Int) -> Int? {
            var value = 0
            for i in from..<(from + length) {
                let c = chars[i]
                guard c >= 48 && c <= 57 else { return nil }
                value = value * 10 + Int(c - 48)
            }
            return value
        }
        guard let year = number(0, 4), let month = number(4, 2), let day = number(6, 2),
              let hour = number(8, 2), let minute = number(10, 2), let second = number(12, 2)
        else { return nil }

        // Optional "+HHMM" / "-HHMM" offset.
        var offset = 0
        let tail = chars.dropFirst(14).drop { $0 == 32 }
        if tail.count >= 5, let sign = tail.first, sign == 43 || sign == 45 {
            let digits = Array(tail.dropFirst().prefix(4))
            if digits.count == 4, digits.allSatisfy({ $0 >= 48 && $0 <= 57 }) {
                let hh = Int(digits[0] - 48) * 10 + Int(digits[1] - 48)
                let mm = Int(digits[2] - 48) * 10 + Int(digits[3] - 48)
                offset = (hh * 3600 + mm * 60) * (sign == 45 ? -1 : 1)
            }
        }

        let days = daysFromCivil(year: year, month: month, day: day)
        let seconds = days * 86_400 + hour * 3600 + minute * 60 + second - offset
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    /// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's algorithm).
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// Long titles are split across fields in the feed: "George Clarke's Amazing..." with a
    /// description of "...Spaces: First Home: George …". Moves the overflow back into the title.
    static func rejoinTitle(_ title: String, _ desc: String?) -> (String, String?) {
        guard title.hasSuffix("..."), let desc, desc.hasPrefix("..."),
              let colon = desc.range(of: ": ") else { return (title, desc) }
        let overflow = desc[desc.index(desc.startIndex, offsetBy: 3)..<colon.lowerBound]
        guard !overflow.isEmpty, overflow.count < 60 else { return (title, desc) }
        let head = title.dropLast(3)
        let joiner = head.hasSuffix(" ") || overflow.first?.isPunctuation == true ? "" : " "
        return (head + joiner + overflow, String(desc[colon.upperBound...]).nilIfEmpty)
    }

    /// Normalises `S17E3` or xmltv_ns `16.2.0/1` into `S17 E3`.
    static func episodeLabel(onscreen: String?, xmltvNS: String?) -> String? {
        if let onscreen = onscreen?.nilIfEmpty {
            let upper = onscreen.uppercased()
            if let s = upper.firstIndex(of: "S"), let e = upper.firstIndex(of: "E"), s < e {
                let season = upper[upper.index(after: s)..<e].trimmingCharacters(in: .whitespaces)
                let episode = upper[upper.index(after: e)...].trimmingCharacters(in: .whitespaces)
                // Some series are numbered by year (S2026E17); show those as plain episodes.
                if let year = Int(season), year >= 1900, !episode.isEmpty { return "Ep \(episode)" }
                if !season.isEmpty, !episode.isEmpty { return "S\(season) E\(episode)" }
                if !episode.isEmpty { return "Ep \(episode)" }
            }
            return onscreen
        }
        guard let ns = xmltvNS?.nilIfEmpty else { return nil }
        let parts = ns.split(separator: ".", omittingEmptySubsequences: false).map {
            $0.split(separator: "/").first.map { String($0).trimmed } ?? ""
        }
        let season = parts.count > 0 ? Int(parts[0]).map { $0 + 1 } : nil
        let episode = parts.count > 1 ? Int(parts[1]).map { $0 + 1 } : nil
        switch (season, episode) {
        case let (s?, e?): return "S\(s) E\(e)"
        case let (nil, e?): return "Ep \(e)"
        default: return nil
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
