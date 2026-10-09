import Foundation

/// Groups used by the sidebar to filter the guide.
enum ChannelCategory: String, CaseIterable, Identifiable, Codable {
    case all
    case favourites
    case entertainment
    case films
    case sport
    case factual
    case news
    case kids

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All channels"
        case .favourites: "Favourites"
        case .entertainment: "Entertainment"
        case .films: "Movies"
        case .sport: "Sports"
        case .factual: "Documentaries"
        case .news: "News"
        case .kids: "Kids"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .favourites: "heart"
        case .entertainment: "sparkles.tv"
        case .films: "film"
        case .sport: "sportscourt"
        case .factual: "globe.europe.africa"
        case .news: "newspaper"
        case .kids: "balloon.2"
        }
    }

    /// Categories that a channel can belong to (excludes the virtual filters).
    static var filters: [ChannelCategory] { [.all, .favourites, .entertainment, .films, .sport, .factual, .news, .kids] }
}

/// A broadcast channel in the Freeview line-up.
struct Channel: Identifiable, Hashable, Codable {
    /// The XMLTV channel id used by the EPG feed, e.g. `BBCTwoHD.uk`.
    let id: String
    /// Logical channel number shown in the guide.
    let number: Int
    let name: String
    let category: ChannelCategory
    let isHD: Bool
    /// Brand colour used for fallback logos and tile gradients, as `RRGGBB`.
    let brandHex: String
    var logoURL: URL?

    init(_ number: Int, _ name: String, id: String, _ category: ChannelCategory,
         hd: Bool = false, brand: String = "1F4FD1") {
        self.id = id
        self.number = number
        self.name = name
        self.category = category
        self.isHD = hd
        self.brandHex = brand
        self.logoURL = nil
    }

    /// Two or three letter monogram for the fallback logo.
    var monogram: String {
        if name.hasPrefix("TNT Sports ") { return "TNT " + name.dropFirst(11) }
        for prefix in ["Sky Sports ", "Sky Cinema ", "Sky "] where name.hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        let words = name.split(separator: " ")
        if let first = words.first, first.count <= 4 { return String(first) }
        return words.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}
