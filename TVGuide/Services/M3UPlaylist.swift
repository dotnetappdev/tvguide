import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An extended M3U playlist of live channels, as exported by Channels DVR,
/// Jellyfin, Plex, TVHeadend, HDHomeRun gateways or an IPTV provider.
struct M3UPlaylist {
    struct Entry: Equatable {
        var name: String
        var tvgID: String?
        var tvgName: String?
        var number: Int?
        var url: URL
    }

    var entries: [Entry]

    static func parse(_ text: String) -> M3UPlaylist {
        var entries: [Entry] = []
        var pending: (name: String, attributes: [String: String])?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#EXTINF") {
                pending = (displayName(line), attributes(line))
            } else if line.hasPrefix("#") {
                continue
            } else if let url = URL(string: line), url.scheme != nil {
                let attrs = pending?.attributes ?? [:]
                let chno = attrs["tvg-chno"] ?? attrs["channel-number"] ?? attrs["channel-id"]
                entries.append(Entry(name: pending?.name ?? "",
                                     tvgID: attrs["tvg-id"]?.nilIfEmpty,
                                     tvgName: attrs["tvg-name"]?.nilIfEmpty,
                                     number: chno.flatMap { Int($0) },
                                     url: url))
                pending = nil
            }
        }
        let header = text.prefix { $0 != "\n" && $0 != "\r" }
        let headerAttributes = header.hasPrefix("#EXTM3U") ? attributes(String(header)) : [:]
        let guide = (headerAttributes["url-tvg"] ?? headerAttributes["x-tvg-url"])?
            .split(separator: ",").first.flatMap { URL(string: String($0).trimmed) }
        return M3UPlaylist(entries: entries, guideURL: guide)
    }

    static func load(from url: URL, session: URLSession = .shared) async throws -> M3UPlaylist {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return parse(String(decoding: data, as: UTF8.self))
    }

    /// Matches playlist entries to guide channels: first by XMLTV id, then by
    /// channel name (see `ChannelMatcher`), then (for unnamed entries) by number.
    func streams(for channels: [Channel]) -> [String: URL] {
        let ids = Dictionary(channels.map { ($0.id.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        let numbers = Dictionary(channels.map { ($0.number, $0) }, uniquingKeysWith: { a, _ in a })
        let matcher = ChannelMatcher(channels: channels)
        var result: [String: URL] = [:]
        for entry in entries {
            let channel = entry.tvgID.flatMap { ids[$0.lowercased()] }
                ?? [entry.tvgName, entry.name].compactMap { $0?.nilIfEmpty }.lazy.compactMap(matcher.match(name:)).first
                // Numbering differs between providers, so only trust it for unnamed entries.
                ?? (entry.tvgName == nil && entry.name.isEmpty ? entry.number.flatMap { numbers[$0] } : nil)
            if let channel, result[channel.id] == nil { result[channel.id] = entry.url }
        }
        return result
    }

    /// The XMLTV guide address advertised in the playlist header (`url-tvg` / `x-tvg-url`), if any.
    var guideURL: URL?

    private static func displayName(_ line: String) -> String {
        // The name follows the last comma that is outside quotes.
        var inQuotes = false
        var commaIndex: String.Index?
        for index in line.indices {
            if line[index] == "\"" { inQuotes.toggle() }
            else if line[index] == ",", !inQuotes { commaIndex = index }
        }
        guard let commaIndex else { return "" }
        return String(line[line.index(after: commaIndex)...]).trimmed
    }

    private static func attributes(_ line: String) -> [String: String] {
        var result: [String: String] = [:]
        let scanner = line[...]
        var index = scanner.startIndex
        while let eq = scanner[index...].firstIndex(of: "=") {
            // Key: characters before '=' back to the previous space.
            let keyStart = scanner[..<eq].lastIndex(of: " ").map(scanner.index(after:)) ?? scanner.startIndex
            let key = String(scanner[keyStart..<eq]).lowercased()
            let afterEq = scanner.index(after: eq)
            guard afterEq < scanner.endIndex, scanner[afterEq] == "\"" else { index = afterEq; continue }
            let valueStart = scanner.index(after: afterEq)
            guard let close = scanner[valueStart...].firstIndex(of: "\"") else { break }
            result[key] = String(scanner[valueStart..<close])
            index = scanner.index(after: close)
        }
        return result
    }
}
