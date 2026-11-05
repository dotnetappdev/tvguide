package com.dotnetappdev.tvguide.ui

import android.content.Context
import android.content.Intent
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.tv.material3.Border
import androidx.tv.material3.Button
import androidx.tv.material3.Card
import androidx.tv.material3.CardDefaults
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.Icon
import androidx.tv.material3.OutlinedButton
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import com.dotnetappdev.tvguide.data.Channel
import com.dotnetappdev.tvguide.data.ChannelsDvr
import com.dotnetappdev.tvguide.data.LiveSource
import com.dotnetappdev.tvguide.data.Programme
import com.dotnetappdev.tvguide.data.Region
import com.dotnetappdev.tvguide.reminders.Reminder
import com.dotnetappdev.tvguide.store.GuideViewModel
import kotlinx.coroutines.launch
import java.time.Instant

/** Requests focus on the first composition (D-pad apps need a starting point). */
@Composable
fun rememberInitialFocus(): FocusRequester {
    val requester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        withFrameNanos { }
        runCatching { requester.requestFocus() }
    }
    return requester
}

@Composable
private fun ScreenTitle(text: String) {
    Text(text, color = Palette.accent, fontSize = 26.sp, fontWeight = FontWeight.Bold)
}

// MARK: Programme info

@Composable
fun DetailScreen(
    vm: GuideViewModel,
    channel: Channel,
    programme: Programme?,
    hasReminder: (Programme) -> Boolean,
    onWatch: () -> Unit,
    onToggleReminder: (Programme) -> Unit,
    onBack: () -> Unit,
) {
    val first = rememberInitialFocus()
    Box(Modifier.fillMaxSize().background(Palette.backgroundTop)) {
        Artwork(programme?.image, channel, Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(Palette.backgroundTop.copy(alpha = 0.98f), Palette.backgroundTop.copy(alpha = 0.7f), Color.Transparent))))
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.5f to Color.Transparent, 1f to Palette.backgroundTop.copy(alpha = 0.95f))))
        Column(Modifier.align(Alignment.BottomStart).padding(horizontal = 45.dp, vertical = 30.dp).widthIn(max = 640.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                ChannelLogo(channel, 27.dp)
                Text(channel.name, color = Palette.secondaryText, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
            Text(programme?.title ?: "No information available", color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.Black, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (programme != null && !programme.isPlaceholder) {
                programme.subtitle?.let { Text(it, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold) }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("${Fmt.day(programme.start, vm.now)} · ${Fmt.range(programme.start, programme.end)} · ${Fmt.duration(programme.duration)}",
                        color = Color.White, fontSize = 14.sp)
                    programme.badges(channel).forEach { Badge(it) }
                    if (programme.isNew) Badge("NEW", filled = true, tint = Palette.accent)
                }
                if (programme.isOn(vm.now)) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    ProgressBar(programme.progress(vm.now), Modifier.width(210.dp), height = 4.dp)
                    Text(Fmt.remaining(programme.end, vm.now), color = Palette.secondaryText, fontSize = 12.sp)
                }
                programme.synopsis?.let { Text(it, color = Color.White.copy(alpha = 0.85f), fontSize = 15.sp, maxLines = 5, overflow = TextOverflow.Ellipsis) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.padding(top = 4.dp)) {
                Button(onClick = onWatch, modifier = Modifier.focusRequester(first)) {
                    Icon(Icons.Filled.PlayArrow, null)
                    Text(if (programme?.isOn(vm.now) == true) " Watch now" else " Watch ${channel.name}")
                }
                if (programme != null && programme.start.isAfter(vm.now) && !programme.isPlaceholder) {
                    val set = hasReminder(programme)
                    OutlinedButton(onClick = { onToggleReminder(programme) }) {
                        Icon(if (set) Icons.Filled.Notifications else Icons.Filled.NotificationsOff, null)
                        Text(if (set) " Reminder set" else " Remind me")
                    }
                }
                OutlinedButton(onClick = { vm.toggleFavourite(channel) }) {
                    Icon(if (vm.isFavourite(channel)) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder, null)
                    Text(if (vm.isFavourite(channel)) " Favourite" else " Add to favourites")
                }
                OutlinedButton(onClick = onBack) { Text("Back to guide") }
            }
            val later = programme?.let { vm.upcoming(it) }.orEmpty()
            if (later.isNotEmpty()) {
                Text("Later on ${channel.name}", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(vertical = 6.dp)) {
                    items(later, key = { it.id }) { p ->
                        Card(onClick = {}, modifier = Modifier.size(160.dp, 75.dp)) {
                            Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                Text(Fmt.time(p.start), color = Palette.accent, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                                Text(p.title, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                p.episode?.let { Text(it, color = Color.White.copy(alpha = 0.7f), fontSize = 9.sp) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: Search

@Composable
fun SearchScreen(
    vm: GuideViewModel,
    onTune: (Channel) -> Unit,
    onOpen: (Channel, Programme) -> Unit,
    onLongPress: (Channel, Programme?) -> Unit,
    initialQuery: String = "",
) {
    var query by remember { mutableStateOf(initialQuery) }
    val results = remember(query, vm.schedules, vm.channels) { vm.search(query) }
    val context = LocalContext.current
    val voiceIntent = remember {
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-GB")
            .putExtra(RecognizerIntent.EXTRA_PROMPT, "Say a programme or channel")
    }
    val canDictate = remember { voiceIntent.resolveActivity(context.packageManager) != null }
    val voice = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()?.let { query = it }
    }
    val field = rememberInitialFocus()
    GuideBackground {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 40.dp, vertical = 25.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    TextInput(query, { query = it }, "Search programmes or channels", Modifier.width(480.dp).focusRequester(field))
                    if (canDictate) Button(onClick = { voice.launch(voiceIntent) }) { Icon(Icons.Filled.Mic, null); Text(" Speak") }
                }
                Text(
                    if (canDictate) "Type with the on-screen keyboard (its microphone works too), or choose Speak."
                    else "Type with the on-screen keyboard – on newer Fire TV remotes, hold the microphone button while the keyboard is open to dictate.",
                    color = Palette.secondaryText, fontSize = 11.sp, modifier = Modifier.padding(top = 6.dp),
                )
            }
            if (query.isNotBlank() && results.isEmpty) item { Text("No results for “$query”", color = Palette.secondaryText, fontSize = 15.sp) }
            if (results.channels.isNotEmpty()) item {
                ResultRow("Channels") {
                    items(results.channels, key = { it.id }) { c ->
                        Card(onClick = { onTune(c) }, modifier = Modifier.size(210.dp, 52.dp)) {
                            Row(Modifier.fillMaxSize().padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                ChannelLogo(c, 22.dp)
                                Text(c.name, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                        }
                    }
                }
            }
            for ((title, list) in listOf("On now" to results.onNow, "Coming up" to results.later)) if (list.isNotEmpty()) item {
                ResultRow(title) {
                    items(list, key = { it.id }) { p ->
                        val c = vm.channel(p.channelId) ?: return@items
                        ProgrammeCard(vm, c, p, onClick = { if (p.isOn(vm.now)) onTune(c) else onOpen(c, p) }, onLongClick = { onLongPress(c, p) })
                    }
                }
            }
        }
    }
}

@Composable
private fun ResultRow(title: String, content: androidx.compose.foundation.lazy.LazyListScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp), contentPadding = PaddingValues(vertical = 8.dp), content = content)
    }
}

@Composable
private fun ProgrammeCard(vm: GuideViewModel, channel: Channel, p: Programme, onClick: () -> Unit, onLongClick: () -> Unit) {
    Card(onClick = onClick, onLongClick = onLongClick, modifier = Modifier.size(200.dp, 112.dp),
        border = CardDefaults.border(focusedBorder = Border(androidx.compose.foundation.BorderStroke(2.dp, Palette.accent)))) {
        Box(Modifier.fillMaxSize()) {
            Artwork(p.image, channel, Modifier.fillMaxSize())
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.4f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.85f))))
            Column(Modifier.align(Alignment.BottomStart).padding(8.dp)) {
                Text(p.title, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(if (p.isOn(vm.now)) "Now · ${channel.name}" else "${Fmt.day(p.start, vm.now)} ${Fmt.time(p.start)} · ${channel.name}",
                    color = Color.White.copy(alpha = 0.8f), fontSize = 9.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** A D-pad friendly text field; selecting it opens Fire TV's on-screen keyboard. */
@Composable
fun TextInput(value: String, onChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier, onDone: (() -> Unit)? = null) {
    BasicTextField(
        value = value, onValueChange = onChange, singleLine = true,
        textStyle = TextStyle(color = Color.White, fontSize = 15.sp),
        cursorBrush = SolidColor(Palette.accent),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = if (onDone != null) ImeAction.Done else ImeAction.Search),
        keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = { onDone?.invoke() }),
        modifier = modifier,
        decorationBox = { inner ->
            Box(Modifier.background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(7.dp)).border(1.dp, Palette.accent.copy(alpha = 0.4f), RoundedCornerShape(7.dp))
                .padding(horizontal = 12.dp, vertical = 9.dp)) {
                if (value.isEmpty()) Text(placeholder, color = Color.White.copy(alpha = 0.5f), fontSize = 15.sp)
                inner()
            }
        },
    )
}

// MARK: Reminders

@Composable
fun RemindersScreen(reminders: List<Reminder>, onRemove: (Reminder) -> Unit, onBack: () -> Unit) {
    val first = rememberInitialFocus()
    GuideBackground {
        Column(Modifier.fillMaxSize().padding(horizontal = 50.dp, vertical = 35.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            ScreenTitle("Reminders")
            if (reminders.isEmpty()) {
                Text("No reminders set. Press and hold a programme later in the guide and choose Set reminder.", color = Palette.secondaryText, fontSize = 14.sp)
                Button(onClick = onBack, modifier = Modifier.focusRequester(first)) { Text("Back to guide") }
            } else {
                Text("Select a reminder to cancel it.", color = Palette.secondaryText, fontSize = 11.sp)
                LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(vertical = 8.dp)) {
                    items(reminders, key = { it.programmeId }) { r ->
                        Surface(
                            onClick = { onRemove(r) },
                            modifier = Modifier.widthIn(max = 700.dp).fillMaxWidth().let { if (r == reminders.first()) it.focusRequester(first) else it },
                            shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(8.dp)),
                            colors = ClickableSurfaceDefaults.colors(containerColor = Palette.cell, contentColor = Color.White,
                                focusedContainerColor = Palette.accent, focusedContentColor = Palette.ink),
                        ) {
                            Row(Modifier.padding(horizontal = 15.dp, vertical = 9.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(15.dp)) {
                                Icon(Icons.Filled.Notifications, null, modifier = Modifier.size(14.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(r.title, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    val start = Instant.ofEpochSecond(r.start)
                                    Text("${Fmt.day(start, Instant.now())} · ${Fmt.range(start, Instant.ofEpochSecond(r.end))} · ${r.channelName}", fontSize = 11.sp)
                                }
                                Icon(Icons.Filled.NotificationsOff, null, modifier = Modifier.size(13.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: Live TV

@Composable
fun LiveTvScreen(vm: GuideViewModel, onDone: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val servers = remember { mutableStateListOf<Pair<String, String>>() } // name to url
    var address by remember { mutableStateOf((vm.liveSource as? LiveSource.ChannelsDvr)?.let { LiveSource.host(it.server) }.orEmpty()) }
    var playlist by remember { mutableStateOf((vm.liveSource as? LiveSource.Playlist)?.url.orEmpty()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    fun connect(source: LiveSource) {
        busy = true; error = null
        scope.launch {
            error = vm.connect(source)
            busy = false
        }
    }

    if (!LocalInspectionMode.current) {
        DisposableEffect(Unit) {
            val stop = discoverChannelsDvr(context) { name, url -> if (servers.none { it.second == url }) servers += name to url }
            onDispose { stop() }
        }
    }
    val first = rememberInitialFocus()

    GuideBackground {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 50.dp, vertical = 35.dp).widthIn(max = 760.dp),
            verticalArrangement = Arrangement.spacedBy(13.dp)) {
            ScreenTitle("Live TV")
            Text("Fire TV has no aerial input, so live pictures come from a live TV server or playlist: Channels DVR, Jellyfin, Plex, TVHeadend or an IPTV service. Without one, channels open in the broadcaster's own app.",
                color = Palette.secondaryText, fontSize = 12.sp)
            (error ?: vm.liveStatus)?.let { Text(it, color = if (error != null) Color(0xFFFF9800) else Palette.accent, fontSize = 13.sp, fontWeight = FontWeight.SemiBold) }
            vm.liveSource?.let { source ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Filled.Check, null, tint = Color.White, modifier = Modifier.size(14.dp))
                    Text("Connected: ${source.label}", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    OutlinedButton(onClick = { vm.useLiveSource(null) }) { Text("Disconnect") }
                }
            }

            Section("Channels DVR servers on your network")
            if (servers.isEmpty()) Text("Looking… none found yet. You can also type the server's address below.", color = Palette.secondaryText, fontSize = 11.sp)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(vertical = 4.dp)) {
                items(servers, key = { it.second }) { (name, url) ->
                    Button(onClick = { connect(LiveSource.ChannelsDvr(url)) }) { Text("Channels DVR: $name") }
                }
            }

            Section("Channels DVR by address")
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TextInput(address, { address = it }, "e.g. 192.168.1.20 (port 8089 by default)", Modifier.width(340.dp).focusRequester(first), onDone = {})
                Button(enabled = !busy, onClick = {
                    ChannelsDvr.serverUrl(address)?.let { connect(LiveSource.ChannelsDvr(it)) } ?: run { error = "That doesn't look like an address." }
                }) { Text("Connect") }
            }

            Section("Other live TV source (M3U playlist)")
            Text("Jellyfin, Plex, TVHeadend or an IPTV service. Channels are matched by name; a guide linked from the playlist fills any gaps.",
                color = Palette.secondaryText, fontSize = 11.sp)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TextInput(playlist, { playlist = it }, "http://…/playlist.m3u", Modifier.width(420.dp), onDone = {})
                Button(enabled = !busy && playlist.isNotBlank(), onClick = { connect(LiveSource.Playlist(playlist.trim())) }) { Text("Use playlist") }
            }
            if (busy) Text("Connecting…", color = Palette.secondaryText, fontSize = 12.sp)
            OutlinedButton(onClick = onDone) { Text("Done") }
        }
    }
}

@Composable
private fun Section(title: String) {
    Text(title, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 6.dp))
}

/** Finds Channels DVR servers advertised over mDNS. Returns a function that stops the search. */
@Suppress("DEPRECATION")
private fun discoverChannelsDvr(context: Context, found: (String, String) -> Unit): () -> Unit {
    val nsd = context.getSystemService(NsdManager::class.java) ?: return {}
    val main = android.os.Handler(context.mainLooper)
    val listener = object : NsdManager.DiscoveryListener {
        override fun onServiceFound(info: NsdServiceInfo) {
            nsd.resolveService(info, object : NsdManager.ResolveListener {
                override fun onServiceResolved(resolved: NsdServiceInfo) {
                    val host = resolved.host?.hostAddress ?: return
                    val shown = if (host.contains(":")) "[$host]" else host
                    main.post { found(resolved.serviceName, "http://$shown:${resolved.port}") }
                }
                override fun onResolveFailed(info: NsdServiceInfo, code: Int) {}
            })
        }
        override fun onDiscoveryStarted(type: String) {}
        override fun onDiscoveryStopped(type: String) {}
        override fun onServiceLost(info: NsdServiceInfo) {}
        override fun onStartDiscoveryFailed(type: String, code: Int) {}
        override fun onStopDiscoveryFailed(type: String, code: Int) {}
    }
    return runCatching {
        nsd.discoverServices("_channels_dvr._tcp", NsdManager.PROTOCOL_DNS_SD, listener)
        ({ runCatching { nsd.stopServiceDiscovery(listener) }; Unit })
    }.getOrDefault {}
}

// MARK: Region

@Composable
fun RegionScreen(vm: GuideViewModel, onDone: () -> Unit) {
    val first = rememberInitialFocus()
    GuideBackground {
        Column(Modifier.fillMaxSize().padding(horizontal = 50.dp, vertical = 35.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ScreenTitle("Your TV region")
            Text("Sets which BBC One, ITV1 / STV / UTV and Channel 4 the guide shows.", color = Palette.secondaryText, fontSize = 12.sp)
            LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp), contentPadding = PaddingValues(vertical = 6.dp)) {
                items(Region.all, key = { it.id }) { region ->
                    val selected = region == vm.region
                    Surface(
                        onClick = { vm.selectRegion(region); onDone() },
                        modifier = Modifier.width(380.dp).let { if (selected) it.focusRequester(first) else it },
                        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(7.dp)),
                        colors = ClickableSurfaceDefaults.colors(containerColor = Palette.cell, contentColor = Color.White,
                            focusedContainerColor = Palette.accent, focusedContentColor = Palette.ink),
                    ) {
                        Row(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(region.name, fontSize = 14.sp, modifier = Modifier.weight(1f))
                            if (selected) Icon(Icons.Filled.Check, null, modifier = Modifier.size(14.dp))
                        }
                    }
                }
            }
        }
    }
}

// MARK: Dialogs

/** Press and hold menu: watch, info, reminder, favourite. */
@Composable
fun ActionMenu(
    vm: GuideViewModel,
    channel: Channel,
    programme: Programme?,
    hasReminder: Boolean,
    onWatch: () -> Unit,
    onInfo: () -> Unit,
    onToggleReminder: () -> Unit,
    onDismiss: () -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        val first = rememberInitialFocus()
        Column(Modifier.background(Palette.backgroundTop, RoundedCornerShape(12.dp)).border(1.dp, Palette.accent.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .padding(18.dp).width(300.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(programme?.title ?: channel.name, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(channel.name, color = Palette.secondaryText, fontSize = 11.sp)
            Spacer(Modifier.height(4.dp))
            MenuButton("Watch ${channel.name}", Icons.Filled.PlayArrow, Modifier.focusRequester(first)) { onWatch(); onDismiss() }
            MenuButton("Programme info", Icons.Filled.Info) { onInfo(); onDismiss() }
            if (programme != null && programme.start.isAfter(vm.now) && !programme.isPlaceholder) {
                MenuButton(if (hasReminder) "Cancel reminder" else "Set reminder",
                    if (hasReminder) Icons.Filled.NotificationsOff else Icons.Filled.Notifications) { onToggleReminder(); onDismiss() }
            }
            MenuButton(if (vm.isFavourite(channel)) "Remove from favourites" else "Add to favourites",
                if (vm.isFavourite(channel)) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder) { vm.toggleFavourite(channel); onDismiss() }
        }
    }
}

@Composable
private fun MenuButton(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Surface(onClick = onClick, modifier = modifier.fillMaxWidth(),
        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(7.dp)),
        colors = ClickableSurfaceDefaults.colors(containerColor = Palette.cell, contentColor = Color.White,
            focusedContainerColor = Palette.accent, focusedContentColor = Palette.ink)) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(icon, null, modifier = Modifier.size(14.dp))
            Text(text, fontSize = 13.sp)
        }
    }
}

/** "Starting soon" alert for a due reminder, with an option to switch over. */
@Composable
fun ReminderAlert(reminder: Reminder, now: Instant, onWatch: () -> Unit, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        val first = rememberInitialFocus()
        val start = Instant.ofEpochSecond(reminder.start)
        Column(Modifier.background(Palette.backgroundTop, RoundedCornerShape(14.dp)).border(1.dp, Palette.accent.copy(alpha = 0.6f), RoundedCornerShape(14.dp))
            .padding(22.dp).width(400.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.Notifications, null, tint = Palette.accent, modifier = Modifier.size(22.dp))
            Text("Reminder: ${reminder.title}", color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            Text((if (start.isAfter(now)) "Starts at " else "Started at ") + "${Fmt.time(start)} on ${reminder.channelName}.",
                color = Palette.secondaryText, fontSize = 13.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(onClick = onWatch, modifier = Modifier.focusRequester(first)) { Text("Watch ${reminder.channelName}") }
                OutlinedButton(onClick = onDismiss) { Text("Dismiss") }
            }
        }
    }
}
