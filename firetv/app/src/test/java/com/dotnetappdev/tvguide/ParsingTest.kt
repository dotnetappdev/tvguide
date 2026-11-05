package com.dotnetappdev.tvguide

import com.dotnetappdev.tvguide.data.Channel
import com.dotnetappdev.tvguide.data.ChannelCategory
import com.dotnetappdev.tvguide.data.ChannelLineup
import com.dotnetappdev.tvguide.data.ChannelMatcher
import com.dotnetappdev.tvguide.data.ChannelsDvr
import com.dotnetappdev.tvguide.data.M3uPlaylist
import com.dotnetappdev.tvguide.data.Region
import com.dotnetappdev.tvguide.data.SkyEpgService
import com.dotnetappdev.tvguide.data.XmltvParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class ParsingTest {
    private val xml = """
        <tv>
          <channel id="BBCTwoHD.uk"><display-name>BBC Two HD</display-name><icon src="http://logo/bbc2.png"/></channel>
          <channel id="Other.uk"><display-name>Other</display-name></channel>
          <programme channel="BBCTwoHD.uk" start="20261008220000 +0100" stop="20261008233000 +0100">
            <title>New: George Clarke's Amazing...</title>
            <desc>...Spaces: First Home: George discovers a floating home.</desc>
            <icon src="http://img/1.jpg"/><episode-num system="onscreen">S1E4</episode-num><premiere/>
          </programme>
          <programme channel="BBCTwoHD.uk" start="20261008230000 +0100" stop="20261008235000 +0100"><title>Overlap</title></programme>
          <programme channel="BBCTwoHD.uk" start="20261008233000 +0100" stop="20261009000000 +0100">
            <title>Late</title><episode-num system="xmltv_ns">16.2.0/1</episode-num>
          </programme>
          <programme channel="Other.uk" start="20261008220000 +0100" stop="20261008233000 +0100"><title>Skip</title></programme>
        </tv>
    """.trimIndent()

    @Test fun parsesWantedChannelsAndCleansListings() {
        val doc = XmltvParser.parse(xml.byteInputStream(), setOf("BBCTwoHD.uk"))
        val list = doc.programmes.getValue("BBCTwoHD.uk")
        assertEquals(listOf("New: George Clarke's Amazing Spaces", "Late"), list.map { it.title }) // overlap dropped
        assertEquals("First Home: George discovers a floating home.", list[0].synopsis)
        assertEquals("S1 E4", list[0].episode)
        assertTrue(list[0].isNew)
        assertEquals("S17 E3", list[1].episode)
        assertEquals(Instant.parse("2026-10-08T21:00:00Z"), list[0].start)
        assertEquals("http://logo/bbc2.png", doc.logos["BBCTwoHD.uk"])
        assertNull(doc.programmes["Other.uk"])
    }

    @Test fun episodeLabels() {
        assertEquals("Ep 17", XmltvParser.episodeLabel("S2026E17", null))
        assertEquals("S5 E5", XmltvParser.episodeLabel(null, "4.4.0"))
        assertNull(XmltvParser.episodeLabel(null, null))
    }

    @Test fun matchesTunerNames() {
        val m = ChannelMatcher(ChannelLineup.channels(Region.default))
        val cases = mapOf("BBC ONE Lon HD" to "BBC One", "ITV1 HD" to "ITV1", "Channel 5 HD" to "5", "E4 Extra" to "E4 Extra",
            "E4" to "E4", "ITV+1 London" to "ITV1+1", "Channel 4+1" to "Channel 4+1", "Dave" to "U&Dave", "BBC NEWS HD" to "BBC News")
        for ((tuner, ours) in cases) assertEquals(tuner, ours, m.match(tuner)?.name)
        assertNull(m.match("ITVBe"))
    }

    @Test fun parsesPlaylists() {
        val text = """
            #EXTM3U url-tvg="http://x/guide.xml"
            #EXTINF:-1 tvg-id="BBCOneLondonHD.uk" tvg-chno="1" tvg-name="BBC One HD",BBC One HD
            http://dvr/1.m3u8
            #EXTINF:-1 tvg-chno="2",BBC TWO HD
            http://dvr/2.m3u8
            #EXTINF:-1,ITV1 London HD
            http://dvr/3.m3u8
        """.trimIndent()
        val p = M3uPlaylist.parse(text)
        assertEquals("http://x/guide.xml", p.guideUrl)
        val streams = p.streams(ChannelLineup.channels(Region.default))
        assertEquals("http://dvr/1.m3u8", streams["BBCOneLondonHD.uk"])
        assertEquals("http://dvr/2.m3u8", streams["BBCTwoHD.uk"])
        assertEquals("http://dvr/3.m3u8", streams["ITV1London.uk"])
    }

    @Test fun serverAddresses() {
        assertEquals("http://192.168.1.20:8089", ChannelsDvr.serverUrl("192.168.1.20"))
        assertEquals("http://dvr.local:9000", ChannelsDvr.serverUrl("http://dvr.local:9000/x"))
        assertEquals("http://192.168.1.20:8089/devices/ANY/channels.m3u?format=hls", ChannelsDvr.playlistUrl("http://192.168.1.20:8089"))
    }

    @Test fun skyNames() {
        assertEquals("Sky Sports Main Event", SkyEpgService.prettyName("SkySpMainEvHD", 401))
        assertEquals("Sky Sports Premier League", SkyEpgService.prettyName("SkySp PL HD", 402))
        assertEquals("Sky Cinema Action", SkyEpgService.prettyName("Sky Action HD", 306))
        assertEquals("Sky Documentaries", SkyEpgService.prettyName("SkyDocmntrsHD", 114))
        assertEquals("Main Event", Channel(401, "Sky Sports Main Event", "sky:1", ChannelCategory.SPORT).monogram)
    }

    @Test fun lineupHasUniqueOrder() {
        for (region in Region.all) {
            val list = ChannelLineup.channels(region)
            assertEquals(region.id, list.size, list.map { it.number }.toSet().size)
            assertEquals("BBC One", list.first().name)
        }
    }
}
