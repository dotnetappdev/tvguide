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
        return M3UPlaylist(entries: entries)
    }

    static func load(from url: URL, session: URLSession = .shared) async throws -> M3UPlaylist {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return parse(String(decoding: data, as: UTF8.self))
    }

    /// Matches playlist entries to guide channels: first by XMLTV id, then by
    /// channel name, then (for unnamed entries) by channel number.
    func streams(for channels: [Channel]) -> [String: URL] {
        var byID: [String: URL] = [:], byName: [String: URL] = [:], byNumber: [Int: URL] = [:]
        for entry in entries {
            if let id = entry.tvgID?.lowercased(), byID[id] == nil { byID[id] = entry.url }
            for name in [entry.tvgName, entry.name].compactMap({ $0 }) {
                let key = Self.normalise(name)
                if !key.isEmpty, byName[key] == nil { byName[key] = entry.url }
            }
            // Numbering differs between providers, so only trust it for unnamed entries.
            if let number = entry.number, entry.tvgName == nil, entry.name.isEmpty, byNumber[number] == nil {
                byNumber[number] = entry.url
            }
        }

        var result: [String: URL] = [:]
        for channel in channels {
            if let url = byID[channel.id.lowercased()] ?? byName[Self.normalise(channel.name)] ?? byNumber[channel.number] {
                result[channel.id] = url
            }
        }
        return result
    }

    /// "BBC One HD", "bbc one", "BBC ONE London HD" → "bbcone"-style keys.
    static func normalise(_ name: String) -> String {
        var key = name.lowercased()
        for noise in [" hd", " uhd", " london", " (uk)", " uk"] where key.hasSuffix(noise) {
            key.removeLast(noise.count)
        }
        return key.filter { $0.isLetter || $0.isNumber || $0 == "+" }
    }

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
