package com.dotnetappdev.tvguide.data

/**
 * Matches channel names from tuners and playlists ("BBC ONE Lon HD",
 * "ITV1 HD", "Channel 5 HD") to the guide's channels.
 */
class ChannelMatcher(channels: List<Channel>) {
    private val byKey = LinkedHashMap<String, Channel>()
    /** Longest first, so "E4 Extra" wins over "E4" when matching by prefix. */
    private val keys: List<Pair<String, Channel>>

    init {
        for (channel in channels) for (key in keysFor(channel)) byKey.putIfAbsent(key, channel)
        keys = byKey.entries.map { it.key to it.value }.sortedByDescending { it.first.length }
    }

    /** Exact match on the normalised name, then the longest guide name the tuner name starts with. */
    fun match(name: String): Channel? {
        val key = normalise(name)
        if (key.isEmpty()) return null
        byKey[key]?.let { return it }
        return keys.firstOrNull { it.first.length >= 2 && key.startsWith(it.first) }?.second
    }

    companion object {
        private val noise = setOf(
            "hd", "uhd", "sd", "lon", "london", "uk", "eng", "england", "ne", "nw", "ee", "se", "sw", "w", "e",
            "yorks", "yorkshire", "wales", "cymru", "scot", "scotland", "ni", "east", "west", "south", "north",
            "midlands", "mids", "central", "granada", "meridian", "anglia", "tyne", "tees", "border", "westcountry",
        )

        private val aliases = mapOf(
            "5" to listOf("channel5", "five"),
            "Sky Mix" to listOf("skymixhd"),
            "ITV1+1" to listOf("itvplus1"),
            "U&Dave" to listOf("dave"),
            "U&Drama" to listOf("drama"),
            "U&Yesterday" to listOf("yesterday"),
            "U&W" to listOf("w"),
            "Al Jazeera" to listOf("aljazeeraeng", "aljazeeraenglish"),
            "France 24" to listOf("france24english"),
        )

        /** "BBC ONE Lon HD" → "bbcone". */
        fun normalise(name: String): String {
            val words = name.lowercase()
                .replace("&", " and ")
                .replace("+", " plus ")
                .split(Regex("[^\\p{L}\\p{N}]+"))
                .filter { it.isNotEmpty() }
                .toMutableList()
            while (words.size > 1 && words.last() in noise) words.removeAt(words.lastIndex)
            return words.joinToString("")
        }

        private fun keysFor(channel: Channel) = listOf(normalise(channel.name)) + (aliases[channel.name] ?: emptyList())
    }
}
