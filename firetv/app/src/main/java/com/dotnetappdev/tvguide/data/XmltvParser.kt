package com.dotnetappdev.tvguide.data

import org.xml.sax.Attributes
import org.xml.sax.InputSource
import org.xml.sax.helpers.DefaultHandler
import java.io.InputStream
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import javax.xml.parsers.SAXParserFactory

/** Result of parsing an XMLTV document. */
class XmltvDocument(
    val programmes: Map<String, List<Programme>>,
    val logos: Map<String, String>,
    /** Channel id → display name. */
    val names: Map<String, String>,
)

/**
 * Streaming XMLTV parser (SAX, so it runs on Fire OS and in JVM unit tests).
 * Only keeps listings for the requested channel ids – the full UK feed is ~20 MB.
 */
object XmltvParser {

    fun parse(input: InputStream, channelIds: Set<String>?): XmltvDocument {
        val handler = Handler(channelIds)
        val factory = SAXParserFactory.newInstance()
        factory.newSAXParser().parse(InputSource(input), handler)
        return handler.finish()
    }

    /** Parses a third-party XMLTV guide whose ids differ from ours, matching channels by name. */
    fun parseMatchingNames(input: InputStream, channels: List<Channel>): Map<String, List<Programme>> {
        val document = parse(input, null)
        val matcher = ChannelMatcher(channels)
        val result = HashMap<String, List<Programme>>()
        for ((id, programmes) in document.programmes) {
            val name = document.names[id] ?: continue
            val channel = matcher.match(name) ?: continue
            if (result.containsKey(channel.id)) continue
            result[channel.id] = programmes.map { it.reassigned(channel.id) }
        }
        return result
    }

    private class Handler(private val wanted: Set<String>?) : DefaultHandler() {
        val programmes = HashMap<String, MutableList<Programme>>()
        val logos = HashMap<String, String>()
        val names = HashMap<String, String>()

        private val text = StringBuilder()
        private var channelId: String? = null
        private var inChannel = false
        private var inProgramme = false
        private var start: Instant? = null
        private var stop: Instant? = null
        private var title: String? = null
        private var subtitle: String? = null
        private var desc: String? = null
        private var icon: String? = null
        private var onscreen: String? = null
        private var xmltvNs: String? = null
        private var episodeSystem: String? = null
        private var isNew = false

        private fun isWanted(id: String) = wanted?.contains(id) ?: true

        override fun startElement(uri: String?, localName: String?, qName: String, attributes: Attributes) {
            when (qName) {
                "channel" -> {
                    channelId = attributes.getValue("id")
                    inChannel = channelId?.let(::isWanted) ?: false
                }
                "programme" -> {
                    val id = attributes.getValue("channel")
                    if (id == null || !isWanted(id)) {
                        inProgramme = false
                    } else {
                        inProgramme = true
                        channelId = id
                        start = attributes.getValue("start")?.let(::parseDate)
                        stop = attributes.getValue("stop")?.let(::parseDate)
                        title = null; subtitle = null; desc = null; icon = null
                        onscreen = null; xmltvNs = null; isNew = false
                    }
                }
                "icon" -> {
                    val src = attributes.getValue("src")
                    if (inProgramme) icon = src
                    else if (inChannel && src != null) channelId?.let { logos[it] = src }
                }
                "episode-num" -> episodeSystem = attributes.getValue("system")
                "premiere", "new" -> if (inProgramme) isNew = true
            }
            text.setLength(0)
        }

        override fun characters(ch: CharArray, start: Int, length: Int) {
            if (inProgramme || inChannel) text.appendRange(ch, start, start + length)
        }

        override fun endElement(uri: String?, localName: String?, qName: String) {
            val value = text.toString().trim()
            when {
                qName == "display-name" && inChannel -> channelId?.let { names.putIfAbsent(it, value) }
                qName == "channel" -> inChannel = false
                !inProgramme -> Unit
                qName == "title" -> title = value
                qName == "sub-title" -> subtitle = value
                qName == "desc" -> desc = value
                qName == "episode-num" -> when (episodeSystem) {
                    "onscreen" -> onscreen = value
                    "xmltv_ns" -> xmltvNs = value
                }
                qName == "programme" -> {
                    inProgramme = false
                    val id = channelId ?: return
                    val from = start ?: return
                    val to = stop ?: return
                    if (!to.isAfter(from)) return
                    val (fullTitle, synopsis) = rejoinTitle(title?.ifEmpty { null } ?: "Untitled", desc?.ifEmpty { null })
                    programmes.getOrPut(id) { mutableListOf() } += Programme(
                        channelId = id, title = fullTitle, subtitle = subtitle?.ifEmpty { null },
                        synopsis = synopsis, start = from, end = to, image = icon,
                        episode = episodeLabel(onscreen, xmltvNs), isNew = isNew,
                    )
                }
            }
        }

        fun finish(): XmltvDocument {
            val cleaned = programmes.mapValues { (_, list) ->
                // Sort and drop listings that overlap an earlier one so grid rows never collide.
                val out = ArrayList<Programme>()
                for (p in list.sortedBy { it.start }) {
                    val last = out.lastOrNull()
                    if (last != null && p.start.isBefore(last.end)) continue
                    out += p
                }
                out as List<Programme>
            }
            return XmltvDocument(cleaned, logos, names)
        }
    }

    /** Parses XMLTV timestamps such as `20261008220000 +0100`. */
    fun parseDate(value: String): Instant? {
        if (value.length < 14) return null
        return try {
            val local = LocalDateTime.of(
                value.substring(0, 4).toInt(), value.substring(4, 6).toInt(), value.substring(6, 8).toInt(),
                value.substring(8, 10).toInt(), value.substring(10, 12).toInt(), value.substring(12, 14).toInt(),
            )
            val tail = value.substring(14).trim()
            val offset = if (tail.length >= 5 && (tail[0] == '+' || tail[0] == '-')) {
                val sign = if (tail[0] == '-') -1 else 1
                val hh = tail.substring(1, 3).toInt()
                val mm = tail.substring(3, 5).toInt()
                ZoneOffset.ofTotalSeconds(sign * (hh * 3600 + mm * 60))
            } else ZoneOffset.UTC
            local.toInstant(offset)
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Long titles are split across fields in the feed: "George Clarke's Amazing..." with
     * a description of "...Spaces: First Home: George …". Moves the overflow back into the title.
     */
    fun rejoinTitle(title: String, desc: String?): Pair<String, String?> {
        if (!title.endsWith("...") || desc == null || !desc.startsWith("...")) return title to desc
        val colon = desc.indexOf(": ")
        if (colon < 0) return title to desc
        val overflow = desc.substring(3, colon)
        if (overflow.isEmpty() || overflow.length >= 60) return title to desc
        val head = title.dropLast(3)
        val joiner = if (head.endsWith(" ") || !overflow.first().isLetterOrDigit()) "" else " "
        return (head + joiner + overflow) to desc.substring(colon + 2).ifEmpty { null }
    }

    /** Normalises `S17E3` or xmltv_ns `16.2.0/1` into `S17 E3`; year-numbered series become `Ep 17`. */
    fun episodeLabel(onscreen: String?, xmltvNs: String?): String? {
        if (!onscreen.isNullOrEmpty()) {
            val match = Regex("""S\s*(\d+)\s*E\s*(\d+)""", RegexOption.IGNORE_CASE).find(onscreen)
            if (match != null) {
                val (season, episode) = match.destructured
                return if (season.toInt() >= 1900) "Ep $episode" else "S$season E$episode"
            }
            return onscreen
        }
        if (xmltvNs.isNullOrEmpty()) return null
        val parts = xmltvNs.split(".").map { it.substringBefore("/").trim() }
        val season = parts.getOrNull(0)?.toIntOrNull()?.plus(1)
        val episode = parts.getOrNull(1)?.toIntOrNull()?.plus(1)
        return when {
            season != null && episode != null -> "S$season E$episode"
            episode != null -> "Ep $episode"
            else -> null
        }
    }
}
