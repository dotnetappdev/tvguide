import Foundation

/// Matches channel names from tuners and playlists ("BBC ONE Lon HD",
/// "ITV1 HD", "Channel 5 HD") to the guide's channels.
struct ChannelMatcher {
    private let byKey: [String: Channel]
    private let keys: [(key: String, channel: Channel)]

    init(channels: [Channel]) {
        var byKey: [String: Channel] = [:]
        for channel in channels {
            for key in Self.keys(for: channel) where byKey[key] == nil { byKey[key] = channel }
        }
        self.byKey = byKey
        // Longest first, so "E4 Extra" wins over "E4" when matching by prefix.
        self.keys = byKey.map { ($0.key, $0.value) }.sorted { $0.key.count > $1.key.count }
    }

    /// Exact match on the normalised name, then the longest guide channel name
    /// that the tuner name starts with ("bbconelon" → "bbcone").
    func match(name: String) -> Channel? {
        let key = Self.normalise(name)
        guard !key.isEmpty else { return nil }
        if let exact = byKey[key] { return exact }
        return keys.first { $0.key.count >= 2 && key.hasPrefix($0.key) }?.channel
    }

    /// Lower-cases, drops "HD"/region words and punctuation: "BBC ONE Lon HD" → "bbcone".
    static func normalise(_ name: String) -> String {
        var words = name.lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "+", with: " plus ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        while let last = words.last, noise.contains(last), words.count > 1 { words.removeLast() }
        return words.joined()
    }

    /// Alternative spellings tuners use for some channels.
    private static func keys(for channel: Channel) -> [String] {
        var keys = [normalise(channel.name)]
        let aliases: [String: [String]] = [
            "5": ["channel5", "five"],
            "Sky Mix": ["skymixhd"],
            "5USA": ["5usa"],
            "ITV1+1": ["itvplus1"],
            "U&Dave": ["dave"],
            "U&Drama": ["drama"],
            "U&Yesterday": ["yesterday"],
            "U&W": ["w"],
            "Quest": ["quest"],
            "Al Jazeera": ["aljazeeraeng", "aljazeeraenglish"],
            "France 24": ["france24english"],
        ]
        keys += aliases[channel.name] ?? []
        return keys
    }

    private static let noise: Set<String> = [
        "hd", "uhd", "sd", "lon", "london", "uk", "eng", "england", "ne", "nw", "ee", "se", "sw", "w", "e",
        "yorks", "yorkshire", "wales", "cymru", "scot", "scotland", "ni", "east", "west", "south", "north",
        "midlands", "mids", "central", "granada", "meridian", "anglia", "tyne", "tees", "border", "westcountry",
    ]
}
