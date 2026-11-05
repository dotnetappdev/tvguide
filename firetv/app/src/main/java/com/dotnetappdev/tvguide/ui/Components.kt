package com.dotnetappdev.tvguide.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import com.dotnetappdev.tvguide.data.Channel
import com.dotnetappdev.tvguide.data.Programme

/** Channel logo on a dark navy chip (the feed's logos are made for dark backgrounds), or a branded monogram. */
@Composable
fun ChannelLogo(channel: Channel, height: Dp, modifier: Modifier = Modifier) {
    var failed by remember(channel.logo) { mutableStateOf(channel.logo == null) }
    val shape = RoundedCornerShape(height * 0.22f)
    Box(
        modifier
            .size(width = height * 2, height = height)
            .clip(shape)
            .background(if (failed) Brush.linearGradient(listOf(Palette.hex(channel.brand), Palette.ink)) else Brush.linearGradient(listOf(Palette.ink, Palette.ink)))
            .border(1.dp, Color.White.copy(alpha = 0.12f), shape),
        contentAlignment = Alignment.Center,
    ) {
        if (failed) {
            Text(
                channel.monogram, color = Color.White, fontWeight = FontWeight.Black, maxLines = 1,
                fontSize = (height.value * 0.36f).sp, textAlign = TextAlign.Center, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 3.dp),
            )
        } else {
            RemoteImage(
                channel.logo!!, ContentScale.Fit, onError = { failed = true },
                modifier = Modifier.fillMaxSize().padding(vertical = height * 0.14f, horizontal = height * 0.22f),
            )
        }
    }
}

/** Small rounded label such as "HD", "S", "NEW" or "S2 E4". */
@Composable
fun Badge(text: String, filled: Boolean = false, tint: Color = Color.White) {
    val shape = RoundedCornerShape(3.dp)
    Text(
        text, fontSize = 9.sp, fontWeight = FontWeight.Bold, color = if (filled) Palette.ink else tint,
        modifier = Modifier
            .background(if (filled) tint else Color.Transparent, shape)
            .border(1.dp, if (filled) Color.Transparent else tint.copy(alpha = 0.7f), shape)
            .padding(horizontal = 4.dp, vertical = 1.dp),
    )
}

/** Thin progress bar showing how far through a programme we are. */
@Composable
fun ProgressBar(progress: Float, modifier: Modifier = Modifier, tint: Color = Palette.accent, height: Dp = 3.dp) {
    Box(modifier.height(height).clip(RoundedCornerShape(height)).background(Color.White.copy(alpha = 0.22f))) {
        Box(Modifier.fillMaxWidth(progress.coerceIn(0.02f, 1f)).height(height).background(tint))
    }
}

/** Programme artwork with a branded gradient and logo fallback. */
@Composable
fun Artwork(image: String?, channel: Channel, modifier: Modifier = Modifier) {
    var failed by remember(image) { mutableStateOf(image == null) }
    Box(modifier.background(Brush.linearGradient(listOf(Palette.hex(channel.brand), Palette.backgroundTop))), contentAlignment = Alignment.Center) {
        if (failed) ChannelLogo(channel, 35.dp)
        else RemoteImage(image!!, ContentScale.Crop, Modifier.fillMaxSize(), onError = { failed = true })
    }
}

/** Full-screen classic Sky royal blue gradient. */
@Composable
fun GuideBackground(content: @Composable BoxScope.() -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Palette.backgroundTop, Palette.backgroundBottom)))
            .background(Brush.radialGradient(listOf(Palette.glow.copy(alpha = 0.4f), Color.Transparent), radius = 900f,
                center = androidx.compose.ui.geometry.Offset(1900f, 0f))),
        content = content,
    )
}

/** Badges shown next to a listing, Sky style. */
fun Programme.badges(channel: Channel): List<String> = buildList {
    if (channel.hd) add("HD")
    if (!isPlaceholder) add("S")
    episode?.let(::add)
}
