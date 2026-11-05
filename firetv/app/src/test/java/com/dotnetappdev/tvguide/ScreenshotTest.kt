package com.dotnetappdev.tvguide

import android.graphics.BitmapFactory
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.activity.result.ActivityResultRegistry
import androidx.activity.result.ActivityResultRegistryOwner
import androidx.activity.result.contract.ActivityResultContract
import androidx.core.app.ActivityOptionsCompat
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme
import app.cash.paparazzi.DeviceConfig
import app.cash.paparazzi.Paparazzi
import com.android.resources.Density
import com.android.resources.ScreenOrientation
import com.android.resources.UiMode
import com.dotnetappdev.tvguide.data.ChannelCategory
import com.dotnetappdev.tvguide.data.EpgService
import com.dotnetappdev.tvguide.data.Http
import com.dotnetappdev.tvguide.store.GuideViewModel
import com.dotnetappdev.tvguide.ui.Artwork
import com.dotnetappdev.tvguide.ui.ChannelBanner
import com.dotnetappdev.tvguide.ui.DetailScreen
import com.dotnetappdev.tvguide.ui.GuideActions
import com.dotnetappdev.tvguide.ui.GuideScreen
import com.dotnetappdev.tvguide.ui.LiveTvScreen
import com.dotnetappdev.tvguide.ui.LocalPreviewImages
import com.dotnetappdev.tvguide.ui.Palette
import com.dotnetappdev.tvguide.ui.PreviewPlayer
import com.dotnetappdev.tvguide.ui.RadioNowPlaying
import com.dotnetappdev.tvguide.ui.SearchScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.setMain
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.nio.file.Files

/**
 * Renders the real screens with today's live listings at Fire TV's 1080p
 * (960×540 dp). Only runs when recording: `./gradlew recordPaparazziDebug`.
 * Images land in app/src/test/snapshots/images.
 */
class ScreenshotTest {
    @get:Rule
    val paparazzi = Paparazzi(
        deviceConfig = DeviceConfig(
            screenWidth = 1920, screenHeight = 1080, xdpi = 320, ydpi = 320, density = Density.XHIGH,
            orientation = ScreenOrientation.LANDSCAPE, uiMode = UiMode.TELEVISION, softButtons = false,
        ),
        theme = "android:Theme.Material.NoActionBar.Fullscreen",
        maxPercentDifference = 100.0,
    )

    @Before fun onlyWhenRecording() = assumeTrue(System.getProperty("paparazzi.test.record") == "true")

    companion object {
        private val images = HashMap<String, ImageBitmap?>()

        val vm: GuideViewModel by lazy {
            @Suppress("OPT_IN_USAGE") Dispatchers.setMain(UnconfinedTestDispatcher())
            GuideViewModel(FakePrefs(), EpgService(Files.createTempDirectory("epg").toFile())).also { runBlocking { it.load() } }
        }

        /** Downloads the logos and artwork a screen shows, so it renders without network access. */
        fun prefetch(urls: Collection<String?>) = runBlocking(Dispatchers.IO) {
            val gate = Semaphore(6)
            urls.filterNotNull().distinct().filter { it !in images }.map { url ->
                async {
                    gate.withPermit {
                        val bytes = runCatching { Http.get(url, 15_000) }.getOrNull()
                        images[url] = bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size)?.asImageBitmap() }
                    }
                }
            }.awaitAll()
        }
    }

    @Composable
    private fun Screen(content: @Composable () -> Unit) {
        CompositionLocalProvider(
            LocalPreviewImages provides { url -> images[url] },
            LocalInspectionMode provides true,
            LocalActivityResultRegistryOwner provides registryOwner,
        ) {
            MaterialTheme(colorScheme = darkColorScheme(primary = Palette.accent, onPrimary = Palette.ink, surface = Palette.backgroundTop)) {
                content()
            }
        }
    }

    /** Stands in for the activity so the voice search launcher can be created. */
    private val registryOwner = object : ActivityResultRegistryOwner {
        override val activityResultRegistry = object : ActivityResultRegistry() {
            override fun <I, O> onLaunch(requestCode: Int, contract: ActivityResultContract<I, O>, input: I, options: ActivityOptionsCompat?) {}
        }
    }

    private val noActions = GuideActions({ _, _ -> }, {}, { _, _ -> }, {}, {}, {}, {})

    private fun guide(category: ChannelCategory, name: String) {
        vm.category = category
        val channels = vm.visibleChannels.take(12)
        prefetch(channels.map { it.logo } + channels.take(6).map { vm.current(it)?.image })
        paparazzi.snapshot(name) {
            Screen {
                GuideScreen(vm, emptySet(), LazyListState(), null, {}, PreviewPlayer(LocalContext.current), noActions)
            }
        }
        vm.category = ChannelCategory.ALL
    }

    @Test fun guideAllChannels() = guide(ChannelCategory.ALL, "guide")
    @Test fun guideSports() = guide(ChannelCategory.SPORT, "sports")
    @Test fun guideRadio() = guide(ChannelCategory.RADIO, "radio")

    @Test fun radioNowPlaying() {
        val station = vm.channels.first { it.name == "Absolute Radio" }
        prefetch(listOf(station.logo))
        paparazzi.snapshot("radioplay") { Screen { RadioNowPlaying(vm, station) } }
    }

    @Test fun channelBanner() {
        val channel = vm.channels.first { it.name == "Channel 4" }
        prefetch(listOf(channel.logo, vm.current(channel)?.image))
        paparazzi.snapshot("player") {
            Screen {
                Box(Modifier.fillMaxSize()) {
                    Artwork(vm.current(channel)?.image, channel, Modifier.fillMaxSize())
                    Box(Modifier.align(Alignment.BottomCenter)) { ChannelBanner(vm, channel) }
                }
            }
        }
    }

    @Test fun programmeInfo() {
        val channel = vm.channels.first { it.name == "BBC One" }
        val programme = vm.next(channel)
        prefetch(listOf(channel.logo, programme?.image))
        paparazzi.snapshot("info") {
            Screen { DetailScreen(vm, channel, programme, { false }, {}, {}, {}) }
        }
    }

    @Test fun search() {
        val results = vm.search("news")
        prefetch(results.channels.map { it.logo } + (results.onNow + results.later).take(10).flatMap { p ->
            listOf(p.image, vm.channel(p.channelId)?.logo)
        })
        paparazzi.snapshot("search") { Screen { SearchScreen(vm, {}, { _, _ -> }, { _, _ -> }, initialQuery = "news") } }
    }

    @Test fun liveTv() {
        paparazzi.snapshot("livetv") { Screen { LiveTvScreen(vm) {} } }
    }
}
