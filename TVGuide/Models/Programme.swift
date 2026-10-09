import Foundation

/// A single listing in the electronic programme guide.
struct Programme: Identifiable, Hashable {
    let id: String
    let channelID: String
    let title: String
    let subtitle: String?
    let synopsis: String?
    let start: Date
    let end: Date
    let imageURL: URL?
    /// Human readable episode marker, e.g. `S17 E3`.
    let episode: String?
    let isNew: Bool
    /// `true` for filler cells covering a hole in the listings.
    let isPlaceholder: Bool

    init(channelID: String, title: String, subtitle: String? = nil, synopsis: String? = nil,
         start: Date, end: Date, imageURL: URL? = nil, episode: String? = nil,
         isNew: Bool = false, isPlaceholder: Bool = false) {
        self.id = "\(channelID)|\(Int(start.timeIntervalSince1970))"
        self.channelID = channelID
        self.title = title
        self.subtitle = subtitle
        self.synopsis = synopsis
        self.start = start
        self.end = end
        self.imageURL = imageURL
        self.episode = episode
        self.isNew = isNew
        self.isPlaceholder = isPlaceholder
    }

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func isOn(at date: Date) -> Bool { start <= date && date < end }

    /// 0...1 progress through the programme at `date`.
    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(start) / duration, 0), 1)
    }

    func overlaps(_ start: Date, _ end: Date) -> Bool { self.start < end && self.end > start }

    static func placeholder(channelID: String, start: Date, end: Date) -> Programme {
        Programme(channelID: channelID, title: "No information available",
                  start: start, end: end, isPlaceholder: true)
    }
}
