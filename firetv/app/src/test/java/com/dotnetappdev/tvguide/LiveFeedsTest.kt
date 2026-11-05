package com.dotnetappdev.tvguide

import com.dotnetappdev.tvguide.data.ChannelLineup
import com.dotnetappdev.tvguide.data.EpgService
import com.dotnetappdev.tvguide.data.RADIO_CATALOGUE
import com.dotnetappdev.tvguide.data.RayoService
import com.dotnetappdev.tvguide.data.Region
import com.dotnetappdev.tvguide.data.SkyEpgService
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.nio.file.Files

/** Hits the real Freeview, Sky and Rayo feeds. Run with `LIVE_FEEDS=1 ./gradlew test`. */
class LiveFeedsTest {
    private fun live() = assumeTrue("set LIVE_FEEDS=1 to run", System.getenv("LIVE_FEEDS") == "1")

    @Test fun freeviewFeed() = runBlocking {
        live()
        val ids = ChannelLineup.channels(Region.default).map { it.id }.toSet()
        val snap = EpgService(Files.createTempDirectory("epg").toFile()).load(ids)
        println("Freeview: ${snap.programmes.size} of ${ids.size} channels, ${snap.logos.size} logos")
        assertTrue(snap.programmes.size >= ids.size - 2)
    }

    @Test fun skyFeed() = runBlocking {
        live()
        val used = ChannelLineup.channels(Region.default).map { it.number }.toSet()
        val (channels, programmes) = SkyEpgService().load(used, includeTv = true)
        println("Sky: ${channels.count { !it.isRadio }} TV + ${channels.count { it.isRadio }} radio, listings for ${programmes.size}")
        assertTrue(channels.any { it.name == "Sky Sports Main Event" })
        assertTrue(channels.count { it.isRadio } >= 40)
    }

    @Test fun rayoFeed() = runBlocking {
        live()
        val codes = RADIO_CATALOGUE.mapNotNull { s -> s.rayoCode?.let { it to s.id } }.toMap()
        val stations = RayoService().stations(codes.keys, codes)
        println("Rayo: ${stations.size} of ${codes.size}; Absolute: ${stations["abr"]?.onAir?.title} / ${stations["abr"]?.nowPlaying}")
        assertTrue(stations.size >= codes.size - 3)
        assertTrue(stations.getValue("abr").streams.isNotEmpty())
    }
}
