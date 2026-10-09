import Foundation

/// The UK Freeview (digital terrestrial) TV line-up. Channel numbers follow
/// the England Freeview LCN plan; regional channels are swapped in per `Region`.
enum ChannelLineup {
    static func channels(for region: Region) -> [Channel] {
        var list: [Channel] = [
            Channel(1, "BBC One", id: region.bbcOne, .entertainment, hd: true, brand: "D6002A"),
            Channel(2, "BBC Two", id: region.bbcTwo, .entertainment, hd: true, brand: "6A1FB5"),
            Channel(3, region.itv1Name, id: region.itv1, .entertainment, hd: true, brand: "0AA8A0"),
            Channel(region.channel4Number, "Channel 4", id: region.channel4, .entertainment, hd: true, brand: "1F2A44"),
            Channel(5, "5", id: "5.uk", .entertainment, hd: true, brand: "E6007E"),
            Channel(6, "ITV2", id: "ITV2.uk", .entertainment, hd: true, brand: "0AA8A0"),
            Channel(7, "BBC Three", id: "BBCThreeHD.uk", .entertainment, hd: true, brand: "C1F06E"),
            Channel(9, "BBC Four", id: "BBCFourHD.uk", .factual, hd: true, brand: "2B2B2B"),
            Channel(10, "ITV3", id: "ITV3.uk", .entertainment, hd: true, brand: "0AA8A0"),
            Channel(11, "Sky Mix", id: "SkyMix.uk", .entertainment, hd: true, brand: "0A6CFF"),
            Channel(12, "Quest", id: "QuestHD.uk", .factual, hd: true, brand: "F3A712"),
            Channel(13, "E4", id: "E4.uk", .entertainment, brand: "5A2D82"),
            Channel(14, "Film4", id: "Film4.uk", .films, brand: "1F2A44"),
            Channel(17, "Really", id: "Really.uk", .factual, brand: "E5007D"),
            Channel(18, "More4", id: "More4.uk", .entertainment, brand: "00A651"),
            Channel(19, "U&Dave", id: "UAndDave.uk", .entertainment, brand: "111111"),
            Channel(20, "U&Drama", id: "UAndDrama.uk", .entertainment, brand: "8A0F3C"),
            Channel(21, "5USA", id: "5USA.uk", .entertainment, brand: "1E3A8A"),
            Channel(23, "Sky Arts", id: "SkyArts.uk", .factual, brand: "C8102E"),
            Channel(24, "ITV4", id: "ITV4.uk", .entertainment, hd: true, brand: "0AA8A0"),
            Channel(25, "U&Yesterday", id: "UAndYesterday.uk", .factual, brand: "B8860B"),
            Channel(26, "ITV Quiz", id: "ITVQuiz.uk", .entertainment, brand: "0AA8A0"),
            Channel(29, "E4 Extra", id: "E4Extra.uk", .entertainment, brand: "5A2D82"),
            Channel(30, "5STAR", id: "5Star.uk", .entertainment, brand: "E6007E"),
            Channel(31, "5ACTION", id: "5Action.uk", .entertainment, brand: "E6007E"),
            Channel(33, "4seven", id: "4seven.uk", .entertainment, brand: "1F2A44"),
            Channel(36, "Quest Red", id: "QuestRed.uk", .factual, brand: "C8102E"),
            Channel(37, "DMAX", id: "DMAX.uk", .factual, brand: "1C1C1C"),
            Channel(38, "Food Network", id: "FoodNetwork.uk", .factual, brand: "D62828"),
            Channel(41, "Legend", id: "Legend.uk", .entertainment, brand: "7A1F1F"),
            Channel(42, "Challenge", id: "Challenge.uk", .entertainment, brand: "F26522"),
            Channel(43, "TLC", id: "TLC.uk", .factual, brand: "E4007C"),
            Channel(44, "Blaze", id: "Blaze.uk", .factual, brand: "E25822"),
            Channel(45, "PBS America", id: "PBSAmerica.uk", .factual, brand: "2638C4"),
            Channel(46, "5SELECT", id: "5Select.uk", .factual, brand: "E6007E"),
            Channel(48, "Together TV", id: "TogetherTV.uk", .factual, brand: "F5A623"),
            Channel(50, "GREAT! tv", id: "GreatTV.uk", .entertainment, brand: "D7263D"),
            Channel(51, "GREAT! Movies", id: "GreatMovies.uk", .films, brand: "D7263D"),
            Channel(52, "GREAT! Mystery", id: "GreatMystery.uk", .entertainment, brand: "D7263D"),
            Channel(53, "GREAT! Romance", id: "GreatRomance.uk", .films, brand: "D7263D"),
            Channel(60, "U&W", id: "UAndW.uk", .entertainment, brand: "6B2C91"),
            Channel(61, "True Crime", id: "TrueCrime.uk", .factual, brand: "8B0000"),
            Channel(70, "Movies24", id: "Movies24.uk", .films, brand: "3A0CA3"),
            Channel(81, "Talking Pictures TV", id: "TalkingPicturesTV.uk", .films, brand: "6D4C41"),
            Channel(82, "That's TV", id: "ThatsTV.uk", .entertainment, brand: "FF6F00"),
            Channel(201, "CBBC", id: "CBBC.uk", .kids, brand: "7AC943"),
            Channel(202, "CBeebies", id: "CBeebies.uk", .kids, brand: "F6B800"),
            Channel(231, "BBC News", id: "BBCNews.uk", .news, hd: true, brand: "B80000"),
            Channel(232, "BBC Parliament", id: "BBCParliament.uk", .news, hd: true, brand: "0B6E4F"),
            Channel(233, "Sky News", id: "SkyNews.uk", .news, hd: true, brand: "C8102E"),
            Channel(234, "Al Jazeera", id: "AlJazeeraEnglish.qa", .news, hd: true, brand: "C68B00"),
            Channel(235, "GB News", id: "GBNews.uk", .news, hd: true, brand: "0B2341"),
            Channel(236, "Bloomberg", id: "BloombergTVEurope.uk", .news, hd: true, brand: "000000"),
            Channel(237, "CNN", id: "CNNInternational.uk", .news, hd: true, brand: "CC0000"),
            Channel(238, "France 24", id: "France24English.fr", .news, hd: true, brand: "00A3E0"),
            Channel(239, "Euronews", id: "EuronewsEnglish.fr", .news, brand: "003B71"),
        ]
        if let plus1 = region.itvPlus1 {
            list.append(Channel(35, region.itvPlus1Name, id: plus1, .entertainment, brand: "0AA8A0"))
        }
        if let plus1 = region.channel4Plus1 {
            list.append(Channel(15, "Channel 4+1", id: plus1, .entertainment, brand: "1F2A44"))
        }
        list.append(contentsOf: region.extras)

        // Keep the first occurrence of an id and order by channel number.
        var seen = Set<String>()
        return list
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.number, $0.name) < ($1.number, $1.name) }
    }
}
