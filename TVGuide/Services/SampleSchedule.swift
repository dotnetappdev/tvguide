import Foundation

/// Generates plausible listings so the guide is still usable when the
/// live feed can't be reached (e.g. first launch with no network).
enum SampleSchedule {
    private static let titles: [ChannelCategory: [(String, Int)]] = [
        .entertainment: [("The Great British Menu", 60), ("Pointless", 45), ("Emmerdale", 30),
                         ("The Chase", 60), ("Gogglebox", 60), ("Ghosts", 30), ("Would I Lie to You?", 30),
                         ("Strictly Come Dancing", 90), ("Taskmaster", 60), ("Location, Location, Location", 60),
                         ("Coronation Street", 30), ("EastEnders", 30), ("Hollyoaks", 30), ("QI", 45)],
        .films: [("Paddington 2", 120), ("The Italian Job", 105), ("Brief Encounter", 90),
                 ("Mission: Impossible", 130), ("Notting Hill", 135), ("Hot Fuzz", 125)],
        .factual: [("Planet Earth III", 60), ("Grand Designs", 60), ("Wheeler Dealers", 60),
                   ("Countryfile", 60), ("Secrets of the Castle", 45), ("Abandoned Engineering", 60)],
        .news: [("The Latest", 30), ("Business Today", 30), ("World Report", 60), ("Breakfast", 180),
                ("Politics Live", 60), ("Weather", 15)],
        .kids: [("Hey Duggee", 15), ("Bluey", 15), ("Newsround", 15), ("Blue Peter", 30),
                ("Andy's Adventures", 15), ("The Next Step", 30)],
    ]

    static func make(for channels: [Channel], around date: Date = Date()) -> [String: [Programme]] {
        let calendar = Calendar.current
        let dayStart = calendar.date(byAdding: .hour, value: -6, to: date) ?? date
        let end = calendar.date(byAdding: .day, value: 2, to: date) ?? date
        var result: [String: [Programme]] = [:]

        for (index, channel) in channels.enumerated() {
            let pool = titles[channel.category] ?? titles[.entertainment]!
            var cursor = alignedDown(dayStart, minutes: 30)
            var i = index * 3
            var listings: [Programme] = []
            while cursor < end {
                let (title, minutes) = pool[i % pool.count]
                let next = cursor.addingTimeInterval(TimeInterval(minutes * 60))
                listings.append(Programme(
                    channelID: channel.id,
                    title: title,
                    synopsis: "Sample listing. Connect your Apple TV to the internet to load the live Freeview guide.",
                    start: cursor, end: next,
                    episode: minutes <= 60 ? "S\(1 + i % 9) E\(1 + i % 12)" : nil,
                    isNew: i % 5 == 0))
                cursor = next
                i += 1
            }
            result[channel.id] = listings
        }
        return result
    }

    static func alignedDown(_ date: Date, minutes: Int) -> Date {
        let step = TimeInterval(minutes * 60)
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded(.down) * step)
    }
}
