package com.dotnetappdev.tvguide.data

import java.time.Duration
import java.time.Instant

/** Plausible listings so the guide is usable when the live feed can't be reached. */
object SampleSchedule {
    private val titles = mapOf(
        ChannelCategory.ENTERTAINMENT to listOf("The Great British Menu" to 60, "Pointless" to 45, "Emmerdale" to 30,
            "The Chase" to 60, "Gogglebox" to 60, "Ghosts" to 30, "Would I Lie to You?" to 30, "Taskmaster" to 60,
            "Coronation Street" to 30, "EastEnders" to 30, "QI" to 45),
        ChannelCategory.FILMS to listOf("Paddington 2" to 120, "The Italian Job" to 105, "Notting Hill" to 135, "Hot Fuzz" to 125),
        ChannelCategory.FACTUAL to listOf("Planet Earth III" to 60, "Grand Designs" to 60, "Countryfile" to 60, "Abandoned Engineering" to 60),
        ChannelCategory.NEWS to listOf("The Latest" to 30, "Business Today" to 30, "World Report" to 60, "Weather" to 15),
        ChannelCategory.KIDS to listOf("Hey Duggee" to 15, "Bluey" to 15, "Newsround" to 15, "Blue Peter" to 30),
    )

    fun make(channels: List<Channel>, around: Instant = Instant.now()): Map<String, List<Programme>> {
        val result = HashMap<String, List<Programme>>()
        val end = around.plus(Duration.ofDays(2))
        channels.forEachIndexed { index, channel ->
            val pool = titles[channel.category] ?: titles.getValue(ChannelCategory.ENTERTAINMENT)
            var cursor = alignedDown(around.minus(Duration.ofHours(6)), 30)
            var i = index * 3
            val listings = ArrayList<Programme>()
            while (cursor.isBefore(end)) {
                val (title, minutes) = pool[i % pool.size]
                val next = cursor.plus(Duration.ofMinutes(minutes.toLong()))
                listings += Programme(channel.id, title,
                    synopsis = "Sample listing. Connect your Fire TV to the internet to load the live guide.",
                    start = cursor, end = next, episode = if (minutes <= 60) "S${1 + i % 9} E${1 + i % 12}" else null,
                    isNew = i % 5 == 0)
                cursor = next
                i++
            }
            result[channel.id] = listings
        }
        return result
    }

    fun alignedDown(instant: Instant, minutes: Int): Instant {
        val step = minutes * 60L
        return Instant.ofEpochSecond(Math.floorDiv(instant.epochSecond, step) * step)
    }
}
