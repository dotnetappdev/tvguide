package com.dotnetappdev.tvguide.data

import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.time.Instant

/** Where live TV pictures come from. */
sealed interface LiveSource {
    /** Channels DVR server: HLS playlist plus the guide it reads from the aerial. */
    data class ChannelsDvr(val server: String) : LiveSource
    /**
     * HDHomeRun tuner used directly. Fire TV's player (ExoPlayer) plays the
     * tuner's MPEG-TS streams, so no Channels DVR is needed here.
     */
    data class HdHomeRun(val baseUrl: String) : LiveSource
    /** Any M3U playlist (Jellyfin, Plex, TVHeadend, IPTV). */
    data class Playlist(val url: String) : LiveSource

    val label: String
        get() = when (this) {
            is ChannelsDvr -> "Channels DVR at ${host(server)}"
            is HdHomeRun -> "HDHomeRun at ${host(baseUrl)}"
            is Playlist -> "Playlist"
        }

    companion object {
        fun host(url: String) = runCatching { URI(url).host }.getOrNull() ?: url
    }
}

/** A tuner's channel list and guide, mapped onto the guide's channels. */
class TunerData(val streams: Map<String, String>, val guide: Map<String, List<Programme>>)

object ChannelsDvr {
    const val DEFAULT_PORT = 8089

    /** Accepts "192.168.1.20", "192.168.1.20:8089" or a full URL. */
    fun serverUrl(input: String, defaultPort: Int = DEFAULT_PORT): String? {
        var text = input.trim()
        if (text.isEmpty()) return null
        if (!text.contains("://")) text = "http://$text"
        return runCatching {
            val uri = URI(text)
            val host = uri.host ?: return null
            val port = if (uri.port > 0) uri.port else defaultPort
            "${uri.scheme}://$host:$port"
        }.getOrNull()
    }

    fun playlistUrl(server: String) = "$server/devices/ANY/channels.m3u?format=hls"

    suspend fun load(server: String, channels: List<Channel>, now: Instant = Instant.now()): TunerData {
        val playlist = M3uPlaylist.parse(Http.getText(playlistUrl(server), 8_000))
        if (playlist.entries.isEmpty()) error("No channels found on that server")
        val streams = playlist.streams(channels)
        val guide = runCatching { guide(server, channels, now) }.getOrDefault(emptyMap())
        return TunerData(streams, guide)
    }

    /** `/devices/ANY/guide?time=…&duration=…` in 8 hour blocks (as the Channels apps request it). */
    private suspend fun guide(server: String, channels: List<Channel>, now: Instant): Map<String, List<Programme>> {
        val matcher = ChannelMatcher(channels)
        val result = HashMap<String, MutableList<Programme>>()
        var start = now.minusSeconds(3600)
        repeat(3) {
            val json = JSONArray(Http.getText("$server/devices/ANY/guide?time=${start.epochSecond}&duration=28800"))
            for (i in 0 until json.length()) {
                val entry = json.optJSONObject(i) ?: continue
                val info = entry.optJSONObject("Channel") ?: continue
                val channel = matcher.match(info.optString("Name").ifEmpty { info.optString("CallSign") }) ?: continue
                val airings = entry.optJSONArray("Airings") ?: continue
                for (j in 0 until airings.length()) {
                    val a = airings.optJSONObject(j) ?: continue
                    val time = a.optDouble("Time", Double.NaN).takeIf { !it.isNaN() } ?: continue
                    val duration = a.optDouble("Duration", 0.0).takeIf { it > 0 } ?: continue
                    val from = Instant.ofEpochSecond(time.toLong())
                    result.getOrPut(channel.id) { mutableListOf() } += Programme(channel.id, a.optString("Title", "Untitled"),
                        subtitle = a.optString("EpisodeTitle").ifEmpty { null }, synopsis = a.optString("Summary").ifEmpty { null },
                        start = from, end = from.plusSeconds(duration.toLong()), image = a.optString("Image").ifEmpty { null })
                }
            }
            start = start.plusSeconds(28800)
        }
        return result.mapValues { (_, list) -> list.sortedBy { it.start }.distinctBy { it.start } }
    }
}

/** SiliconDust HDHomeRun network tuners (e.g. HDHomeRun FLEX DUO / QUATTRO for Freeview). */
object HdHomeRun {
    data class Device(val name: String, val baseUrl: String)

    /** Tuners on the same internet connection, via SiliconDust's discovery service. */
    suspend fun discover(): List<Device> = runCatching {
        val array = JSONArray(Http.getText("https://api.hdhomerun.com/discover", 8_000))
        (0 until array.length()).mapNotNull { i ->
            val o = array.optJSONObject(i) ?: return@mapNotNull null
            val base = o.optString("BaseURL").ifEmpty { o.optString("LocalIP").ifEmpty { null }?.let { "http://$it" } }
                ?: return@mapNotNull null
            if (o.has("StorageID")) return@mapNotNull null // a DVR record engine, not a tuner
            Device(o.optString("FriendlyName").ifEmpty { "HDHomeRun" }, base)
        }
    }.getOrDefault(emptyList())

    /** Accepts "192.168.1.40" or a full URL. */
    fun baseUrl(input: String): String? = ChannelsDvr.serverUrl(input, defaultPort = 80)?.removeSuffix(":80")

    suspend fun load(baseUrl: String, channels: List<Channel>): TunerData {
        val lineup = JSONArray(Http.getText("$baseUrl/lineup.json", 8_000))
        val matcher = ChannelMatcher(channels)
        val streams = LinkedHashMap<String, String>()
        val names = HashMap<String, String>() // GuideNumber → our channel id
        for (i in 0 until lineup.length()) {
            val o = lineup.optJSONObject(i) ?: continue
            val channel = matcher.match(o.optString("GuideName")) ?: continue
            val url = o.optString("URL").ifEmpty { null } ?: continue
            if (streams.putIfAbsent(channel.id, url) == null) names[o.optString("GuideNumber")] = channel.id
        }
        if (streams.isEmpty()) error("The tuner didn't list any channels yet – run a channel scan in the HDHomeRun app")
        val guide = runCatching { guide(baseUrl, names) }.getOrDefault(emptyMap())
        return TunerData(streams, guide)
    }

    /** The tuner's own guide (SiliconDust's guide service, read from the aerial / their data). */
    private suspend fun guide(baseUrl: String, names: Map<String, String>): Map<String, List<Programme>> {
        val auth = JSONObject(Http.getText("$baseUrl/discover.json", 8_000)).optString("DeviceAuth").ifEmpty { null } ?: return emptyMap()
        val array = JSONArray(Http.getText("https://api.hdhomerun.com/api/guide.php?DeviceAuth=$auth"))
        val result = HashMap<String, List<Programme>>()
        for (i in 0 until array.length()) {
            val ch = array.optJSONObject(i) ?: continue
            val id = names[ch.optString("GuideNumber")] ?: continue
            val items = ch.optJSONArray("Guide") ?: continue
            result[id] = (0 until items.length()).mapNotNull { j ->
                val g = items.optJSONObject(j) ?: return@mapNotNull null
                val from = g.optLong("StartTime").takeIf { it > 0 } ?: return@mapNotNull null
                val to = g.optLong("EndTime").takeIf { it > from } ?: return@mapNotNull null
                Programme(id, g.optString("Title", "Untitled"), subtitle = g.optString("EpisodeTitle").ifEmpty { null },
                    synopsis = g.optString("Synopsis").ifEmpty { null }, start = Instant.ofEpochSecond(from),
                    end = Instant.ofEpochSecond(to), image = g.optString("ImageURL").ifEmpty { null })
            }.sortedBy { it.start }
        }
        return result
    }
}

object PlaylistSource {
    suspend fun load(url: String, channels: List<Channel>): TunerData {
        val playlist = M3uPlaylist.load(url)
        val guide = playlist.guideUrl?.let { guideUrl ->
            runCatching { Http.get(guideUrl).inputStream().use { XmltvParser.parseMatchingNames(it, channels) } }.getOrNull()
        } ?: emptyMap()
        return TunerData(playlist.streams(channels), guide)
    }
}
