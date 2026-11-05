package com.dotnetappdev.tvguide

import com.dotnetappdev.tvguide.data.ChannelCategory
import com.dotnetappdev.tvguide.data.EpgService
import com.dotnetappdev.tvguide.data.EpgSnapshot
import com.dotnetappdev.tvguide.data.EpgSource
import com.dotnetappdev.tvguide.data.Programme
import com.dotnetappdev.tvguide.data.SampleSchedule
import com.dotnetappdev.tvguide.store.GuideViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.time.Duration
import java.time.Instant

class GuideViewModelTest {
    private val now = Instant.parse("2026-10-09T18:50:00Z")

    private fun model(): GuideViewModel {
        val vm = GuideViewModel(FakePrefs(), EpgService(Files.createTempDirectory("epg").toFile()), clock = { now })
        val listings = SampleSchedule.make(vm.channels, now).toMutableMap()
        // A gap and an overlap to exercise the filler logic.
        val bbc2 = vm.channels[1].id
        listings[bbc2] = listOf(
            Programme(bbc2, "A", start = now.minus(Duration.ofMinutes(50)), end = now.plus(Duration.ofMinutes(10))),
            Programme(bbc2, "B", start = now.plus(Duration.ofMinutes(25)), end = now.plus(Duration.ofMinutes(55))),
        )
        vm.apply(EpgSnapshot(listings, emptyMap(), EpgSource.Live(now)))
        return vm
    }

    @Test fun rowsTileTheWindowWithStableIds() {
        val vm = model()
        repeat(20) { step ->
            for (c in vm.channels) {
                val segs = vm.segments(c)
                var cursor = vm.windowStart
                for (s in segs) {
                    val a = maxOf(s.start, vm.windowStart)
                    val b = minOf(s.end, vm.windowEnd)
                    assertEquals("${c.name} step $step", cursor, a)
                    assertTrue(b.isAfter(a))
                    cursor = b
                }
                assertEquals(vm.windowEnd, cursor)
                assertEquals(segs.size, segs.map { it.id }.toSet().size)
            }
            vm.shiftWindow(if (step < 15) 1 else -1)
        }
    }

    @Test fun windowClampsToNow() {
        val vm = model()
        assertTrue(vm.isAtNow)
        assertFalse(vm.shiftWindow(-1))
        assertTrue(vm.shiftWindow(2))
        assertFalse(vm.isAtNow)
        vm.jumpToNow()
        assertTrue(vm.isAtNow)
    }

    @Test fun radioIsSeparateFromTv() {
        val vm = model()
        assertTrue(vm.visibleChannels.none { it.isRadio })
        vm.category = ChannelCategory.RADIO
        assertTrue(vm.visibleChannels.all { it.isRadio })
        assertTrue(vm.visibleChannels.size > 100)
        val firstRadio = vm.channels.indexOfFirst { it.isRadio }
        assertTrue(vm.channels.drop(firstRadio).all { it.isRadio })
        val bbcOne = vm.channels.first()
        assertEquals("BBC One", bbcOne.name)
        assertEquals("BBC Two", vm.channelAfter(bbcOne, 1)!!.name)
        assertFalse(vm.channelAfter(bbcOne, -1)!!.isRadio)
    }

    @Test fun searchFindsChannelsAndProgrammes() {
        val vm = model()
        assertEquals(listOf("BBC One"), vm.search("bbc one").channels.map { it.name })
        assertTrue(vm.search("pointless").let { it.onNow.size + it.later.size } > 0)
        assertTrue(vm.search("").isEmpty)
    }

    @Test fun radioStationsHaveStreams() {
        val vm = model()
        val radio = vm.channels.filter { it.isRadio && !it.id.startsWith("sky:") }
        val fixed = radio.filter { vm.streams(it).isNotEmpty() }
        assertTrue("catalogue BBC/Global stations should have fixed streams", fixed.size >= 60)
    }
}
