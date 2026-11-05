package com.dotnetappdev.tvguide.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LiveTv
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SettingsInputAntenna
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.outlined.Apps
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.ChildCare
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Movie
import androidx.compose.material.icons.outlined.Newspaper
import androidx.compose.material.icons.outlined.Public
import androidx.compose.material.icons.outlined.Radio
import androidx.compose.material.icons.outlined.SportsSoccer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.tv.material3.Border
import androidx.tv.material3.Card
import androidx.tv.material3.CardDefaults
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.Icon
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import com.dotnetappdev.tvguide.data.Channel
import com.dotnetappdev.tvguide.data.ChannelCategory
import com.dotnetappdev.tvguide.data.EpgSource
import com.dotnetappdev.tvguide.data.Programme
import com.dotnetappdev.tvguide.store.GuideViewModel
import java.time.Duration

/** What the guide is pointing at (drives the info panel). */
data class Highlight(val channel: Channel, val programme: Programme?)

/** Everything the guide can ask the app to do. */
class GuideActions(
    val openDetail: (Channel, Programme?) -> Unit,
    val tune: (Channel) -> Unit,
    val longPress: (Channel, Programme?) -> Unit,
    val search: () -> Unit,
    val reminders: () -> Unit,
    val liveTv: () -> Unit,
    val regions: () -> Unit,
)

@Composable
fun GuideScreen(
    vm: GuideViewModel,
    reminderIds: Set<String>,
    listState: LazyListState,
    restoreFocusId: String?,
    onFocusRemembered: (String) -> Unit,
    preview: PreviewPlayer,
    actions: GuideActions,
) {
    var highlight by remember { mutableStateOf<Highlight?>(null) }
    var gridFocused by remember { mutableStateOf(false) }
    val shown = highlight ?: vm.visibleChannels.firstOrNull()?.let { Highlight(it, vm.current(it)) }

    GuideBackground {
        Column(Modifier.fillMaxSize()) {
            TopBar(vm)
            HeroPanel(vm, shown, reminderIds, preview)
            Row(Modifier.fillMaxSize()) {
                Sidebar(vm, locked = gridFocused && !vm.isAtNow, actions = actions)
                GuideContent(
                    vm = vm,
                    reminderIds = reminderIds,
                    listState = listState,
                    restoreFocusId = restoreFocusId,
                    onHighlight = { h, inGrid ->
                        highlight = h
                        gridFocused = inGrid
                        h.programme?.id?.let(onFocusRemembered) ?: onFocusRemembered("tile:" + h.channel.id)
                    },
                    actions = actions,
                )
            }
        }
        if (vm.state == GuideViewModel.LoadState.Loading && vm.schedules.isEmpty()) {
            Text(
                "Fetching the TV guide…", color = Palette.secondaryText, fontSize = 15.sp,
                modifier = Modifier.align(Alignment.Center).background(Palette.backgroundTop.copy(alpha = 0.9f), RoundedCornerShape(12.dp))
                    .padding(24.dp),
            )
        }
    }
}

// MARK: Top bar

@Composable
private fun TopBar(vm: GuideViewModel) {
    Row(
        Modifier.fillMaxWidth().padding(start = Metrics.screenPadding, end = Metrics.screenPadding, top = 20.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Filled.LiveTv, contentDescription = null, tint = Palette.accent, modifier = Modifier.size(18.dp))
        Text("TV Guide", color = Palette.accent, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text(Fmt.longDay(vm.now), color = Palette.secondaryText, fontSize = 13.sp)
        Spacer(Modifier.weight(1f))
        val (label, dot) = when (val s = vm.state) {
            GuideViewModel.LoadState.Loading -> "Loading listings…" to Color(0xFFFFC107)
            is GuideViewModel.LoadState.Failed -> "Couldn't refresh listings" to Color(0xFFFF9800)
            is GuideViewModel.LoadState.Ready -> when (val src = s.source) {
                is EpgSource.Live -> "Freeview · ${vm.region.name}${if (vm.includesSky) " + Sky" else ""} · updated ${Fmt.time(src.updated)}" to Color(0xFF3DDC84)
                is EpgSource.Cached -> "Freeview · ${vm.region.name}${if (vm.includesSky) " + Sky" else ""} · updated ${Fmt.time(src.updated)}" to Color(0xFF3DDC84)
                EpgSource.Tuner -> "Guide from your tuner · ${vm.region.name}" to Color(0xFF3DDC84)
                EpgSource.Sample -> "Sample listings · offline" to Color(0xFFFF9800)
            }
        }
        Row(
            Modifier.background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(50)).padding(horizontal = 9.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Box(Modifier.size(6.dp).background(dot, RoundedCornerShape(50)))
            Text(label, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        }
        Text(Fmt.time(vm.now), color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
    }
}

// MARK: Info panel

@Composable
private fun HeroPanel(vm: GuideViewModel, highlight: Highlight?, reminderIds: Set<String>, preview: PreviewPlayer) {
    Row(
        Modifier.fillMaxWidth().height(Metrics.heroHeight).padding(horizontal = Metrics.screenPadding, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        if (highlight == null) return@Row
        val channel = highlight.channel
        val programme = highlight.programme
        LivePreview(vm, channel, programme, preview)
        Column(Modifier.widthIn(max = 560.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ChannelLogo(channel, 20.dp)
                Text(channel.name, color = Palette.secondaryText, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
            Text(programme?.title ?: "No information available", color = Color.White, fontSize = 23.sp,
                fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (programme != null && !programme.isPlaceholder) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    Text(Fmt.duration(programme.duration), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    programme.badges(channel).forEach { Badge(it) }
                    if (programme.isNew) Badge("NEW", filled = true, tint = Palette.accent)
                    if (programme.id in reminderIds) Icon(Icons.Filled.Notifications, null, tint = Palette.accent, modifier = Modifier.size(12.dp))
                    if (programme.isOn(vm.now)) {
                        Text("Started at ${Fmt.time(programme.start)}", color = Color.White, fontSize = 12.sp)
                        ProgressBar(programme.progress(vm.now), Modifier.width(80.dp))
                        Text(Fmt.remaining(programme.end, vm.now), color = Palette.secondaryText, fontSize = 11.sp)
                    } else {
                        Text("${Fmt.day(programme.start, vm.now)} ${Fmt.range(programme.start, programme.end)}", color = Color.White, fontSize = 12.sp)
                    }
                }
                val synopsis = listOfNotNull(programme.subtitle, programme.synopsis).joinToString(" — ")
                if (synopsis.isNotEmpty()) Text(synopsis, color = Color.White.copy(alpha = 0.8f), fontSize = 12.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** The little TV: plays the focused channel muted when a live stream exists, otherwise artwork. */
@Composable
private fun LivePreview(vm: GuideViewModel, channel: Channel, programme: Programme?, preview: PreviewPlayer) {
    val stream = vm.streams(channel).firstOrNull()
    val showsVideo = stream != null && !channel.isRadio && programme?.isOn(vm.now) != false
    if (!LocalInspectionMode.current) LaunchedEffect(channel.id, stream, showsVideo) {
        // A short pause so scrolling quickly through the guide doesn't start lots of streams.
        if (showsVideo) {
            kotlinx.coroutines.delay(700)
            preview.play(stream!!)
        } else preview.stop()
    }
    val shape = RoundedCornerShape(7.dp)
    Box(Modifier.size(224.dp, 126.dp).clip(shape).border(1.dp, Palette.accent.copy(alpha = 0.5f), shape)) {
        Artwork(programme?.image, channel, Modifier.fillMaxSize())
        if (showsVideo && !LocalInspectionMode.current) PreviewSurface(preview, Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.6f)))))
        Row(Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(7.dp), verticalAlignment = Alignment.CenterVertically) {
            if (showsVideo) Text("LIVE", fontSize = 7.sp, fontWeight = FontWeight.Black, color = Palette.ink,
                modifier = Modifier.background(Palette.accent, RoundedCornerShape(2.dp)).padding(horizontal = 3.dp, vertical = 1.dp))
            Spacer(Modifier.weight(1f))
            if (programme != null && programme.isOn(vm.now)) ProgressBar(programme.progress(vm.now), Modifier.width(60.dp))
        }
    }
}

// MARK: Sidebar

private val categoryIcons = mapOf(
    ChannelCategory.ALL to Icons.Outlined.Apps, ChannelCategory.FAVOURITES to Icons.Outlined.FavoriteBorder,
    ChannelCategory.ENTERTAINMENT to Icons.Outlined.AutoAwesome, ChannelCategory.FILMS to Icons.Outlined.Movie,
    ChannelCategory.SPORT to Icons.Outlined.SportsSoccer, ChannelCategory.FACTUAL to Icons.Outlined.Public,
    ChannelCategory.NEWS to Icons.Outlined.Newspaper, ChannelCategory.KIDS to Icons.Outlined.ChildCare,
    ChannelCategory.RADIO to Icons.Outlined.Radio,
)

/** While the viewer pages back through the timeline the sidebar steps aside, so left keeps scrolling time. */
@Composable
private fun Sidebar(vm: GuideViewModel, locked: Boolean, actions: GuideActions) {
    Column(
        Modifier.width(Metrics.sidebarWidth).fillMaxHeight().verticalScroll(rememberScrollState())
            .padding(start = 25.dp, end = 5.dp, top = 5.dp, bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text("TV guide", color = Palette.accent, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 10.dp, bottom = 4.dp))
        SidebarItem("Search", Icons.Filled.Search, locked = locked, onClick = actions.search)
        ChannelCategory.filters.forEach { category ->
            SidebarItem(category.title, categoryIcons.getValue(category), selected = vm.category == category, locked = locked) { vm.category = category }
        }
        SectionTitle("Watch")
        SidebarItem("Reminders", Icons.Filled.Notifications, locked = locked, onClick = actions.reminders)
        SidebarItem("Live TV", Icons.Filled.SettingsInputAntenna, locked = locked, onClick = actions.liveTv)
        SectionTitle("Jump to")
        SidebarItem("Now", Icons.Filled.Schedule, locked = locked) { vm.jumpToNow() }
        SidebarItem("Tonight", Icons.Filled.Bedtime, locked = locked) { vm.jump(Fmt.primeTime(vm.now, 0)) }
        SidebarItem("Tomorrow", Icons.Filled.WbSunny, locked = locked) { vm.jump(Fmt.primeTime(vm.now, 1)) }
        SectionTitle("Settings")
        SidebarItem(vm.region.name, Icons.Filled.Place, locked = locked, onClick = actions.regions)
        SidebarItem(if (vm.includesSky) "Sky channels: On" else "Sky channels: Off",
            if (vm.includesSky) Icons.Outlined.CheckCircle else Icons.Outlined.Circle, selected = vm.includesSky, locked = locked) {
            vm.selectIncludesSky(!vm.includesSky)
        }
        SidebarItem("Refresh", Icons.Filled.Refresh, locked = locked) { vm.refresh() }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(text.uppercase(), color = Palette.secondaryText, fontSize = 9.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp,
        modifier = Modifier.padding(start = 10.dp, top = 12.dp, bottom = 2.dp))
}

@Composable
private fun SidebarItem(title: String, icon: ImageVector, selected: Boolean = false, locked: Boolean = false, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().focusProperties { canFocus = !locked },
        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(7.dp)),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = if (selected) Color.White.copy(alpha = 0.10f) else Color.Transparent,
            contentColor = if (selected) Palette.accent else Color.White.copy(alpha = 0.85f),
            focusedContainerColor = Palette.accent, focusedContentColor = Palette.ink,
            pressedContainerColor = Palette.accent, pressedContentColor = Palette.ink,
        ),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1.04f),
    ) {
        Row(Modifier.padding(horizontal = 10.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(14.dp))
            Text(title, fontSize = 12.sp, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

// MARK: Tiles and grid

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun GuideContent(
    vm: GuideViewModel,
    reminderIds: Set<String>,
    listState: LazyListState,
    restoreFocusId: String?,
    onHighlight: (Highlight, Boolean) -> Unit,
    actions: GuideActions,
) {
    var pendingFocus by remember { mutableStateOf<String?>(restoreFocusId ?: "tile:first") }
    val channels = vm.visibleChannels
    BoxWithConstraints(Modifier.fillMaxSize().onPreviewKeyEvent { e ->
        // Play/Pause snaps the timeline back to now.
        if (e.type == KeyEventType.KeyDown && (e.key == Key.MediaPlayPause || e.key == Key.MediaPlay)) {
            vm.jumpToNow(); true
        } else false
    }) {
        val gridWidth = maxWidth - Metrics.channelColumnWidth - Metrics.rowSpacing - Metrics.screenPadding
        LazyColumn(state = listState, contentPadding = PaddingValues(end = Metrics.screenPadding, bottom = 30.dp)) {
            item(key = "tiles") {
                Text("On now", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 4.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(18.dp), contentPadding = PaddingValues(vertical = 10.dp, horizontal = 4.dp)) {
                    items(channels, key = { it.id }) { channel ->
                        val first = channel == channels.firstOrNull()
                        NowTile(vm, channel, actions,
                            focusKey = if (first) "tile:first" else "tile:${channel.id}",
                            altKey = "tile:${channel.id}",
                            pendingFocus = pendingFocus, clearPending = { pendingFocus = null },
                            onFocused = { onHighlight(Highlight(channel, vm.current(channel)), false) })
                    }
                }
                Spacer(Modifier.height(10.dp))
            }
            stickyHeader(key = "timeline") { TimelineHeader(vm, gridWidth) }
            if (channels.isEmpty()) item(key = "empty") {
                Text(
                    if (vm.category == ChannelCategory.FAVOURITES) "No favourites yet. Press and hold a channel or programme to add it."
                    else "There are no channels in this category.",
                    color = Palette.secondaryText, fontSize = 13.sp, modifier = Modifier.padding(20.dp),
                )
            }
            items(channels, key = { it.id }) { channel ->
                GuideRow(vm, channel, gridWidth, reminderIds, pendingFocus,
                    setPending = { pendingFocus = it },
                    onHighlight = { onHighlight(it, true) }, actions = actions)
            }
        }
    }
}

@Composable
private fun NowTile(
    vm: GuideViewModel,
    channel: Channel,
    actions: GuideActions,
    focusKey: String,
    altKey: String,
    pendingFocus: String?,
    clearPending: () -> Unit,
    onFocused: () -> Unit,
) {
    val current = vm.current(channel)
    val next = vm.next(channel)
    val requester = remember { FocusRequester() }
    LaunchedEffect(pendingFocus) {
        if (pendingFocus == focusKey || pendingFocus == altKey) {
            withFrameNanos { }
            runCatching { requester.requestFocus() }
            clearPending()
        }
    }
    Card(
        onClick = { actions.tune(channel) },
        onLongClick = { actions.longPress(channel, current) },
        modifier = Modifier.size(200.dp, 112.dp).focusRequester(requester).onFocusChanged { if (it.isFocused) onFocused() },
        border = CardDefaults.border(focusedBorder = Border(androidx.compose.foundation.BorderStroke(2.dp, Palette.accent))),
        scale = CardDefaults.scale(focusedScale = 1.08f),
    ) {
        Box(Modifier.fillMaxSize()) {
            Artwork(current?.image, channel, Modifier.fillMaxSize())
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.35f), Color.Black.copy(alpha = 0.85f)))))
            ChannelLogo(channel, 17.dp, Modifier.padding(7.dp))
            Column(Modifier.align(Alignment.BottomStart).padding(8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(current?.title ?: "No information", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (next != null) Text("Next ${Fmt.time(next.start)}  ${next.title}", color = Color.White.copy(alpha = 0.75f),
                    fontSize = 9.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (current != null) ProgressBar(current.progress(vm.now), Modifier.fillMaxWidth().padding(top = 2.dp), height = 2.5.dp)
            }
        }
    }
}

@Composable
private fun TimelineHeader(vm: GuideViewModel, gridWidth: Dp) {
    val slots = (GuideViewModel.WINDOW_SPAN.toMinutes() / GuideViewModel.SLOT.toMinutes()).toInt()
    Row(
        Modifier.fillMaxWidth().background(Palette.backgroundTop.copy(alpha = 0.95f)).padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(Metrics.rowSpacing), verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(Modifier.width(Metrics.channelColumnWidth).padding(start = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(Fmt.day(vm.windowStart, vm.now), color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
            if (!vm.isAtNow) Icon(Icons.Filled.ChevronLeft, null, tint = Palette.accent, modifier = Modifier.size(14.dp))
        }
        Box(Modifier.width(gridWidth).height(22.dp)) {
            for (i in 0 until slots) {
                val time = vm.windowStart.plus(GuideViewModel.SLOT.multipliedBy(i.toLong()))
                Row(Modifier.offset(x = gridWidth * (i.toFloat() / slots)), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.width(1.dp).height(11.dp).background(Color.White.copy(alpha = 0.35f)))
                    Text(" ${Fmt.time(time)}", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            val fraction = Duration.between(vm.windowStart, vm.now).seconds.toFloat() / GuideViewModel.WINDOW_SPAN.seconds
            if (fraction in 0f..1f) {
                Text("NOW", color = Palette.ink, fontSize = 8.sp, fontWeight = FontWeight.Black,
                    modifier = Modifier.offset(x = gridWidth * fraction - 12.dp, y = 12.dp)
                        .background(Palette.accent, RoundedCornerShape(50)).padding(horizontal = 4.dp, vertical = 1.dp))
            }
        }
    }
}

@Composable
private fun GuideRow(
    vm: GuideViewModel,
    channel: Channel,
    gridWidth: Dp,
    reminderIds: Set<String>,
    pendingFocus: String?,
    setPending: (String?) -> Unit,
    onHighlight: (Highlight) -> Unit,
    actions: GuideActions,
) {
    val segments = vm.segments(channel)
    val span = GuideViewModel.WINDOW_SPAN.seconds.toFloat()
    Row(Modifier.padding(bottom = Metrics.rowSpacing), horizontalArrangement = Arrangement.spacedBy(Metrics.rowSpacing)) {
        // Logo and name at the start of the row.
        Row(
            Modifier.width(Metrics.channelColumnWidth).height(Metrics.rowHeight).background(Palette.panel, RoundedCornerShape(6.dp)).padding(horizontal = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            ChannelLogo(channel, 20.dp)
            Text(channel.name, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, maxLines = 2,
                overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            if (vm.isFavourite(channel)) Icon(Icons.Filled.Favorite, null, tint = Palette.accent, modifier = Modifier.size(9.dp))
        }
        Box(Modifier.width(gridWidth).height(Metrics.rowHeight)) {
            Row {
                segments.forEachIndexed { index, programme ->
                    val from = maxOf(programme.start, vm.windowStart)
                    val to = minOf(programme.end, vm.windowEnd)
                    val width = gridWidth * (Duration.between(from, to).seconds / span)
                    ProgrammeCell(
                        vm, channel, programme, width,
                        isFirst = index == 0, isLast = index == segments.lastIndex,
                        hasReminder = programme.id in reminderIds,
                        pendingFocus = pendingFocus, setPending = setPending,
                        onFocused = { onHighlight(Highlight(channel, programme)) }, actions = actions,
                    )
                }
            }
            // Past part of the window dimmed, with the "now" line.
            val offset = Duration.between(vm.windowStart, vm.now).seconds / span
            if (offset in 0f..1f) {
                Box(Modifier.width(gridWidth * offset).fillMaxHeight().background(Color.Black.copy(alpha = 0.18f)))
                Box(Modifier.offset(x = gridWidth * offset - 1.dp).width(1.5.dp).height(Metrics.rowHeight + Metrics.rowSpacing).background(Palette.accent))
            }
        }
    }
}

/** Classic Sky cell: blue at rest, solid Sky yellow when focused. */
@Composable
private fun ProgrammeCell(
    vm: GuideViewModel,
    channel: Channel,
    programme: Programme,
    width: Dp,
    isFirst: Boolean,
    isLast: Boolean,
    hasReminder: Boolean,
    pendingFocus: String?,
    setPending: (String?) -> Unit,
    onFocused: () -> Unit,
    actions: GuideActions,
) {
    if (width < 1.dp) return
    val requester = remember { FocusRequester() }
    LaunchedEffect(pendingFocus) {
        if (pendingFocus == programme.id) {
            withFrameNanos { }
            runCatching { requester.requestFocus() }
            setPending(null)
        }
    }
    val isNow = programme.isOn(vm.now)
    Surface(
        onClick = {
            // Like Sky: select on what's on now watches it, otherwise shows info.
            if (isNow) actions.tune(channel) else actions.openDetail(channel, programme)
        },
        onLongClick = { actions.longPress(channel, programme) },
        modifier = Modifier.width(width).height(Metrics.rowHeight).padding(horizontal = 1.5.dp)
            .focusRequester(requester)
            .onFocusChanged { if (it.isFocused) onFocused() }
            .onPreviewKeyEvent { e -> e.type == KeyEventType.KeyDown && page(vm, channel, programme, e.key, isFirst, isLast, setPending) },
        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(5.dp)),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = when { isNow -> Palette.cellNow; programme.isPlaceholder -> Color.White.copy(alpha = 0.04f); else -> Palette.cell },
            contentColor = Color.White.copy(alpha = if (programme.isPlaceholder) 0.5f else 0.95f),
            focusedContainerColor = Palette.accent, focusedContentColor = Palette.ink,
            pressedContainerColor = Palette.accent, pressedContentColor = Palette.ink,
        ),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1f),
    ) {
        if (width > 17.dp) Row(Modifier.fillMaxSize().padding(horizontal = 7.dp), verticalAlignment = Alignment.CenterVertically) {
            if (programme.start.isBefore(vm.windowStart)) Icon(Icons.Filled.ChevronLeft, null, modifier = Modifier.size(10.dp))
            Column(Modifier.weight(1f)) {
                Text(programme.title, fontSize = 12.sp, fontWeight = if (programme.isPlaceholder) FontWeight.Normal else FontWeight.SemiBold,
                    fontStyle = if (programme.isPlaceholder) FontStyle.Italic else FontStyle.Normal, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (width > 95.dp && !programme.isPlaceholder) Text(Fmt.range(programme.start, programme.end), fontSize = 9.sp, maxLines = 1,
                    modifier = Modifier.padding(top = 1.dp), color = androidx.compose.ui.graphics.Color.Unspecified)
            }
            if (hasReminder && width > 45.dp) Icon(Icons.Filled.Notifications, null, modifier = Modifier.size(9.dp))
            if (programme.isNew && width > 140.dp) Text("NEW", fontSize = 7.sp, fontWeight = FontWeight.Black, color = Palette.ink,
                modifier = Modifier.padding(start = 3.dp).background(Palette.accent, RoundedCornerShape(2.dp)).padding(horizontal = 3.dp))
            if (programme.end.isAfter(vm.windowEnd)) Icon(Icons.Filled.ChevronRight, null, modifier = Modifier.size(10.dp))
        }
    }
}

/**
 * Right on the last cell (or left on the first) pages the window by 30
 * minutes, then moves focus to the newly revealed listing. Returns true when
 * the key press was used.
 */
private fun page(
    vm: GuideViewModel, channel: Channel, programme: Programme, key: Key,
    isFirst: Boolean, isLast: Boolean, setPending: (String?) -> Unit,
): Boolean = when {
    key == Key.DirectionRight && isLast -> {
        val fullyVisible = !programme.end.isAfter(vm.windowEnd)
        if (vm.shiftWindow(1) && fullyVisible) {
            setPending(vm.segments(channel).firstOrNull { !it.start.isBefore(programme.end) }?.id)
        }
        true
    }
    key == Key.DirectionLeft && isFirst && !vm.isAtNow -> {
        val fullyVisible = !programme.start.isBefore(vm.windowStart)
        if (vm.shiftWindow(-1) && fullyVisible) {
            setPending(vm.segments(channel).lastOrNull { !it.end.isAfter(programme.start) }?.id)
        }
        true
    }
    else -> false
}
