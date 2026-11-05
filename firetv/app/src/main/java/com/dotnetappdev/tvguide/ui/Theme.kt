package com.dotnetappdev.tvguide.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Classic Sky guide palette: deep royal blue with Sky yellow highlights. */
object Palette {
    val backgroundTop = Color(0xFF00135C)
    val backgroundBottom = Color(0xFF0038A8)
    val glow = Color(0xFF1D63E6)
    /** Sky yellow – focus highlight and accents. */
    val accent = Color(0xFFFFD100)
    /** Dark navy text on yellow. */
    val ink = Color(0xFF001450)
    val panel = Color(0xD90A2C8F)
    val cell = Color(0xBF1E50C8)
    val cellNow = Color(0xE62E6BF0)
    val secondaryText = Color(0xFFBCD0FF)

    fun hex(rrggbb: String): Color = runCatching { Color(0xFF000000 or rrggbb.toLong(16)) }.getOrDefault(Color(0xFF1F4FD1))
}

/** Layout metrics for Fire TV's 960×540 dp canvas (a 1080p screen at 2×). */
object Metrics {
    val sidebarWidth = 170.dp
    val channelColumnWidth = 135.dp
    val rowHeight = 34.dp
    val rowSpacing = 4.dp
    val heroHeight = 150.dp
    val screenPadding = 40.dp
}

/** UK style times ("7:30pm", "1h 30m", "Tomorrow"). */
object Fmt {
    private val zone: ZoneId get() = ZoneId.systemDefault()
    private val timeFormat = DateTimeFormatter.ofPattern("h:mma", Locale.UK)
    private val dayFormat = DateTimeFormatter.ofPattern("EEE d MMM", Locale.UK)
    private val longDayFormat = DateTimeFormatter.ofPattern("EEEE d MMMM", Locale.UK)

    fun time(instant: Instant): String = timeFormat.format(instant.atZone(zone)).lowercase(Locale.UK)

    fun range(start: Instant, end: Instant) = "${time(start)} – ${time(end)}"

    fun duration(d: Duration): String {
        val minutes = (d.seconds + 30) / 60
        if (minutes < 60) return "${minutes}m"
        val h = minutes / 60
        val m = minutes % 60
        return if (m == 0L) "${h}h" else "${h}h ${m}m"
    }

    fun day(instant: Instant, now: Instant): String {
        val date = instant.atZone(zone).toLocalDate()
        val today = now.atZone(zone).toLocalDate()
        return when (date) {
            today -> "Today"
            today.plusDays(1) -> "Tomorrow"
            else -> dayFormat.format(date)
        }
    }

    fun longDay(instant: Instant): String = longDayFormat.format(instant.atZone(zone))

    fun remaining(end: Instant, now: Instant) = "${duration(Duration.between(now, end))} left"

    /** 7pm on today + [dayOffset]. */
    fun primeTime(now: Instant, dayOffset: Long): Instant =
        now.atZone(zone).toLocalDate().plusDays(dayOffset).atTime(19, 0).atZone(zone).toInstant()
}
