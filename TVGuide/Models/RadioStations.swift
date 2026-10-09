import Foundation

/// UK radio stations in Sky's radio line-up (0101 BBC Radio 1 … 0142 Times
/// Radio), with the broadcasters' own public internet streams.
///
/// Stream addresses were checked when this table was written: BBC stations
/// use the BBC's HLS streams, commercial stations their Icecast/AAC streams.
/// Stations without a working public stream have `stream == nil` and still
/// appear in the guide with their listings.
struct RadioStation {
    /// Sky radio number without the leading zero (101 = "0101").
    let number: Int
    let name: String
    let stream: URL?
    let logo: URL?
    let brand: String

    static func with(number: Int) -> RadioStation? { all[number] }

    static let all: [Int: RadioStation] = {
        let list: [RadioStation] = [
            RadioStation(number: 101, name: "BBC Radio 1", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_01505109/live/ww/bbc_radio_one/bbc_radio_one.isml/bbc_radio_one-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-1.png"), brand: "000000"),
            RadioStation(number: 102, name: "BBC Radio 2", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_74208725/live/ww/bbc_radio_two/bbc_radio_two.isml/bbc_radio_two-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-2.png"), brand: "E66B21"),
            RadioStation(number: 103, name: "BBC Radio 3", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_23461179/live/ww/bbc_radio_three/bbc_radio_three.isml/bbc_radio_three-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-3.png"), brand: "C1272D"),
            RadioStation(number: 104, name: "BBC Radio 4", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_55057080/live/ww/bbc_radio_fourfm/bbc_radio_fourfm.isml/bbc_radio_fourfm-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-4.png"), brand: "1F5D9E"),
            RadioStation(number: 105, name: "BBC Radio 5 Live", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_89021708/live/ww/bbc_radio_five_live/bbc_radio_five_live.isml/bbc_radio_five_live-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-5-Live.png"), brand: "00A4B4"),
            RadioStation(number: 106, name: "Classic FM", stream: URL(string: "https://media-ssl.musicradio.com/ClassicFMMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Classic-FM.png"), brand: "1B3A6B"),
            RadioStation(number: 107, name: "talkSPORT", stream: URL(string: "https://radio.talksport.com/stream"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Talksport.png"), brand: "E30613"),
            RadioStation(number: 108, name: "Capital", stream: URL(string: "https://media-ssl.musicradio.com/CapitalMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Capital.png"), brand: "0071BB"),
            RadioStation(number: 109, name: "Heart", stream: URL(string: "https://media-ssl.musicradio.com/HeartLondonMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Heart.png"), brand: "E2001A"),
            RadioStation(number: 110, name: "Heart 80s", stream: URL(string: "https://media-ssl.musicradio.com/Heart80sMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Heart-80s.png"), brand: "E2001A"),
            RadioStation(number: 111, name: "Radio X", stream: URL(string: "https://media-ssl.musicradio.com/RadioXLondonMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Radio-X.png"), brand: "111111"),
            RadioStation(number: 112, name: "Capital Xtra", stream: URL(string: "https://media-ssl.musicradio.com/CapitalXTRALondonMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Capital-Xtra.png"), brand: "111111"),
            RadioStation(number: 113, name: "BBC World Service", stream: URL(string: "https://stream.live.vc.bbcmedia.co.uk/bbc_world_service"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-World-Service.png"), brand: "B80000"),
            RadioStation(number: 114, name: "BBC Radio Scotland", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_43322914/live/ww/bbc_radio_scotland_fm/bbc_radio_scotland_fm.isml/bbc_radio_scotland_fm-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-Scotland.png"), brand: "0B4EA2"),
            RadioStation(number: 115, name: "BBC Radio Wales", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_97517794/live/ww/bbc_radio_wales_fm/bbc_radio_wales_fm.isml/bbc_radio_wales_fm-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-Wales.png"), brand: "C8102E"),
            RadioStation(number: 116, name: "BBC Radio Ulster", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_31244774/live/ww/bbc_radio_ulster/bbc_radio_ulster.isml/bbc_radio_ulster-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-Ulster.png"), brand: "0B4EA2"),
            RadioStation(number: 117, name: "BBC Asian Network", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_22108647/live/ww/bbc_asian_network/bbc_asian_network.isml/bbc_asian_network-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Asian-Network.png"), brand: "E5007D"),
            RadioStation(number: 118, name: "BBC Radio 6 Music", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_81827798/live/ww/bbc_6music/bbc_6music.isml/bbc_6music-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-6-Music.png"), brand: "0B7A75"),
            RadioStation(number: 119, name: "Gold", stream: URL(string: "https://media-ssl.musicradio.com/GoldMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Gold-Radio.png"), brand: "B8860B"),
            RadioStation(number: 120, name: "WRN Europe", stream: nil, logo: nil, brand: "1F4FD1"),
            RadioStation(number: 121, name: "LBC", stream: URL(string: "https://media-ssl.musicradio.com/LBCUKMP3Low"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/LBC.png"), brand: "1A1A1A"),
            RadioStation(number: 122, name: "Smooth", stream: URL(string: "https://media-ssl.musicradio.com/SmoothLondonMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Smooth-Radio.png"), brand: "6A1B9A"),
            RadioStation(number: 123, name: "BBC Radio 4 Extra", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_26173715/live/ww/bbc_radio_four_extra/bbc_radio_four_extra.isml/bbc_radio_four_extra-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-4-Extra.png"), brand: "7B1FA2"),
            RadioStation(number: 124, name: "BBC Radio 1Xtra", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_92079267/live/ww/bbc_1xtra/bbc_1xtra.isml/bbc_1xtra-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-1Xtra.png"), brand: "000000"),
            RadioStation(number: 125, name: "Panjab Radio", stream: URL(string: "http://s1.voscast.com:7918/stream"), logo: nil, brand: "E65100"),
            RadioStation(number: 126, name: "BBC Radio nan Gàidheal", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_01935182/live/ww/bbc_radio_nan_gaidheal/bbc_radio_nan_gaidheal.isml/bbc_radio_nan_gaidheal-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-nan-Gaidheal.png"), brand: "0B4EA2"),
            RadioStation(number: 127, name: "BBC Radio 5 Sports Extra", stream: nil, logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-5-Sports-Extra.png"), brand: "00A4B4"),
            RadioStation(number: 128, name: "Heart Dance", stream: URL(string: "https://media-ssl.musicradio.com/HeartDanceMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Heart-Dance.png"), brand: "E2001A"),
            RadioStation(number: 129, name: "BBC Radio London", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_98137350/live/ww/bbc_london/bbc_london.isml/bbc_london-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-London.png"), brand: "0B4EA2"),
            RadioStation(number: 130, name: "BBC Radio Cymru", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_24792333/live/ww/bbc_radio_cymru/bbc_radio_cymru.isml/bbc_radio_cymru-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-Cymru.png"), brand: "C8102E"),
            RadioStation(number: 131, name: "RTÉ Radio 1", stream: URL(string: "https://liveaudio.rte.ie/hls-radio/radio1/chunklist.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/refs/heads/master/Radio/RTE-Radio-1.png"), brand: "00843D"),
            RadioStation(number: 132, name: "RTÉ 2FM", stream: URL(string: "https://liveaudio.rte.ie/hls-radio/2fm/chunklist.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/refs/heads/master/Radio/RTE-2FM.png"), brand: "00843D"),
            RadioStation(number: 133, name: "RTÉ lyric fm", stream: URL(string: "https://icecast.rte.ie/lyric"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/refs/heads/master/Radio/RTE-Lyric-FM.png"), brand: "00843D"),
            RadioStation(number: 134, name: "RTÉ Raidió na Gaeltachta", stream: URL(string: "https://liveaudio.rte.ie/hls-radio/rnag/chunklist.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/refs/heads/master/Radio/RTE-Raidio-na-Gaeltachta.png"), brand: "00843D"),
            RadioStation(number: 135, name: "EWTN Catholic Radio", stream: URL(string: "https://ewtn-ice.streamguys1.com/english-aac"), logo: nil, brand: "1F4FD1"),
            RadioStation(number: 136, name: "BFBS Radio", stream: nil, logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BFBS-Radio.png"), brand: "1F2A44"),
            RadioStation(number: 137, name: "Virgin Radio", stream: URL(string: "https://radio.virginradio.co.uk/stream"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Virgin-Radio-UK.png"), brand: "E10A0A"),
            RadioStation(number: 138, name: "Heart 90s", stream: URL(string: "https://media-ssl.musicradio.com/Heart90sMP3"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/Heart-90s.png"), brand: "E2001A"),
            RadioStation(number: 139, name: "BBC Radio Cymru 2", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_98610936/live/ww/bbc_radio_cymru_2/bbc_radio_cymru_2.isml/bbc_radio_cymru_2-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-Cymru-2.png"), brand: "C8102E"),
            RadioStation(number: 140, name: "BBC Radio Foyle", stream: URL(string: "https://as-hls-ww-live.akamaized.net/pool_43178797/live/ww/bbc_radio_foyle/bbc_radio_foyle.isml/bbc_radio_foyle-audio%3d128000.norewind.m3u8"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/BBC-Radio-Foyle.png"), brand: "0B4EA2"),
            RadioStation(number: 141, name: "LBC News", stream: URL(string: "https://media-ssl.musicradio.com/LBCNewsUK"), logo: URL(string: "https://raw.githubusercontent.com/dp247/mediaportal-uk-logos/master/Radio/LBC-News.png"), brand: "1A1A1A"),
            RadioStation(number: 142, name: "Times Radio", stream: URL(string: "https://timesradio.wireless.radio/stream"), logo: nil, brand: "1A1A1A"),
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.number, $0) })
    }()
}
