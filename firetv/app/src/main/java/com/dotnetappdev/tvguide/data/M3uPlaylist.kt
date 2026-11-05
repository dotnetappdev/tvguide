package com.dotnetappdev.tvguide.data

/**
 * An extended M3U playlist of live channels, as exported by Channels DVR,
 * Jellyfin, Plex, TVHeadend or an IPTV provider.
 */
class M3uPlaylist(val entries: List<Entry>, val guideUrl: String? = null) {
    data class Entry(val name: String, val tvgId: String?, val tvgName: String?, val number: Int?, val url: String)

    /** Matches entries to guide channels by tvg-id, then by name, then (unnamed entries only) by number. */
    fun streams(channels: List<Channel>): Map<String, String> {
        val ids = channels.associateBy { it.id.lowercase() }
        val numbers = channels.associateBy { it.number }
        val matcher = ChannelMatcher(channels)
        val result = LinkedHashMap<String, String>()
        for (entry in entries) {
            val channel = entry.tvgId?.let { ids[it.lowercase()] }
                ?: listOfNotNull(entry.tvgName, entry.name.ifEmpty { null }).firstNotNullOfOrNull { matcher.match(it) }
                ?: if (entry.tvgName == null && entry.name.isEmpty()) entry.number?.let { numbers[it] } else null
            if (channel != null) result.putIfAbsent(channel.id, entry.url)
        }
        return result
    }

    companion object {
        fun parse(text: String): M3uPlaylist {
            val entries = ArrayList<Entry>()
            var pendingName = ""
            var pendingAttrs: Map<String, String> = emptyMap()
            val lines = text.lineSequence().map { it.trim() }.filter { it.isNotEmpty() }.toList()
            for (line in lines) {
                when {
                    line.startsWith("#EXTINF") -> {
                        pendingName = displayName(line)
                        pendingAttrs = attributes(line)
                    }
                    line.startsWith("#") -> Unit
                    line.contains("://") -> {
                        val chno = pendingAttrs["tvg-chno"] ?: pendingAttrs["channel-number"] ?: pendingAttrs["channel-id"]
                        entries += Entry(
                            name = pendingName,
                            tvgId = pendingAttrs["tvg-id"]?.ifEmpty { null },
                            tvgName = pendingAttrs["tvg-name"]?.ifEmpty { null },
                            number = chno?.toIntOrNull(),
                            url = line,
                        )
                        pendingName = ""
                        pendingAttrs = emptyMap()
                    }
                }
            }
            val header = lines.firstOrNull()?.takeIf { it.startsWith("#EXTM3U") }?.let(::attributes) ?: emptyMap()
            val guide = (header["url-tvg"] ?: header["x-tvg-url"])?.split(",")?.firstOrNull()?.trim()
            return M3uPlaylist(entries, guide)
        }

        suspend fun load(url: String) = parse(Http.getText(url))

        private fun displayName(line: String): String {
            var inQuotes = false
            var comma = -1
            line.forEachIndexed { i, c ->
                if (c == '"') inQuotes = !inQuotes else if (c == ',' && !inQuotes) comma = i
            }
            return if (comma >= 0) line.substring(comma + 1).trim() else ""
        }

        private fun attributes(line: String): Map<String, String> =
            Regex("""([\w-]+)="([^"]*)"""").findAll(line).associate { it.groupValues[1].lowercase() to it.groupValues[2] }
    }
}
