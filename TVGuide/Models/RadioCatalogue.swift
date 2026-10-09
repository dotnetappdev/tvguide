import Foundation

/// Radio stations beyond Sky's own radio list (0101–0142), numbered Sky style
/// after it:
/// - 0143–0146 extra BBC national streams
/// - 0150–0189 national commercial stations (Absolute, KISS, Magic, Greatest
///   Hits, Hits Radio, Jazz FM, Planet Rock, Boom, LBC London, Global extras)
/// - 0200–0241 BBC Local Radio
/// - 0260 onwards regional stations for Scotland, Northern Ireland, Wales and
///   the English regions (Cool FM, Downtown, Clyde 1, Forth 1, Radio City …)
///
/// BBC and Global stream addresses were checked when this list was written.
/// Rayo stations (formerly Bauer) are looked up live from Rayo's station
/// list, which supplies their current streams, logos and what's on air.
struct CatalogueStation {
    enum Source {
        case stream(URL)
        /// Rayo station code, e.g. "abr" for Absolute Radio.
        case rayo(String)
    }

    let number: Int
    /// Channel id: the Freeview XMLTV id where there is one (so listings and
    /// logos come from the Freeview feed), otherwise "radio:<key>".
    let id: String
    let name: String
    let region: String
    let tagline: String?
    let source: Source

    var rayoCode: String? {
        if case .rayo(let code) = source { return code }
        return nil
    }

    var fixedStream: URL? {
        if case .stream(let url) = source { return url }
        return nil
    }

    static let all: [CatalogueStation] = [
        CatalogueStation(number: 143, id: "radio:bbc1dance", name: "BBC Radio 1 Dance", region: "UK", tagline: "Non-stop dance from Radio 1", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_one_dance.m3u8")!)),
        CatalogueStation(number: 144, id: "radio:bbc1anthems", name: "BBC Radio 1 Anthems", region: "UK", tagline: "The biggest anthems from Radio 1", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_one_anthems.m3u8")!)),
        CatalogueStation(number: 145, id: "radio:bbc3unwind", name: "BBC Radio 3 Unwind", region: "UK", tagline: "Calming classical music", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_three_unwind.m3u8")!)),
        CatalogueStation(number: 146, id: "radio:bbcnews", name: "BBC Live News", region: "UK", tagline: "Rolling news from BBC News", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_sounds_news.m3u8")!)),
        CatalogueStation(number: 150, id: "radio:rayo-abr", name: "Absolute Radio", region: "UK", tagline: nil, source: .rayo("abr")),
        CatalogueStation(number: 151, id: "radio:rayo-ab7", name: "Absolute Radio 70s", region: "UK", tagline: nil, source: .rayo("ab7")),
        CatalogueStation(number: 152, id: "radio:rayo-ab8", name: "Absolute 80s", region: "UK", tagline: nil, source: .rayo("ab8")),
        CatalogueStation(number: 153, id: "radio:rayo-ab9", name: "Absolute Radio 90s", region: "UK", tagline: nil, source: .rayo("ab9")),
        CatalogueStation(number: 154, id: "radio:rayo-ab0", name: "Absolute Radio 00s", region: "UK", tagline: nil, source: .rayo("ab0")),
        CatalogueStation(number: 155, id: "radio:rayo-ab1", name: "Absolute Radio 10s", region: "UK", tagline: nil, source: .rayo("ab1")),
        CatalogueStation(number: 156, id: "radio:rayo-abc", name: "Absolute Classic Rock", region: "UK", tagline: nil, source: .rayo("abc")),
        CatalogueStation(number: 157, id: "radio:rayo-abk", name: "Absolute Radio Country", region: "UK", tagline: nil, source: .rayo("abk")),
        CatalogueStation(number: 158, id: "radio:rayo-ki1", name: "KISS", region: "UK", tagline: nil, source: .rayo("ki1")),
        CatalogueStation(number: 159, id: "radio:rayo-ki2", name: "KISSTORY", region: "UK", tagline: nil, source: .rayo("ki2")),
        CatalogueStation(number: 160, id: "radio:rayo-ki3", name: "KISS XTRA", region: "UK", tagline: nil, source: .rayo("ki3")),
        CatalogueStation(number: 161, id: "radio:rayo-ki5", name: "KISS DANCE", region: "UK", tagline: nil, source: .rayo("ki5")),
        CatalogueStation(number: 162, id: "radio:rayo-ktb", name: "KISSTORY R&B", region: "UK", tagline: nil, source: .rayo("ktb")),
        CatalogueStation(number: 163, id: "radio:rayo-mag", name: "Magic Radio", region: "UK", tagline: nil, source: .rayo("mag")),
        CatalogueStation(number: 164, id: "radio:rayo-mel", name: "Mellow Magic", region: "UK", tagline: nil, source: .rayo("mel")),
        CatalogueStation(number: 165, id: "radio:rayo-mso", name: "Magic Soul", region: "UK", tagline: nil, source: .rayo("mso")),
        CatalogueStation(number: 166, id: "radio:rayo-mmu", name: "Magic Musicals", region: "UK", tagline: nil, source: .rayo("mmu")),
        CatalogueStation(number: 167, id: "radio:rayo-mrs", name: "Magic Classical", region: "UK", tagline: nil, source: .rayo("mrs")),
        CatalogueStation(number: 168, id: "radio:rayo-gh0", name: "Greatest Hits Radio", region: "UK", tagline: nil, source: .rayo("gh0")),
        CatalogueStation(number: 169, id: "radio:rayo-g6s", name: "Greatest Hits Radio 60s", region: "UK", tagline: nil, source: .rayo("g6s")),
        CatalogueStation(number: 170, id: "radio:rayo-70s", name: "Greatest Hits Radio 70s", region: "UK", tagline: nil, source: .rayo("70s")),
        CatalogueStation(number: 171, id: "radio:rayo-80s", name: "Greatest Hits Radio 80s", region: "UK", tagline: nil, source: .rayo("80s")),
        CatalogueStation(number: 172, id: "radio:rayo-hit", name: "Hits Radio", region: "UK", tagline: nil, source: .rayo("hit")),
        CatalogueStation(number: 173, id: "radio:rayo-h90", name: "Hits Radio 90s", region: "UK", tagline: nil, source: .rayo("h90")),
        CatalogueStation(number: 174, id: "radio:rayo-h00", name: "Hits Radio 00s", region: "UK", tagline: nil, source: .rayo("h00")),
        CatalogueStation(number: 175, id: "radio:rayo-hch", name: "Hits Radio Chilled", region: "UK", tagline: nil, source: .rayo("hch")),
        CatalogueStation(number: 176, id: "radio:rayo-jaz", name: "Jazz FM", region: "UK", tagline: nil, source: .rayo("jaz")),
        CatalogueStation(number: 177, id: "radio:rayo-pln", name: "Planet Rock", region: "UK", tagline: nil, source: .rayo("pln")),
        CatalogueStation(number: 178, id: "radio:rayo-ker", name: "Kerrang! Radio", region: "UK", tagline: nil, source: .rayo("ker")),
        CatalogueStation(number: 179, id: "radio:rayo-htr", name: "heat Radio", region: "UK", tagline: nil, source: .rayo("htr")),
        CatalogueStation(number: 180, id: "radio:boom", name: "Boom Radio", region: "UK", tagline: "Music and memories for baby boomers", source: .stream(URL(string: "https://listen-boomradio.sharp-stream.com/65_boom_radio_live_128")!)),
        CatalogueStation(number: 181, id: "radio:gbnews", name: "GB News Radio", region: "UK", tagline: "News and opinion", source: .stream(URL(string: "https://listen-gbnews.sharp-stream.com/gbnews.mp3")!)),
        CatalogueStation(number: 182, id: "radio:lbclondon", name: "LBC London", region: "London", tagline: "LBC with London news and travel", source: .stream(URL(string: "https://media-ssl.musicradio.com/LBCLondonMP3")!)),
        CatalogueStation(number: 183, id: "radio:capitaldance", name: "Capital Dance", region: "UK", tagline: "Non-stop dance", source: .stream(URL(string: "https://media-ssl.musicradio.com/CapitalDanceMP3")!)),
        CatalogueStation(number: 184, id: "radio:capitalchill", name: "Capital Chill", region: "UK", tagline: "Chilled beats", source: .stream(URL(string: "https://media-ssl.musicradio.com/CapitalChillMP3")!)),
        CatalogueStation(number: 185, id: "radio:heart70s", name: "Heart 70s", region: "UK", tagline: "Non-stop 70s hits", source: .stream(URL(string: "https://media-ssl.musicradio.com/Heart70sMP3")!)),
        CatalogueStation(number: 186, id: "radio:heart00s", name: "Heart 00s", region: "UK", tagline: "Non-stop 00s hits", source: .stream(URL(string: "https://media-ssl.musicradio.com/Heart00sMP3")!)),
        CatalogueStation(number: 187, id: "radio:smoothchill", name: "Smooth Chill", region: "UK", tagline: "Chilled music", source: .stream(URL(string: "https://media-ssl.musicradio.com/SmoothChillMP3")!)),
        CatalogueStation(number: 188, id: "radio:smoothcountry", name: "Smooth Country", region: "UK", tagline: "Country hits", source: .stream(URL(string: "https://media-ssl.musicradio.com/SmoothCountryMP3")!)),
        CatalogueStation(number: 189, id: "radio:radioxclassic", name: "Radio X Classic Rock", region: "UK", tagline: "Classic rock", source: .stream(URL(string: "https://media-ssl.musicradio.com/RadioXClassicRockMP3")!)),
        CatalogueStation(number: 200, id: "BBCRadioBerkshire.uk", name: "BBC Radio Berkshire", region: "Berkshire", tagline: "Local news, sport and music for Berkshire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_berkshire.m3u8")!)),
        CatalogueStation(number: 201, id: "BBCRadioBristol.uk", name: "BBC Radio Bristol", region: "Bristol", tagline: "Local news, sport and music for Bristol", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_bristol.m3u8")!)),
        CatalogueStation(number: 202, id: "BBCRadioCambridgeshire.uk", name: "BBC Radio Cambridgeshire", region: "Cambridgeshire", tagline: "Local news, sport and music for Cambridgeshire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_cambridge.m3u8")!)),
        CatalogueStation(number: 203, id: "BBCRadioCornwall.uk", name: "BBC Radio Cornwall", region: "Cornwall", tagline: "Local news, sport and music for Cornwall", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_cornwall.m3u8")!)),
        CatalogueStation(number: 204, id: "radio:bbcradiocwr", name: "BBC CWR", region: "Coventry & Warwickshire", tagline: "Local news, sport and music for Coventry & Warwickshire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_coventry_warwickshire.m3u8")!)),
        CatalogueStation(number: 205, id: "BBCRadioCumbria.uk", name: "BBC Radio Cumbria", region: "Cumbria", tagline: "Local news, sport and music for Cumbria", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_cumbria.m3u8")!)),
        CatalogueStation(number: 206, id: "BBCRadioDerby.uk", name: "BBC Radio Derby", region: "Derbyshire", tagline: "Local news, sport and music for Derbyshire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_derby.m3u8")!)),
        CatalogueStation(number: 207, id: "BBCRadioDevon.uk", name: "BBC Radio Devon", region: "Devon", tagline: "Local news, sport and music for Devon", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_devon.m3u8")!)),
        CatalogueStation(number: 208, id: "radio:bbcradioessex", name: "BBC Essex", region: "Essex", tagline: "Local news, sport and music for Essex", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_essex.m3u8")!)),
        CatalogueStation(number: 209, id: "BBCRadioGloucestershire.uk", name: "BBC Radio Gloucestershire", region: "Gloucestershire", tagline: "Local news, sport and music for Gloucestershire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_gloucestershire.m3u8")!)),
        CatalogueStation(number: 210, id: "radio:bbcradioguernsey", name: "BBC Radio Guernsey", region: "Guernsey", tagline: "Local news, sport and music for Guernsey", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_guernsey.m3u8")!)),
        CatalogueStation(number: 211, id: "radio:bbcradioherefordworcester", name: "BBC Hereford & Worcester", region: "Hereford & Worcester", tagline: "Local news, sport and music for Hereford & Worcester", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_hereford_worcester.m3u8")!)),
        CatalogueStation(number: 212, id: "BBCRadioHumberside.uk", name: "BBC Radio Humberside", region: "Humberside", tagline: "Local news, sport and music for Humberside", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_humberside.m3u8")!)),
        CatalogueStation(number: 213, id: "BBCRadioJersey.uk", name: "BBC Radio Jersey", region: "Jersey", tagline: "Local news, sport and music for Jersey", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_jersey.m3u8")!)),
        CatalogueStation(number: 214, id: "BBCRadioKent.uk", name: "BBC Radio Kent", region: "Kent", tagline: "Local news, sport and music for Kent", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_kent.m3u8")!)),
        CatalogueStation(number: 215, id: "BBCRadioLancashire.uk", name: "BBC Radio Lancashire", region: "Lancashire", tagline: "Local news, sport and music for Lancashire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_lancashire.m3u8")!)),
        CatalogueStation(number: 216, id: "BBCRadioLeeds.uk", name: "BBC Radio Leeds", region: "Leeds", tagline: "Local news, sport and music for Leeds", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_leeds.m3u8")!)),
        CatalogueStation(number: 217, id: "BBCRadioLeicester.uk", name: "BBC Radio Leicester", region: "Leicester", tagline: "Local news, sport and music for Leicester", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_leicester.m3u8")!)),
        CatalogueStation(number: 218, id: "BBCRadioLincolnshire.uk", name: "BBC Radio Lincolnshire", region: "Lincolnshire", tagline: "Local news, sport and music for Lincolnshire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_lincolnshire.m3u8")!)),
        CatalogueStation(number: 219, id: "BBCRadioManchester.uk", name: "BBC Radio Manchester", region: "Manchester", tagline: "Local news, sport and music for Manchester", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_manchester.m3u8")!)),
        CatalogueStation(number: 220, id: "BBCRadioMerseyside.uk", name: "BBC Radio Merseyside", region: "Merseyside", tagline: "Local news, sport and music for Merseyside", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_merseyside.m3u8")!)),
        CatalogueStation(number: 221, id: "BBCRadioNewcastle.uk", name: "BBC Radio Newcastle", region: "Newcastle", tagline: "Local news, sport and music for Newcastle", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_newcastle.m3u8")!)),
        CatalogueStation(number: 222, id: "BBCRadioNorfolk.uk", name: "BBC Radio Norfolk", region: "Norfolk", tagline: "Local news, sport and music for Norfolk", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_norfolk.m3u8")!)),
        CatalogueStation(number: 223, id: "BBCRadioNorthampton.uk", name: "BBC Radio Northampton", region: "Northampton", tagline: "Local news, sport and music for Northampton", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_northampton.m3u8")!)),
        CatalogueStation(number: 224, id: "BBCRadioNottingham.uk", name: "BBC Radio Nottingham", region: "Nottingham", tagline: "Local news, sport and music for Nottingham", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_nottingham.m3u8")!)),
        CatalogueStation(number: 225, id: "radio:bbcradiooxford", name: "BBC Radio Oxford", region: "Oxford", tagline: "Local news, sport and music for Oxford", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_oxford.m3u8")!)),
        CatalogueStation(number: 226, id: "BBCRadioSheffield.uk", name: "BBC Radio Sheffield", region: "Sheffield", tagline: "Local news, sport and music for Sheffield", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_sheffield.m3u8")!)),
        CatalogueStation(number: 227, id: "BBCRadioShropshire.uk", name: "BBC Radio Shropshire", region: "Shropshire", tagline: "Local news, sport and music for Shropshire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_shropshire.m3u8")!)),
        CatalogueStation(number: 228, id: "radio:bbcradiosolent", name: "BBC Radio Solent", region: "Solent", tagline: "Local news, sport and music for Solent", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_solent.m3u8")!)),
        CatalogueStation(number: 229, id: "radio:bbcradiosomerset", name: "BBC Radio Somerset", region: "Somerset", tagline: "Local news, sport and music for Somerset", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_somerset_sound.m3u8")!)),
        CatalogueStation(number: 230, id: "radio:bbcradiostoke", name: "BBC Radio Stoke", region: "Stoke", tagline: "Local news, sport and music for Stoke", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_stoke.m3u8")!)),
        CatalogueStation(number: 231, id: "radio:bbcradiosuffolk", name: "BBC Radio Suffolk", region: "Suffolk", tagline: "Local news, sport and music for Suffolk", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_suffolk.m3u8")!)),
        CatalogueStation(number: 232, id: "BBCRadioSurrey.uk", name: "BBC Radio Surrey", region: "Surrey", tagline: "Local news, sport and music for Surrey", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_surrey.m3u8")!)),
        CatalogueStation(number: 233, id: "radio:bbcradiosussex", name: "BBC Radio Sussex", region: "Sussex", tagline: "Local news, sport and music for Sussex", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_sussex.m3u8")!)),
        CatalogueStation(number: 234, id: "BBCRadioTees.uk", name: "BBC Tees", region: "Tees", tagline: "Local news, sport and music for Tees", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_tees.m3u8")!)),
        CatalogueStation(number: 235, id: "BBCRadioThreeCounties.uk", name: "BBC Three Counties Radio", region: "Beds, Herts & Bucks", tagline: "Local news, sport and music for Beds, Herts & Bucks", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_three_counties_radio.m3u8")!)),
        CatalogueStation(number: 236, id: "radio:bbcwm", name: "BBC WM", region: "West Midlands", tagline: "Local news, sport and music for West Midlands", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_wm.m3u8")!)),
        CatalogueStation(number: 237, id: "radio:bbcradiowiltshire", name: "BBC Radio Wiltshire", region: "Wiltshire", tagline: "Local news, sport and music for Wiltshire", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_wiltshire.m3u8")!)),
        CatalogueStation(number: 238, id: "BBCRadioYork.uk", name: "BBC Radio York", region: "York", tagline: "Local news, sport and music for York", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_york.m3u8")!)),
        CatalogueStation(number: 239, id: "BBCRadioOrkney.uk", name: "BBC Radio Orkney", region: "Orkney", tagline: "Local news, sport and music for Orkney", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_orkney.m3u8")!)),
        CatalogueStation(number: 240, id: "BBCRadioShetland.uk", name: "BBC Radio Shetland", region: "Shetland", tagline: "Local news, sport and music for Shetland", source: .stream(URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/ak/bbc_radio_shetland.m3u8")!)),
        CatalogueStation(number: 260, id: "radio:rayo-cl1", name: "Clyde 1", region: "Glasgow", tagline: nil, source: .rayo("cl1")),
        CatalogueStation(number: 261, id: "radio:rayo-cay", name: "Clyde 1 Ayrshire (West FM)", region: "Ayrshire", tagline: nil, source: .rayo("cay")),
        CatalogueStation(number: 262, id: "radio:rayo-fo1", name: "Forth 1", region: "Edinburgh", tagline: nil, source: .rayo("fo1")),
        CatalogueStation(number: 263, id: "radio:rayo-no1", name: "Northsound 1", region: "Aberdeen", tagline: nil, source: .rayo("no1")),
        CatalogueStation(number: 264, id: "radio:rayo-mf1", name: "MFR", region: "Inverness & Moray", tagline: nil, source: .rayo("mf1")),
        CatalogueStation(number: 265, id: "radio:rayo-ta1", name: "Tay FM", region: "Tayside", tagline: nil, source: .rayo("ta1")),
        CatalogueStation(number: 266, id: "radio:smoothscotland", name: "Smooth Scotland", region: "Scotland", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/SmoothScotlandMP3")!)),
        CatalogueStation(number: 267, id: "radio:rayo-coo", name: "Cool FM", region: "Northern Ireland", tagline: nil, source: .rayo("coo")),
        CatalogueStation(number: 268, id: "radio:rayo-cwf", name: "Cool Old Skool", region: "Northern Ireland", tagline: nil, source: .rayo("cwf")),
        CatalogueStation(number: 269, id: "radio:rayo-dra", name: "Downtown Radio", region: "Northern Ireland", tagline: nil, source: .rayo("dra")),
        CatalogueStation(number: 270, id: "radio:rayo-dco", name: "Downtown Country", region: "Northern Ireland", tagline: nil, source: .rayo("dco")),
        CatalogueStation(number: 271, id: "radio:capitalcymru", name: "Capital Cymru", region: "North Wales", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/CapitalCymruMP3")!)),
        CatalogueStation(number: 272, id: "radio:capitalsouthwales", name: "Capital South Wales", region: "South Wales", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/CapitalSouthWalesMP3")!)),
        CatalogueStation(number: 273, id: "radio:heartsouthwales", name: "Heart Wales", region: "Wales", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/HeartSouthWalesMP3")!)),
        CatalogueStation(number: 274, id: "radio:rayo-hrf", name: "Hits Radio Liverpool (Radio City)", region: "Liverpool", tagline: nil, source: .rayo("hrf")),
        CatalogueStation(number: 275, id: "radio:rayo-hrg", name: "Hits Radio Lancashire (Rock FM)", region: "Lancashire", tagline: nil, source: .rayo("hrg")),
        CatalogueStation(number: 276, id: "radio:rayo-hrn", name: "Hits Radio North East (Metro)", region: "North East", tagline: nil, source: .rayo("hrn")),
        CatalogueStation(number: 277, id: "radio:rayo-hra", name: "Hits Radio South Yorkshire (Hallam)", region: "South Yorkshire", tagline: nil, source: .rayo("hra")),
        CatalogueStation(number: 278, id: "radio:rayo-hrk", name: "Hits Radio East Yorkshire (Viking)", region: "East Yorkshire", tagline: nil, source: .rayo("hrk")),
        CatalogueStation(number: 279, id: "radio:rayo-hri", name: "Hits Radio Birmingham (Free Radio)", region: "Birmingham", tagline: nil, source: .rayo("hri")),
        CatalogueStation(number: 280, id: "radio:rayo-hru", name: "Hits Radio East Midlands (Gem 106)", region: "East Midlands", tagline: nil, source: .rayo("hru")),
        CatalogueStation(number: 281, id: "radio:capitalmanchester", name: "Capital Manchester & Lancashire", region: "Manchester", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/CapitalManchesterMP3")!)),
        CatalogueStation(number: 282, id: "radio:capitalbirmingham", name: "Capital Midlands", region: "Midlands", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/CapitalBirminghamMP3")!)),
        CatalogueStation(number: 283, id: "radio:heartnorthwest", name: "Heart North West", region: "North West", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/HeartNorthWestMP3")!)),
        CatalogueStation(number: 284, id: "radio:heartyorkshire", name: "Heart Yorkshire", region: "Yorkshire", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/HeartYorkshireMP3")!)),
        CatalogueStation(number: 285, id: "radio:heartwestmids", name: "Heart West Midlands", region: "West Midlands", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/HeartWestMidsMP3")!)),
        CatalogueStation(number: 286, id: "radio:heartbristol", name: "Heart West", region: "West", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/HeartBristolMP3")!)),
        CatalogueStation(number: 287, id: "radio:smoothnorthwest", name: "Smooth North West", region: "North West", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/SmoothNorthWestMP3")!)),
        CatalogueStation(number: 288, id: "radio:smoothwestmids", name: "Smooth West Midlands", region: "West Midlands", tagline: nil, source: .stream(URL(string: "https://media-ssl.musicradio.com/SmoothWestMidsMP3")!)),
    ]
}
