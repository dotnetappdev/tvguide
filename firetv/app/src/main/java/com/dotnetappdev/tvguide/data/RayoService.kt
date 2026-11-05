package com.dotnetappdev.tvguide.data

import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Station details from Rayo (formerly Bauer: Absolute Radio, KISS, Magic,
 * Greatest Hits, Hits Radio, Cool FM, Clyde 1 …) via the station list its own
 * apps use: current streams, logo, brand colour, show on air and song playing.
 * Unofficial, so it may change; Rayo's streams only play in the UK.
 */
class RayoService {
    data class Station(
        val code: String,
        val streams: List<String>,
        val logo: String?,
        val colour: String?,
        val strapline: String?,
        val onAir: Programme?,
        val nowPlaying: String?,
    )

    /** One request for the main stations, then one per regional station (only returned individually). */
    suspend fun stations(codes: Set<String>, channelIds: Map<String, String>): Map<String, Station> = coroutineScope {
        val result = HashMap<String, Station>()
        runCatching { fetch(null) }.getOrNull()?.forEach { raw ->
            val code = raw.optString("stationCode")
            if (code in codes) result[code] = station(raw, channelIds[code])
        }
        val missing = codes - result.keys
        missing.map { code ->
            async { code to runCatching { fetch(code).firstOrNull { it.optString("stationCode") == code } }.getOrNull() }
        }.awaitAll().forEach { (code, raw) -> if (raw != null) result[code] = station(raw, channelIds[code]) }
        result
    }

    /** The song playing now on one station, e.g. "Tom Petty – I Won't Back Down". */
    suspend fun nowPlaying(code: String): String? =
        runCatching { fetch(code).firstOrNull { it.optString("stationCode") == code }?.let { track(it.optJSONObject("stationNowPlaying")) } }.getOrNull()

    private suspend fun fetch(code: String?): List<JSONObject> {
        val query = code?.let { "?" + URLEncoder.encode("StationCode[]", "UTF-8") + "=" + it } ?: ""
        val array = JSONArray(Http.getText("$BASE/stations/GB$query"))
        return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
    }

    companion object {
        const val BASE = "https://listenapi.planetradio.co.uk/api9.2"
        private val ukTime = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")

        fun station(raw: JSONObject, channelId: String?): Station {
            val streams = raw.optJSONArray("stationStreams")
            val free = (0 until (streams?.length() ?: 0)).mapNotNull { streams?.optJSONObject(it) }
                .filter { !it.optBoolean("streamPremium") && !it.optBoolean("streamUsersOnly") }
            // HLS first, then AAC/MP3 Icecast streams.
            val ordered = free.filter { it.optString("streamType") == "hls" } + free.filter { it.optString("streamType") != "hls" }
            val show = raw.optJSONObject("stationOnAir")
            val onAir = if (show != null && channelId != null) runCatching {
                val title = show.optString("episodeTitle").ifEmpty { null } ?: return@runCatching null
                val start = LocalDateTime.parse(show.getString("episodeStart"), ukTime).atZone(ZoneId.of("Europe/London")).toInstant()
                val duration = show.optLong("episodeDuration")
                if (duration <= 0) null else Programme(channelId, title, synopsis = show.optString("episodeDescription").ifEmpty { null },
                    start = start, end = start.plusSeconds(duration), image = show.optString("episodeImageUrl").ifEmpty { null })
            }.getOrNull() else null
            return Station(
                code = raw.optString("stationCode"),
                streams = ordered.map { it.optString("streamUrl") }.filter { it.isNotEmpty() },
                logo = raw.optString("stationListenBarLogo").ifEmpty { null },
                colour = raw.optString("stationBrandColour").removePrefix("#").ifEmpty { null },
                strapline = raw.optString("stationStrapline").ifEmpty { null },
                onAir = onAir,
                nowPlaying = track(raw.optJSONObject("stationNowPlaying")),
            )
        }

        fun track(now: JSONObject?): String? {
            val title = now?.optString("nowPlayingTrack")?.ifEmpty { null } ?: return null
            val artist = now.optString("nowPlayingArtist").ifEmpty { null }
            return if (artist != null) "$artist – $title" else title
        }
    }
}
