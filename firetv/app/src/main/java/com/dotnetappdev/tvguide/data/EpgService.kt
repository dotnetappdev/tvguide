package com.dotnetappdev.tvguide.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.time.Instant

sealed interface EpgSource {
    data class Live(val updated: Instant) : EpgSource
    data class Cached(val updated: Instant) : EpgSource
    /** Guide from the viewer's live TV source (Channels DVR / playlist). */
    data object Tuner : EpgSource
    data object Sample : EpgSource
}

class EpgSnapshot(val programmes: Map<String, List<Programme>>, val logos: Map<String, String>, val source: EpgSource)

/**
 * Downloads and caches the UK Freeview XMLTV feed (the community-maintained
 * https://github.com/dp247/Freeview-EPG), refreshing at most every 4 hours.
 */
class EpgService(cacheDir: File, private val maxAgeMs: Long = 4 * 3600_000L) {
    private val cacheFile = File(cacheDir, "freeview-epg.xml")

    suspend fun load(channelIds: Set<String>, forceRefresh: Boolean = false): EpgSnapshot {
        val cachedAt = cacheFile.takeIf { it.exists() }?.lastModified()
        val fresh = cachedAt != null && System.currentTimeMillis() - cachedAt < maxAgeMs
        if (!forceRefresh && fresh) parseCache(channelIds)?.let {
            return EpgSnapshot(it.programmes, it.logos, EpgSource.Cached(Instant.ofEpochMilli(cachedAt!!)))
        }
        return try {
            Http.download(FEED_URL, cacheFile)
            val doc = parseCache(channelIds) ?: error("Couldn't read listings")
            EpgSnapshot(doc.programmes, doc.logos, EpgSource.Live(Instant.now()))
        } catch (e: Exception) {
            // Stale listings beat an empty guide.
            val doc = if (cachedAt != null) parseCache(channelIds) else null
            if (doc != null && doc.programmes.isNotEmpty()) {
                EpgSnapshot(doc.programmes, doc.logos, EpgSource.Cached(Instant.ofEpochMilli(cachedAt!!)))
            } else throw e
        }
    }

    private suspend fun parseCache(ids: Set<String>): XmltvDocument? = withContext(Dispatchers.Default) {
        if (!cacheFile.exists()) null else runCatching { cacheFile.inputStream().buffered().use { XmltvParser.parse(it, ids) } }.getOrNull()
    }

    companion object {
        const val FEED_URL = "https://raw.githubusercontent.com/dp247/Freeview-EPG/master/epg.xml"
    }
}
