package com.dotnetappdev.tvguide

import android.Manifest
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme
import com.dotnetappdev.tvguide.data.Broadcaster
import com.dotnetappdev.tvguide.data.Channel
import com.dotnetappdev.tvguide.data.EpgService
import com.dotnetappdev.tvguide.data.Programme
import com.dotnetappdev.tvguide.reminders.Reminder
import com.dotnetappdev.tvguide.reminders.ReminderStore
import com.dotnetappdev.tvguide.store.GuideViewModel
import com.dotnetappdev.tvguide.ui.ActionMenu
import com.dotnetappdev.tvguide.ui.DetailScreen
import com.dotnetappdev.tvguide.ui.GuideActions
import com.dotnetappdev.tvguide.ui.GuideScreen
import com.dotnetappdev.tvguide.ui.LiveTvScreen
import com.dotnetappdev.tvguide.ui.Palette
import com.dotnetappdev.tvguide.ui.PlayerScreen
import com.dotnetappdev.tvguide.ui.PreviewPlayer
import com.dotnetappdev.tvguide.ui.RegionScreen
import com.dotnetappdev.tvguide.ui.ReminderAlert
import com.dotnetappdev.tvguide.ui.RemindersScreen
import com.dotnetappdev.tvguide.ui.SearchScreen

/** Screens shown over the guide. */
private sealed interface Screen {
    data object Guide : Screen
    data class Detail(val channel: Channel, val programme: Programme?) : Screen
    data object Search : Screen
    data object Reminders : Screen
    data object LiveTv : Screen
    data object Region : Screen
}

class MainActivity : ComponentActivity() {
    private val vm: GuideViewModel by viewModels {
        object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                GuideViewModel(getSharedPreferences("guide", Context.MODE_PRIVATE), EpgService(cacheDir)) as T
        }
    }
    private lateinit var reminderStore: ReminderStore
    /** Channel to open once the line-up has loaded (from a reminder notification). */
    private var pendingTune by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        reminderStore = ReminderStore(applicationContext)
        ReminderStore.ensureChannel(this)
        pendingTune = intent.getStringExtra(ReminderStore.EXTRA_CHANNEL_ID)
        vm.start()
        setContent {
            MaterialTheme(colorScheme = darkColorScheme(primary = Palette.accent, onPrimary = Palette.ink, surface = Palette.backgroundTop)) {
                App(vm, reminderStore, pendingTune) { pendingTune = null }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(ReminderStore.EXTRA_CHANNEL_ID)?.let { pendingTune = it }
    }
}

@Composable
private fun App(vm: GuideViewModel, reminderStore: ReminderStore, pendingTune: String?, clearPendingTune: () -> Unit) {
    val context = LocalContext.current
    var screen by remember { mutableStateOf<Screen>(Screen.Guide) }
    var menu by remember { mutableStateOf<Pair<Channel, Programme?>?>(null) }
    var alert by remember { mutableStateOf<Reminder?>(null) }
    var lastFocus by remember { mutableStateOf<String?>(null) }
    val listState = rememberLazyListState()
    val reminders by reminderStore.reminders.collectAsState(initial = emptyList())
    val reminderIds = remember(reminders) { reminders.map { it.programmeId }.toSet() }
    val preview = remember { PreviewPlayer(context) }
    DisposableEffect(Unit) { onDispose { preview.release() } }

    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
    LaunchedEffect(Unit) { if (Build.VERSION.SDK_INT >= 33) notifications.launch(Manifest.permission.POST_NOTIFICATIONS) }

    LaunchedEffect(pendingTune, vm.channels) {
        val id = pendingTune ?: return@LaunchedEffect
        vm.channel(id)?.let { vm.tune(it); clearPendingTune() }
    }

    // In-app reminder alert (in the guide or while watching).
    LaunchedEffect(vm.now, reminders, screen) {
        if (alert == null && (screen == Screen.Guide || vm.tunedChannelId != null)) {
            alert = reminderStore.due(reminders, vm.now.epochSecond)
        }
    }

    fun toggleReminder(channel: Channel, programme: Programme) =
        reminderStore.toggle(programme, channel, programme.id in reminderIds)

    val watching = vm.tunedChannelId != null
    if (watching) {
        BackHandler { vm.tunedChannelId = null }
        // Pause the preview while full screen TV plays.
        LaunchedEffect(Unit) { preview.stop() }
        PlayerScreen(vm) { broadcaster, _ -> openApp(context, broadcaster) }
    } else when (val s = screen) {
        Screen.Guide -> GuideScreen(
            vm = vm, reminderIds = reminderIds, listState = listState, restoreFocusId = lastFocus,
            onFocusRemembered = { lastFocus = it }, preview = preview,
            actions = GuideActions(
                openDetail = { c, p -> screen = Screen.Detail(c, p) },
                tune = { vm.tune(it) },
                longPress = { c, p -> menu = c to p },
                search = { screen = Screen.Search },
                reminders = { screen = Screen.Reminders },
                liveTv = { screen = Screen.LiveTv },
                regions = { screen = Screen.Region },
            ),
        )
        is Screen.Detail -> {
            BackHandler { screen = Screen.Guide }
            DetailScreen(vm, s.channel, s.programme, hasReminder = { it.id in reminderIds },
                onWatch = { screen = Screen.Guide; vm.tune(s.channel) },
                onToggleReminder = { toggleReminder(s.channel, it) },
                onBack = { screen = Screen.Guide })
        }
        Screen.Search -> {
            BackHandler { screen = Screen.Guide }
            SearchScreen(vm, onTune = { screen = Screen.Guide; vm.tune(it) }, onOpen = { c, p -> screen = Screen.Detail(c, p) },
                onLongPress = { c, p -> menu = c to p })
        }
        Screen.Reminders -> {
            BackHandler { screen = Screen.Guide }
            RemindersScreen(reminders, onRemove = { reminderStore.remove(it) }, onBack = { screen = Screen.Guide })
        }
        Screen.LiveTv -> {
            BackHandler { screen = Screen.Guide }
            LiveTvScreen(vm) { screen = Screen.Guide }
        }
        Screen.Region -> {
            BackHandler { screen = Screen.Guide }
            RegionScreen(vm) { screen = Screen.Guide }
        }
    }

    menu?.let { (channel, programme) ->
        ActionMenu(vm, channel, programme, hasReminder = programme?.id in reminderIds,
            onWatch = { screen = Screen.Guide; vm.tune(channel) },
            onInfo = { screen = Screen.Detail(channel, programme) },
            onToggleReminder = { programme?.let { toggleReminder(channel, it) } },
            onDismiss = { menu = null })
    }
    alert?.let { r ->
        ReminderAlert(r, vm.now,
            onWatch = { vm.channel(r.channelId)?.let { screen = Screen.Guide; vm.tune(it) }; alert = null },
            onDismiss = { alert = null })
    }
}

/** Opens the broadcaster's Fire TV app; returns a message if it isn't installed. */
private fun openApp(context: Context, broadcaster: Broadcaster): String? {
    val pm = context.packageManager
    for (pkg in broadcaster.packages) {
        val intent = pm.getLeanbackLaunchIntentForPackage(pkg) ?: pm.getLaunchIntentForPackage(pkg) ?: continue
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return null
    }
    return "Install the ${broadcaster.appName} app from the Amazon Appstore to watch this channel."
}
