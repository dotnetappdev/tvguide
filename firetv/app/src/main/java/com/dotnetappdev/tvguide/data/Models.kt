package com.dotnetappdev.tvguide.data

import java.time.Instant
import java.time.Duration

/** Groups used by the sidebar to filter the guide. */
enum class ChannelCategory(val title: String) {
    ALL("All channels"),
    FAVOURITES("Favourites"),
    ENTERTAINMENT("Entertainment"),
    FILMS("Movies"),
    SPORT("Sports"),
    FACTUAL("Documentaries"),
    NEWS("News"),
    KIDS("Kids"),
    RADIO("Radio");

    companion object {
        val filters = entries.toList()
    }
}

/** A TV or radio channel in the guide. */
data class Channel(
    /** Position in the guide, following Sky's channel order. Used only for sorting; never shown. */
    val number: Int,
    val name: String,
    /** The XMLTV id from the Freeview feed, "sky:<sid>" for Sky channels or "radio:<key>". */
    val id: String,
    val category: ChannelCategory,
    val hd: Boolean = false,
    /** Brand colour as RRGGBB, used for fallback logos and tile gradients. */
    val brand: String = "1F4FD1",
    val logo: String? = null,
) {
    val isRadio: Boolean get() = category == ChannelCategory.RADIO

    /** Short label for the fallback logo, e.g. "F1" for Sky Sports F1. */
    val monogram: String
        get() {
            if (name.startsWith("TNT Sports ")) return "TNT " + name.removePrefix("TNT Sports ")
            for (prefix in listOf("Sky Sports ", "Sky Cinema ", "Sky ")) {
                if (name.startsWith(prefix)) return name.removePrefix(prefix)
            }
            val words = name.split(" ").filter { it.isNotEmpty() }
            val first = words.firstOrNull() ?: return name
            return if (first.length <= 4) first else words.take(2).joinToString("") { it.take(1) }
        }
}

/** A single listing in the guide. */
data class Programme(
    val channelId: String,
    val title: String,
    val subtitle: String? = null,
    val synopsis: String? = null,
    val start: Instant,
    val end: Instant,
    val image: String? = null,
    /** e.g. "S17 E3". */
    val episode: String? = null,
    val isNew: Boolean = false,
    /** Filler covering a hole in the listings. */
    val isPlaceholder: Boolean = false,
) {
    val id: String = "$channelId|${start.epochSecond}"
    val duration: Duration get() = Duration.between(start, end)

    fun isOn(at: Instant) = !start.isAfter(at) && at.isBefore(end)

    fun progress(at: Instant): Float {
        val total = duration.seconds.toFloat()
        if (total <= 0f) return 0f
        return (Duration.between(start, at).seconds / total).coerceIn(0f, 1f)
    }

    fun overlaps(from: Instant, to: Instant) = start.isBefore(to) && end.isAfter(from)

    fun reassigned(to: String) = copy(channelId = to)

    companion object {
        fun placeholder(channelId: String, start: Instant, end: Instant) =
            Programme(channelId, "No information available", start = start, end = end, isPlaceholder = true)
    }
}

/**
 * A Freeview transmitter region. BBC One, ITV1 and Channel 4 carry regional
 * variations, so each region maps those slots to its own feed ids.
 */
data class Region(
    val id: String,
    val name: String,
    val bbcOne: String,
    val bbcTwo: String = "BBCTwoHD.uk",
    val itv1: String,
    val itv1Name: String = "ITV1",
    val itvPlus1: String? = null,
    val itvPlus1Name: String = "ITV1+1",
    val channel4: String,
    val channel4Plus1: String? = null,
    val channel4Number: Int = 104,
    val extras: List<Channel> = emptyList(),
) {
    companion object {
        val all get() = ALL_REGIONS
        val default get() = ALL_REGIONS.first()
        fun withId(id: String?) = ALL_REGIONS.firstOrNull { it.id == id } ?: default
    }
}

/** UK free-to-air line-up in Sky's order; regional channels swapped in per region. */
object ChannelLineup {
    fun channels(region: Region): List<Channel> {
        val list = baseLineup(region)
        region.itvPlus1?.let { list += Channel(203, region.itvPlus1Name, it, ChannelCategory.ENTERTAINMENT, brand = "0AA8A0") }
        region.channel4Plus1?.let { list += Channel(204, "Channel 4+1", it, ChannelCategory.ENTERTAINMENT, brand = "1F2A44") }
        list += region.extras
        val seen = HashSet<String>()
        return list.filter { seen.add(it.id) }.sortedWith(compareBy({ it.number }, { it.name }))
    }
}

/** A station in Sky's radio list (BBC Radio 1 … Times Radio), with its public stream. */
data class RadioStation(val number: Int, val name: String, val stream: String?, val logo: String?, val brand: String)

sealed interface RadioSource {
    data class Stream(val url: String) : RadioSource
    /** Rayo (formerly Bauer) station code, e.g. "abr" for Absolute Radio. */
    data class Rayo(val code: String) : RadioSource
}

/** Further UK stations beyond Sky's list: national, BBC local and regional. */
data class CatalogueStation(
    val number: Int,
    val id: String,
    val name: String,
    val region: String,
    val tagline: String?,
    val source: RadioSource,
) {
    val rayoCode: String? get() = (source as? RadioSource.Rayo)?.code
    val fixedStream: String? get() = (source as? RadioSource.Stream)?.url
}
