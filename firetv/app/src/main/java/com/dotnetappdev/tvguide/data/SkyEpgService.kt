package com.dotnetappdev.tvguide.data

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Sky's channel line-up and listings (Sky Cinema, Sky Sports, TNT Sports, Sky
 * entertainment, documentaries, kids, news and radio) from the JSON guide
 * behind sky.com/tv-guide. Unofficial, so it may change without notice.
 */
class SkyEpgService {
    data class Service(val sid: String, val c: String, val t: String, val sg: Int?, val adult: Boolean)

    private var cachedServices: List<Service>? = null

    suspend fun load(excludingNumbers: Set<Int>, includeTv: Boolean, around: Instant = Instant.now()):
        Pair<List<Channel>, Map<String, List<Programme>>> {
        val services = services()
        val channels = (if (includeTv) skyChannels(services, excludingNumbers) else emptyList()) + radioChannels(services)
        if (channels.isEmpty()) return channels to emptyMap()
        val programmes = HashMap<String, MutableList<Programme>>()
        val sids = channels.map { it.id.removePrefix("sky:") }
        for (day in dayStrings(around)) {
            for (chunk in sids.chunked(20)) {
                val json = JSONObject(Http.getText("$BASE/schedule/$day/${chunk.joinToString(",")}"))
                val schedule = json.optJSONArray("schedule") ?: continue
                for (i in 0 until schedule.length()) {
                    val entry = schedule.getJSONObject(i)
                    val id = "sky:" + entry.getString("sid")
                    val events = entry.optJSONArray("events") ?: continue
                    for (j in 0 until events.length()) programmes.getOrPut(id) { mutableListOf() } += programme(events.getJSONObject(j), id)
                }
            }
        }
        return channels to programmes.mapValues { (_, list) -> list.sortedBy { it.start }.distinctBy { it.start } }
    }

    private suspend fun services(): List<Service> {
        cachedServices?.let { return it }
        val array = JSONObject(Http.getText("$BASE/services/$BOUQUET")).getJSONArray("services")
        val list = (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            Service(o.getString("sid"), o.getString("c"), o.getString("t"),
                if (o.has("sg")) o.optInt("sg") else null, o.optBoolean("adult", false))
        }
        cachedServices = list
        return list
    }

    companion object {
        const val BASE = "https://awk.epgsky.com/hawk/linear"
        /** Sky's London HD bouquet; national channels are the same everywhere. */
        const val BOUQUET = "4101/1"

        private val factualWords = listOf("Docmntrs", "History", "Nature", "Discovery", "Disc.", "Nat Geo", "NatGeo",
            "Animal", "Crime+Inv", "ID", "PBS", "Travelxp", "Science", "Eden")

        /** Every Sky TV channel not already in the free line-up (radio, adult, +1, PPV, shopping, religious left out). */
        fun skyChannels(services: List<Service>, excluding: Set<Int>): List<Channel> {
            val numbers = excluding.toMutableSet()
            val result = ArrayList<Channel>()
            for (s in services) {
                if (s.c.startsWith("0") || s.sg == 4 || s.sg == 0 || s.adult) continue
                val number = s.c.toIntOrNull() ?: continue
                if (number in numbers) continue
                if (s.t.contains("+1") || s.t.contains("BoxOff") || s.t.endsWith("+")) continue
                val category = category(number, s.t) ?: continue
                numbers += number
                result += Channel(number, prettyName(s.t, number), "sky:${s.sid}", category, hd = s.t.endsWith("HD"),
                    brand = when (category) { ChannelCategory.SPORT -> "C8102E"; ChannelCategory.FILMS -> "5B2D8E"; else -> "0A6CFF" })
            }
            return result.sortedBy { it.number }
        }

        /** Sky's radio stations, with names, logos and streams from the radio tables. */
        fun radioChannels(services: List<Service>): List<Channel> = services.mapNotNull { s ->
            if (s.sg != 4 || !s.c.startsWith("0")) return@mapNotNull null
            val number = s.c.toIntOrNull() ?: return@mapNotNull null
            val station = SKY_RADIO[number]
            Channel(number, station?.name ?: s.t, "sky:${s.sid}", ChannelCategory.RADIO,
                brand = station?.brand ?: "1F4FD1", logo = station?.logo)
        }.sortedBy { it.number }

        private fun category(number: Int, name: String): ChannelCategory? = when (number) {
            in 106..299 -> if (factualWords.any { w -> if (w.length <= 3) name == w || name.startsWith("$w ") else name.contains(w) })
                ChannelCategory.FACTUAL else ChannelCategory.ENTERTAINMENT
            in 301..349 -> ChannelCategory.FILMS
            in 350..379 -> ChannelCategory.ENTERTAINMENT
            in 401..489 -> ChannelCategory.SPORT
            in 501..579 -> ChannelCategory.NEWS
            in 601..639 -> ChannelCategory.KIDS
            else -> null
        }

        /** Expands Sky's abbreviated names, e.g. "SkySpMainEvHD" → "Sky Sports Main Event". */
        fun prettyName(raw: String, number: Int): String {
            var name = raw.removeSuffix("HD").trim()
            val replacements = listOf(
                "SkySp" to "Sky Sports ", "MainEv" to "Main Event", "F'ball" to "Football",
                "ComedyCent" to "Comedy Central", "ComedyXtra" to "Comedy Central Extra", "Disc." to "Discovery ",
                "NatGeoWild" to "Nat Geo Wild", "Crime+Inv" to "Crime+Investigation", "Cartoon Net" to "Cartoon Network",
                "TRUE CRIME X" to "True Crime Xtra", "TRUE CRIME" to "True Crime", "NOW ROCK" to "Now Rock",
                "BBCScotland" to "BBC Scotland", "U&DaveJaVu" to "U&Dave ja vu", "Great!Christmas" to "Great! Christmas",
                "LEGEND XTRA" to "Legend Xtra", "TNTSports" to "TNT Sports ", "SkyPremiere" to "Sky Cinema Premiere",
                "SkyAnimation" to "Sky Cinema Animation", "SkyDocmntrs" to "Sky Documentaries", "Disney+Cine" to "Disney+ Cinema",
            )
            for ((from, to) in replacements) name = name.replace(from, to)
            name = name.replace("  ", " ").replace("Sports +", "Sports+").replace("Sports PL", "Sports Premier League").trim()
            if (number in 301..312) {
                if (name.startsWith("Sky ") && !name.startsWith("Sky Cinema")) name = "Sky Cinema " + name.removePrefix("Sky ")
                else if (!name.startsWith("Sky") && !name.contains("Disney")) name = "Sky Cinema $name"
            }
            return name
        }

        private fun programme(e: JSONObject, channelId: String): Programme {
            val start = Instant.ofEpochSecond(e.getLong("st"))
            val season = if (e.has("seasonnumber")) e.optInt("seasonnumber") else null
            val episode = if (e.has("episodenumber")) e.optInt("episodenumber") else null
            val label = when {
                season != null && episode != null && season < 1900 -> "S$season E$episode"
                episode != null -> "Ep $episode"
                else -> null
            }
            val uuid = e.optString("programmeuuid").ifEmpty { null }
            return Programme(channelId, e.optString("t", "Untitled"), synopsis = e.optString("sy").ifEmpty { null },
                start = start, end = start.plusSeconds(e.optLong("d")),
                image = uuid?.let { "https://images.metadata.sky.com/pd-image/$it/16-9/640" },
                episode = label, isNew = e.optBoolean("new", false))
        }

        /** Today and tomorrow in UK time, as yyyyMMdd. */
        fun dayStrings(around: Instant): List<String> {
            val uk = around.atZone(ZoneId.of("Europe/London")).toLocalDate()
            val f = DateTimeFormatter.ofPattern("yyyyMMdd")
            return listOf(uk.format(f), uk.plusDays(1).format(f))
        }

        @Suppress("unused") private fun JSONArray.objects() = (0 until length()).map { getJSONObject(it) }
    }
}
