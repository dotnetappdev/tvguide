import Foundation

/// A Freeview transmitter region. BBC One, ITV1 and Channel 4 carry regional
/// variations, so each region maps the "big five" slots to its own feed ids.
struct Region: Identifiable, Hashable {
    let id: String
    let name: String
    let bbcOne: String
    var bbcTwo: String = "BBCTwoHD.uk"
    let itv1: String
    var itv1Name: String = "ITV1"
    var itvPlus1: String? = nil
    var itvPlus1Name: String = "ITV1+1"
    let channel4: String
    var channel4Plus1: String? = nil
    var channel4Number: Int = 104
    var extras: [Channel] = []

    static let all: [Region] = [
        Region(id: "london", name: "London", bbcOne: "BBCOneLondonHD.uk",
               itv1: "ITV1London.uk", itvPlus1: "ITV1Plus1London.uk",
               channel4: "Channel4London.uk", channel4Plus1: "Channel4Plus1London.uk"),
        Region(id: "southeast", name: "South East", bbcOne: "BBCOneSouthEast.uk",
               itv1: "ITV1MeridianE.uk", itvPlus1: "ITV1Plus1Meridian.uk",
               channel4: "Channel4South.uk", channel4Plus1: "Channel4Plus1South.uk"),
        Region(id: "south", name: "South", bbcOne: "BBCOneSouth.uk",
               itv1: "ITV1MeridianS.uk", itvPlus1: "ITV1Plus1Meridian.uk",
               channel4: "Channel4South.uk", channel4Plus1: "Channel4Plus1South.uk"),
        Region(id: "east", name: "East", bbcOne: "BBCOneEast.uk",
               itv1: "ITV1Anglia.uk", itvPlus1: "ITV1Plus1London.uk",
               channel4: "Channel4London.uk", channel4Plus1: "Channel4Plus1London.uk"),
        Region(id: "eastmidlands", name: "East Midlands", bbcOne: "BBCOneEastMidlands.uk",
               itv1: "ITV1CentralE.uk", itvPlus1: "ITV1Plus1Midlands.uk",
               channel4: "Channel4Midlands.uk", channel4Plus1: "Channel4Plus1London.uk"),
        Region(id: "westmidlands", name: "West Midlands", bbcOne: "BBCOneWestMidlands.uk",
               itv1: "ITV1CentralW.uk", itvPlus1: "ITV1Plus1Midlands.uk",
               channel4: "Channel4Midlands.uk", channel4Plus1: "Channel4Plus1London.uk"),
        Region(id: "northwest", name: "North West", bbcOne: "BBCOneNorthWest.uk",
               itv1: "ITV1Granada.uk", itvPlus1: "ITV1Plus1Granada.uk",
               channel4: "Channel4North.uk", channel4Plus1: "Channel4Plus1North.uk"),
        Region(id: "yorkshire", name: "Yorkshire", bbcOne: "BBCOneYorkshire.uk",
               itv1: "ITV1YorkshireWest.uk", itvPlus1: "ITV1Plus1Granada.uk",
               channel4: "Channel4North.uk", channel4Plus1: "Channel4Plus1North.uk"),
        Region(id: "northeast", name: "North East & Cumbria", bbcOne: "BBCOneNorthEastCumbria.uk",
               itv1: "ITV1TyneTees.uk", itvPlus1: "ITV1Plus1Granada.uk",
               channel4: "Channel4North.uk", channel4Plus1: "Channel4Plus1North.uk"),
        Region(id: "southwest", name: "South West", bbcOne: "BBCOneSouthWest.uk",
               itv1: "ITV1WestCountry.uk", itvPlus1: "ITV1Plus1Meridian.uk",
               channel4: "Channel4South.uk", channel4Plus1: "Channel4Plus1South.uk"),
        Region(id: "west", name: "West", bbcOne: "BBCOneWest.uk",
               itv1: "ITV1West.uk", itvPlus1: "ITV1Plus1Meridian.uk",
               channel4: "Channel4South.uk", channel4Plus1: "Channel4Plus1South.uk"),
        Region(id: "wales", name: "Wales", bbcOne: "BBCOneWalesHD.uk", bbcTwo: "BBCTwoWales.uk",
               itv1: "ITV1Wales.uk", itvPlus1: "ITV1Plus1London.uk",
               channel4: "Channel4South.uk", channel4Number: 143,
               extras: [Channel(104, "S4C", id: "S4C.uk", .entertainment, brand: "E4003B")]),
        Region(id: "scotland", name: "Scotland (Central)", bbcOne: "BBCOneScotHD.uk",
               itv1: "STVCentral.uk", itv1Name: "STV", itvPlus1: "STVCentralPlus1.uk", itvPlus1Name: "STV+1",
               channel4: "Channel4Scotland.uk", channel4Plus1: "Channel4Plus1Scotland.uk",
               extras: [Channel(144, "BBC Scotland", id: "BBCScotland.uk", .entertainment, hd: true, brand: "1A1A1A"),
                        Channel(145, "BBC ALBA", id: "BBCAlba.uk", .entertainment, hd: true, brand: "0C5DA5")]),
        Region(id: "scotlandnorth", name: "Scotland (North)", bbcOne: "BBCOneScotHD.uk",
               itv1: "STVNorth.uk", itv1Name: "STV", itvPlus1: "STVNorthPlus1.uk", itvPlus1Name: "STV+1",
               channel4: "Channel4Scotland.uk", channel4Plus1: "Channel4Plus1Scotland.uk",
               extras: [Channel(144, "BBC Scotland", id: "BBCScotland.uk", .entertainment, hd: true, brand: "1A1A1A"),
                        Channel(145, "BBC ALBA", id: "BBCAlba.uk", .entertainment, hd: true, brand: "0C5DA5")]),
        Region(id: "ni", name: "Northern Ireland", bbcOne: "BBCOneNorthernIreland.uk", bbcTwo: "BBCTwoNorthernIreland.uk",
               itv1: "UTV.uk", itv1Name: "UTV", itvPlus1: nil,
               channel4: "Channel4Ulster.uk"),
    ]

    static let `default` = all[0]

    static func with(id: String?) -> Region {
        all.first { $0.id == id } ?? .default
    }
}
