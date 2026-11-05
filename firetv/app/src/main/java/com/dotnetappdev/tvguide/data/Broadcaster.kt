package com.dotnetappdev.tvguide.data

/**
 * The broadcaster's own Fire TV app, offered when a channel has no stream.
 * Package names are the Fire TV / Android TV apps; they're launched to their
 * home screen (the apps don't publish deep links to a live channel).
 */
data class Broadcaster(val appName: String, val packages: List<String>) {
    companion object {
        fun forChannel(channel: Channel): Broadcaster? {
            val id = channel.id
            return when {
                id.startsWith("BBC") || id == "CBBC.uk" || id == "CBeebies.uk" ->
                    Broadcaster("BBC iPlayer", listOf("bbc.iplayer.android", "uk.co.bbc.iplayer"))
                id.startsWith("ITV") || id == "UTV.uk" -> Broadcaster("ITVX", listOf("air.ITVMobilePlayer", "com.itv.hub.firetv"))
                id.startsWith("STV") -> Broadcaster("STV Player", listOf("com.stv.stvplayer", "uk.co.stv.player"))
                id.startsWith("Channel4") || id.startsWith("E4") || id.startsWith("More4") || id.startsWith("Film4") || id == "4seven.uk" ->
                    Broadcaster("Channel 4", listOf("com.channel4.ondemand", "uk.co.channel4.android.tv"))
                id.startsWith("5") -> Broadcaster("5", listOf("com.channel5.my5", "com.channel5.androidtv"))
                id.startsWith("sky:") && !channel.isRadio -> Broadcaster("NOW", listOf("com.nowtv.player", "com.nowtv.firetv"))
                id.startsWith("UAnd") -> Broadcaster("U", listOf("uk.co.uktv.dave", "com.uktv.player"))
                else -> null
            }
        }
    }
}
