package com.dotnetappdev.tvguide.data

import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.time.Instant

/** Where live TV pictures come from. */
sealed interface LiveSource {
    /** Channels DVR server: its HLS playlist plus its guide. */
    data class ChannelsDvr(val server: String) : LiveSource
    /** Any M3U playlist (Jellyfin, Plex, TVHeadend, IPTV). */
    data class Playlist(val url: String) : LiveSource

    val label: String
        get() = when (this) {
            is ChannelsDvr -> "Channels DVR at ${host(server)}"
            is Playlist -> "Playlist"
        }

    companion object {
        fun host(url: String) = runCatching { URI(url).host }.getOrNull() ?: url
    }
}

/** A live TV source's streams and guide, mapped onto the guide's channels. */
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

object PlaylistSource {
    suspend fun load(url: String, channels: List<Channel>): TunerData {
        val playlist = M3uPlaylist.load(url)
        val guide = playlist.guideUrl?.let { guideUrl ->
            runCatching { Http.get(guideUrl).inputStream().use { XmltvParser.parseMatchingNames(it, channels) } }.getOrNull()
        } ?: emptyMap()
        return TunerData(playlist.streams(channels), guide)
    }
}
