import Foundation

/// The UK free-to-air TV line-up, using the channel numbers from Sky's own
/// guide (101 BBC One, 102 BBC Two, 103 ITV1 …, 3xx movies, 5xx news, 6xx kids).
/// Regional channels are swapped in per `Region`.
enum ChannelLineup {
    static func channels(for region: Region) -> [Channel] {
        var list: [Channel] = [
            Channel(101, "BBC One", id: region.bbcOne, .entertainment, hd: true, brand: "D6002A"),
            Channel(102, "BBC Two", id: region.bbcTwo, .entertainment, hd: true, brand: "6A1FB5"),
            Channel(103, region.itv1Name, id: region.itv1, .entertainment, hd: true, brand: "0AA8A0"),
            Channel(region.channel4Number, "Channel 4", id: region.channel4, .entertainment, hd: true, brand: "1F2A44"),
            Channel(105, "5", id: "5.uk", .entertainment, hd: true, brand: "E6007E"),
            Channel(118, "ITV2", id: "ITV2.uk", .entertainment, hd: true, brand: "0AA8A0"),
            Channel(115, "BBC Three", id: "BBCThreeHD.uk", .entertainment, hd: true, brand: "C1F06E"),
            Channel(116, "BBC Four", id: "BBCFourHD.uk", .factual, hd: true, brand: "2B2B2B"),
            Channel(119, "ITV3", id: "ITV3.uk", .entertainment, hd: true, brand: "0AA8A0"),
            Channel(151, "Sky Mix", id: "SkyMix.uk", .entertainment, hd: true, brand: "0A6CFF"),
            Channel(140, "Quest", id: "QuestHD.uk", .factual, hd: true, brand: "F3A712"),
            Channel(135, "E4", id: "E4.uk", .entertainment, brand: "5A2D82"),
            Channel(313, "Film4", id: "Film4.uk", .films, brand: "1F2A44"),
            Channel(142, "Really", id: "Really.uk", .factual, brand: "E5007D"),
            Channel(136, "More4", id: "More4.uk", .entertainment, brand: "00A651"),
            Channel(111, "U&Dave", id: "UAndDave.uk", .entertainment, brand: "111111"),
            Channel(143, "U&Drama", id: "UAndDrama.uk", .entertainment, brand: "8A0F3C"),
            Channel(141, "5USA", id: "5USA.uk", .entertainment, brand: "1E3A8A"),
            Channel(122, "Sky Arts", id: "SkyArts.uk", .factual, brand: "C8102E"),
            Channel(120, "ITV4", id: "ITV4.uk", .entertainment, hd: true, brand: "0AA8A0"),
            Channel(155, "U&Yesterday", id: "UAndYesterday.uk", .factual, brand: "B8860B"),
            Channel(131, "ITV Quiz", id: "ITVQuiz.uk", .entertainment, brand: "0AA8A0"),
            Channel(138, "E4 Extra", id: "E4Extra.uk", .entertainment, brand: "5A2D82"),
            Channel(128, "5STAR", id: "5Star.uk", .entertainment, brand: "E6007E"),
            Channel(150, "5ACTION", id: "5Action.uk", .entertainment, brand: "E6007E"),
            Channel(137, "4seven", id: "4seven.uk", .entertainment, brand: "1F2A44"),
            Channel(149, "Quest Red", id: "QuestRed.uk", .factual, brand: "C8102E"),
            Channel(159, "DMAX", id: "DMAX.uk", .factual, brand: "1C1C1C"),
            Channel(144, "Food Network", id: "FoodNetwork.uk", .factual, brand: "D62828"),
            Channel(148, "Legend", id: "Legend.uk", .entertainment, brand: "7A1F1F"),
            Channel(130, "Challenge", id: "Challenge.uk", .entertainment, brand: "F26522"),
            Channel(133, "TLC", id: "TLC.uk", .factual, brand: "E4007C"),
            Channel(156, "Blaze", id: "Blaze.uk", .factual, brand: "E25822"),
            Channel(173, "PBS America", id: "PBSAmerica.uk", .factual, brand: "2638C4"),
            Channel(153, "5SELECT", id: "5Select.uk", .factual, brand: "E6007E"),
            Channel(170, "Together TV", id: "TogetherTV.uk", .factual, brand: "F5A623"),
            Channel(157, "GREAT! tv", id: "GreatTV.uk", .entertainment, brand: "D7263D"),
            Channel(320, "GREAT! Mystery", id: "GreatMystery.uk", .entertainment, brand: "D7263D"),
            Channel(132, "U&W", id: "UAndW.uk", .entertainment, brand: "6B2C91"),
            Channel(146, "True Crime", id: "TrueCrime.uk", .factual, brand: "8B0000"),
            Channel(324, "Talking Pictures TV", id: "TalkingPicturesTV.uk", .films, brand: "6D4C41"),
            Channel(607, "CBBC", id: "CBBC.uk", .kids, brand: "7AC943"),
            Channel(608, "CBeebies", id: "CBeebies.uk", .kids, brand: "F6B800"),
            Channel(503, "BBC News", id: "BBCNews.uk", .news, hd: true, brand: "B80000"),
            Channel(504, "BBC Parliament", id: "BBCParliament.uk", .news, hd: true, brand: "0B6E4F"),
            Channel(501, "Sky News", id: "SkyNews.uk", .news, hd: true, brand: "C8102E"),
            Channel(511, "Al Jazeera", id: "AlJazeeraEnglish.qa", .news, hd: true, brand: "C68B00"),
            Channel(512, "GB News", id: "GBNews.uk", .news, hd: true, brand: "0B2341"),
            Channel(502, "Bloomberg", id: "BloombergTVEurope.uk", .news, hd: true, brand: "000000"),
            Channel(506, "CNN", id: "CNNInternational.uk", .news, hd: true, brand: "CC0000"),
            Channel(510, "France 24", id: "France24English.fr", .news, hd: true, brand: "00A3E0"),
            Channel(508, "Euronews", id: "EuronewsEnglish.fr", .news, brand: "003B71"),
        ]
        if let plus1 = region.itvPlus1 {
            list.append(Channel(203, region.itvPlus1Name, id: plus1, .entertainment, brand: "0AA8A0"))
        }
        if let plus1 = region.channel4Plus1 {
            list.append(Channel(204, "Channel 4+1", id: plus1, .entertainment, brand: "1F2A44"))
        }
        list.append(contentsOf: region.extras)

        // Keep the first occurrence of an id and order by channel number.
        var seen = Set<String>()
        return list
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.number, $0.name) < ($1.number, $1.name) }
    }
}
