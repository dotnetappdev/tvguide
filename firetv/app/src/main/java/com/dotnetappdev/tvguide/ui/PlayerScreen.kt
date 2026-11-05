package com.dotnetappdev.tvguide.ui

import android.content.Context
import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Radio
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import androidx.tv.material3.Button
import androidx.tv.material3.Icon
import androidx.tv.material3.Text
import com.dotnetappdev.tvguide.data.Broadcaster
import com.dotnetappdev.tvguide.data.Channel
import com.dotnetappdev.tvguide.playback.RadioService
import com.dotnetappdev.tvguide.store.GuideViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlin.math.abs
import kotlin.math.sin

/** Muted ExoPlayer for the info panel's little TV. */
class PreviewPlayer(private val context: Context) {
    private var created: ExoPlayer? = null
    val player: ExoPlayer get() = created ?: ExoPlayer.Builder(context).build().apply { volume = 0f }.also { created = it }
    private var url: String? = null

    fun play(stream: String) {
        if (stream == url && player.isPlaying) return
        url = stream
        player.setMediaItem(MediaItem.fromUri(stream))
        player.prepare()
        player.play()
    }

    fun stop() {
        url = null
        created?.run {
            stop()
            clearMediaItems()
        }
    }

    fun release() {
        created?.release()
        created = null
    }
}

@OptIn(UnstableApi::class)
@Composable
fun PreviewSurface(preview: PreviewPlayer, modifier: Modifier = Modifier) {
    AndroidView(
        factory = { context ->
            PlayerView(context).apply {
                useController = false
                resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                player = preview.player
                layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
            }
        },
        modifier = modifier,
    )
}

/**
 * Full screen live TV. Up / down (or channel +/-) change channel, like a Sky
 * remote; a now & next banner appears on every change; Back returns to the
 * guide. Radio stations play through the background radio service with a
 * Sky style "now playing" screen.
 */
@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(vm: GuideViewModel, onOpenApp: (Broadcaster, Channel) -> String?) {
    val channel = vm.tunedChannel ?: return
    val context = LocalContext.current
    val candidates = vm.streams(channel)
    var streamIndex by remember(channel.id) { mutableIntStateOf(0) }
    var error by remember(channel.id) { mutableStateOf<String?>(null) }
    var appMessage by remember(channel.id) { mutableStateOf<String?>(null) }
    var showBanner by remember { mutableStateOf(true) }
    var bannerTick by remember { mutableIntStateOf(0) }
    val stream = candidates.getOrNull(streamIndex)
    val focus = remember { FocusRequester() }

    val tvPlayer = remember { ExoPlayer.Builder(context).build() }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(Unit) {
        // TV pauses when the app goes to the background; radio keeps playing (its own service).
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_STOP -> tvPlayer.pause()
                Lifecycle.Event.ON_START -> if (tvPlayer.mediaItemCount > 0) tvPlayer.play()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            tvPlayer.release()
            RadioService.stop(context)
        }
    }
    DisposableEffect(channel.id) {
        // If a stream fails, try the channel's next one.
        val listener = object : Player.Listener {
            override fun onPlayerError(e: PlaybackException) {
                if (streamIndex + 1 < candidates.size) streamIndex++ else error = e.message ?: "The stream couldn't be played."
            }
        }
        tvPlayer.addListener(listener)
        onDispose { tvPlayer.removeListener(listener) }
    }

    // Start the right player whenever the channel or stream changes.
    LaunchedEffect(channel.id, stream) {
        bannerTick++
        if (channel.isRadio) {
            tvPlayer.stop()
            if (stream != null) RadioService.play(context, candidates.drop(streamIndex), channel.name, vm.current(channel)?.title)
            else RadioService.stop(context)
        } else {
            RadioService.stop(context)
            if (stream != null && error == null) {
                tvPlayer.setMediaItem(MediaItem.fromUri(stream))
                tvPlayer.prepare()
                tvPlayer.play()
            } else tvPlayer.stop()
        }
    }
    LaunchedEffect(bannerTick) {
        showBanner = true
        delay(5_000)
        showBanner = false
    }
    LaunchedEffect(Unit) {
        withFrameNanos { }
        runCatching { focus.requestFocus() }
    }

    fun zap(offset: Int) {
        vm.channelAfter(channel, offset)?.let { vm.tune(it) }
    }

    Box(
        Modifier.fillMaxSize().background(Color.Black).focusRequester(focus).focusable().onKeyEvent { e ->
            if (e.type != KeyEventType.KeyDown) return@onKeyEvent false
            when (e.key) {
                Key.DirectionUp, Key.ChannelUp -> { zap(1); true }
                Key.DirectionDown, Key.ChannelDown -> { zap(-1); true }
                Key.DirectionLeft, Key.DirectionRight, Key.DirectionCenter, Key.Enter -> { bannerTick++; true }
                Key.MediaPlayPause -> {
                    if (!channel.isRadio) { if (tvPlayer.isPlaying) tvPlayer.pause() else tvPlayer.play() }
                    true
                }
                else -> false
            }
        },
    ) {
        when {
            stream != null && error == null && channel.isRadio -> RadioNowPlaying(vm, channel)
            stream != null && error == null -> AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = false
                        player = tvPlayer
                        setShowBuffering(PlayerView.SHOW_BUFFERING_ALWAYS)
                    }
                },
                modifier = Modifier.fillMaxSize(),
            )
            else -> NoStreamPanel(vm, channel, error, appMessage) { b -> appMessage = onOpenApp(b, channel) }
        }
        AnimatedVisibility(
            visible = showBanner && !channel.isRadio,
            enter = slideInVertically { it } + fadeIn(), exit = slideOutVertically { it } + fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter),
        ) { ChannelBanner(vm, channel) }
    }
}

/** Sky style now & next banner shown when changing channel. */
@Composable
internal fun ChannelBanner(vm: GuideViewModel, channel: Channel) {
    val now = vm.current(channel)
    val next = vm.next(channel)
    Row(
        Modifier.padding(horizontal = 40.dp, vertical = 30.dp).fillMaxWidth()
            .background(Brush.verticalGradient(listOf(Palette.backgroundBottom.copy(alpha = 0.96f), Palette.backgroundTop.copy(alpha = 0.96f))), RoundedCornerShape(14.dp))
            .border(2.dp, Palette.accent.copy(alpha = 0.0f), RoundedCornerShape(14.dp))
            .padding(horizontal = 25.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Column(Modifier.width(100.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ChannelLogo(channel, 32.dp)
            Text(channel.name, color = Palette.secondaryText, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            BannerLine("NOW", now?.let { Fmt.time(it.start) }, now?.title) {
                if (now != null) {
                    ProgressBar(now.progress(vm.now), Modifier.width(100.dp))
                    Text(Fmt.remaining(now.end, vm.now), color = Palette.secondaryText, fontSize = 11.sp)
                }
            }
            Box(Modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.2f)))
            BannerLine("NEXT", next?.let { Fmt.time(it.start) }, next?.title) {}
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(Fmt.time(vm.now), color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.SwapVert, null, tint = Palette.secondaryText, modifier = Modifier.size(11.dp))
                Text(" Channel up / down", color = Palette.secondaryText, fontSize = 10.sp)
            }
        }
    }
}

@Composable
private fun BannerLine(label: String, time: String?, title: String?, extra: @Composable () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(label, color = Palette.ink, fontSize = 10.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center,
            modifier = Modifier.width(40.dp).background(Palette.accent, RoundedCornerShape(3.dp)).padding(vertical = 2.dp))
        if (title == null) Text("No information", color = Palette.secondaryText, fontSize = 14.sp)
        else {
            Text(time.orEmpty(), color = Palette.secondaryText, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Text(title, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.widthIn(max = 380.dp))
            extra()
        }
    }
}

/** Shown when there's no stream: offers the broadcaster's app and explains how to add a tuner. */
@Composable
private fun NoStreamPanel(vm: GuideViewModel, channel: Channel, error: String?, message: String?, openApp: (Broadcaster) -> Unit) {
    val explanation = when {
        error != null -> error
        channel.isRadio -> "This station doesn't have a public internet stream that Fire TV can play."
        vm.liveSource == null -> "Connect a TV tuner under Live TV in the guide's sidebar (an HDHomeRun, Channels DVR, or a Jellyfin, TVHeadend or IPTV playlist) to watch here."
        channel.id.startsWith("sky:") -> "Sky channels come by satellite, so a Freeview tuner can't receive them. Watch them in the NOW app."
        else -> "Your live TV source doesn't include this channel."
    }
    GuideBackground {
        Column(Modifier.align(Alignment.Center).widthIn(max = 560.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            ChannelLogo(channel, 45.dp)
            Text(if (error == null) "${channel.name} isn't streaming in TV Guide" else "Couldn't play ${channel.name}",
                color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Text(explanation, color = Palette.secondaryText, fontSize = 13.sp, textAlign = TextAlign.Center)
            Broadcaster.forChannel(channel)?.let { b ->
                Button(onClick = { openApp(b) }) { Text("Watch in ${b.appName}") }
            }
            message?.let { Text(it, color = Palette.accent, fontSize = 12.sp) }
        }
    }
}

/** Sky style radio screen: big logo, the show on air, the song playing, a moving level meter and what's next. */
@Composable
internal fun RadioNowPlaying(vm: GuideViewModel, channel: Channel) {
    val context = LocalContext.current
    val now = vm.current(channel)
    val next = vm.next(channel)
    if (!LocalInspectionMode.current) {
        LaunchedEffect(channel.id) {
            // Keep the song title current while the station is on screen.
            while (isActive) {
                vm.refreshNowPlaying(channel)
                delay(30_000)
            }
        }
        LaunchedEffect(now?.id) { RadioService.updateShow(context, now?.title) }
    }
    GuideBackground {
        Row(Modifier.fillMaxSize().padding(horizontal = 60.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(45.dp)) {
            val shape = RoundedCornerShape(20.dp)
            Box(Modifier.size(230.dp).clip(shape)
                .background(Brush.linearGradient(listOf(Palette.hex(channel.brand), Palette.backgroundTop)))
                .border(1.5.dp, Palette.accent.copy(alpha = 0.5f), shape), contentAlignment = Alignment.Center) {
                if (channel.logo != null) RemoteImage(channel.logo, ContentScale.Fit, Modifier.fillMaxSize().padding(35.dp))
                else Text(channel.name, color = Color.White, fontSize = 27.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center)
            }
            Column(Modifier.widthIn(max = 500.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    Row(Modifier.background(Palette.accent, RoundedCornerShape(4.dp)).padding(horizontal = 6.dp, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Radio, null, tint = Palette.ink, modifier = Modifier.size(11.dp))
                        Text(" RADIO", color = Palette.ink, fontSize = 10.sp, fontWeight = FontWeight.Black)
                    }
                    Text(channel.name, color = Palette.secondaryText, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                }
                Text(now?.title ?: channel.name, color = Color.White, fontSize = 31.sp, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                vm.nowPlaying[channel.id]?.let { track ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.MusicNote, null, tint = Palette.accent, modifier = Modifier.size(15.dp))
                        Text(" $track", color = Palette.accent, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
                now?.synopsis?.let { Text(it, color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp, maxLines = 4, overflow = TextOverflow.Ellipsis) }
                if (now != null) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text(Fmt.range(now.start, now.end), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    ProgressBar(now.progress(vm.now), Modifier.width(180.dp), height = 4.dp)
                    Text(Fmt.remaining(now.end, vm.now), color = Palette.secondaryText, fontSize = 11.sp)
                }
                LevelMeter(Modifier.fillMaxWidth().height(35.dp))
                if (next != null) BannerLine("NEXT", Fmt.time(next.start), next.title) {}
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.SwapVert, null, tint = Palette.secondaryText, modifier = Modifier.size(11.dp))
                    Text(" Up / down for the next station · Back for the guide", color = Palette.secondaryText, fontSize = 10.sp)
                }
            }
        }
    }
}

/** Bouncing level bars while audio plays. */
@Composable
private fun LevelMeter(modifier: Modifier) {
    var t by remember { mutableStateOf(1.3) }
    if (!LocalInspectionMode.current) LaunchedEffect(Unit) {
        while (isActive) withFrameNanos { t = it / 1e9 }
    }
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.Bottom) {
        repeat(24) { i ->
            val level = 0.25f + 0.75f * abs(sin(t * (2.1 + (i % 5) * 0.37) + i * 0.7)).toFloat()
            Box(
                Modifier.width(7.dp).fillMaxHeight().graphicsLayer {
                    scaleY = level
                    transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 1f)
                }.background(if (i % 6 == 0) Palette.accent else Palette.accent.copy(alpha = 0.65f), RoundedCornerShape(50)),
            )
        }
        Spacer(Modifier.weight(1f))
    }
}
