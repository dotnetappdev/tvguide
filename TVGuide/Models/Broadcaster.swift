import Foundation

/// The broadcaster's own streaming app, used as a fallback way to watch a
/// channel live when no stream is configured in the app.
///
/// These deep links are not officially documented by the broadcasters; they
/// are tried in order and the app's home screen is used as a last resort.
struct Broadcaster: Equatable {
    let appName: String
    let links: [URL]

    static func `for`(_ channel: Channel) -> Broadcaster? {
        let id = channel.id
        func urls(_ strings: String...) -> [URL] { strings.compactMap(URL.init(string:)) }

        if id.hasPrefix("BBC") || id == "CBBC.uk" || id == "CBeebies.uk" {
            let slug = bbcSlug(id)
            return Broadcaster(appName: "BBC iPlayer",
                               links: urls("bbciplayer://channels/\(slug)", "bbciplayer://"))
        }
        if id.hasPrefix("ITV") || id == "UTV.uk" {
            let slug = id.hasPrefix("ITV2") ? "itv2" : id.hasPrefix("ITV3") ? "itv3" : id.hasPrefix("ITV4") ? "itv4" : "itv"
            return Broadcaster(appName: "ITVX", links: urls("itvplayer://freeview_app/simulcast/\(slug)", "itvplayer://"))
        }
        if id.hasPrefix("STV") {
            return Broadcaster(appName: "STV Player", links: urls("stvplayer://"))
        }
        if id.hasPrefix("Channel4") || id.hasPrefix("E4") || id.hasPrefix("More4") || id.hasPrefix("Film4") || id == "4seven.uk" {
            let slug = id.hasPrefix("E4") ? "E4" : id.hasPrefix("More4") ? "M4" : id.hasPrefix("Film4") ? "F4" : id == "4seven.uk" ? "4S" : "C4"
            return Broadcaster(appName: "Channel 4", links: urls("all4://views/on-now?channel=\(slug)", "all4://"))
        }
        if id.hasPrefix("5") {
            return Broadcaster(appName: "5", links: urls("my5://"))
        }
        if id.hasPrefix("sky:") {
            // Sky's channels stream in the NOW app on Apple TV (Sky Go isn't available).
            return Broadcaster(appName: "NOW", links: urls("nowtv://"))
        }
        if id.hasPrefix("UAnd") {
            return Broadcaster(appName: "U", links: urls("uktvplay://"))
        }
        return nil
    }

    private static func bbcSlug(_ id: String) -> String {
        switch id {
        case _ where id.hasPrefix("BBCOne"): "bbc_one_hd"
        case _ where id.hasPrefix("BBCTwo"): "bbc_two_hd"
        case "BBCThreeHD.uk": "bbc_three"
        case "BBCFourHD.uk": "bbc_four"
        case "BBCNews.uk": "bbc_news"
        case "BBCParliament.uk": "bbc_parliament"
        case "BBCScotland.uk": "bbc_scotland"
        case "BBCAlba.uk": "bbc_alba"
        case "CBBC.uk": "cbbc"
        case "CBeebies.uk": "cbeebies"
        default: "bbc_one_hd"
        }
    }
}
