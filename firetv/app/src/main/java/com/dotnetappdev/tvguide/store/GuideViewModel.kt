package com.dotnetappdev.tvguide.store

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dotnetappdev.tvguide.data.CatalogueStation
import com.dotnetappdev.tvguide.data.Channel
import com.dotnetappdev.tvguide.data.ChannelCategory
import com.dotnetappdev.tvguide.data.ChannelLineup
import com.dotnetappdev.tvguide.data.ChannelsDvr
import com.dotnetappdev.tvguide.data.EpgService
import com.dotnetappdev.tvguide.data.EpgSnapshot
import com.dotnetappdev.tvguide.data.EpgSource
import com.dotnetappdev.tvguide.data.LiveSource
import com.dotnetappdev.tvguide.data.PlaylistSource
import com.dotnetappdev.tvguide.data.Programme
import com.dotnetappdev.tvguide.data.RADIO_CATALOGUE
import com.dotnetappdev.tvguide.data.RayoService
import com.dotnetappdev.tvguide.data.Region
import com.dotnetappdev.tvguide.data.SKY_RADIO
import com.dotnetappdev.tvguide.data.SampleSchedule
import com.dotnetappdev.tvguide.data.SkyEpgService
import com.dotnetappdev.tvguide.data.TunerData
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.text.Normalizer
import java.time.Duration
import java.time.Instant

/**
 * Single source of truth for the guide: line-up, listings, the visible
 * timeline window, favourites, radio and live TV sources. A port of the
 * Apple TV app's GuideStore.
 */
class GuideViewModel(
    private val prefs: SharedPreferences,
    private val epg: EpgService,
    private val sky: SkyEpgService = SkyEpgService(),
    private val rayo: RayoService = RayoService(),
    private val clock: () -> Instant = Instant::now,
) : ViewModel() {

    sealed interface LoadState {
        data object Loading : LoadState
        data class Ready(val source: EpgSource) : LoadState
        data class Failed(val message: String) : LoadState
    }

    companion object {
        /** Width of the visible timeline (Sky Q style 2 hour view). */
        val WINDOW_SPAN: Duration = Duration.ofHours(2)
        /** Step used when paging the timeline left or right. */
        val SLOT: Duration = Duration.ofMinutes(30)
        private const val KEY_REGION = "guide.region"
        private const val KEY_FAVOURITES = "guide.favourites"
        private const val KEY_SKY = "guide.includesSky"
        private const val KEY_SOURCE_TYPE = "guide.liveSourceType"
        private const val KEY_SOURCE_VALUE = "guide.liveSourceValue"
    }

    // MARK: State

    var region by mutableStateOf(Region.withId(prefs.getString(KEY_REGION, null))); private set
    var channels by mutableStateOf(ChannelLineup.channels(region)); private set
    var schedules by mutableStateOf<Map<String, List<Programme>>>(emptyMap()); private set
    var state by mutableStateOf<LoadState>(LoadState.Loading); private set
    var now by mutableStateOf(clock()); private set
    var favourites by mutableStateOf(prefs.getStringSet(KEY_FAVOURITES, emptySet())!!.toSet()); private set
    var category by mutableStateOf(ChannelCategory.ALL)
    var windowStart by mutableStateOf(SampleSchedule.alignedDown(clock(), 30)); private set
    /** "I have Sky / NOW": adds the Sky TV channels (radio is always included). */
    var includesSky by mutableStateOf(prefs.getBoolean(KEY_SKY, true)); private set

    /** Channel being watched full screen. */
    var tunedChannelId by mutableStateOf<String?>(null)
    var liveSource by mutableStateOf(readLiveSource()); private set
    var liveStatus by mutableStateOf<String?>(null); private set
    /** Live stream per channel id from the viewer's live TV source. */
    var tunerStreams by mutableStateOf<Map<String, String>>(emptyMap()); private set
    /** Song playing now on Rayo stations, by channel id. */
    val nowPlaying = mutableStateMapOf<String, String>()

    private var logos: Map<String, String> = emptyMap()
    private var internetSchedules: Map<String, List<Programme>> = emptyMap()
    private var skyChannels: List<Channel> = emptyList()
    private var skySchedules: Map<String, List<Programme>> = emptyMap()
    private var tunerSchedules: Map<String, List<Programme>> = emptyMap()
    private var radioSchedules: Map<String, List<Programme>> = emptyMap()
    private var rayoStations: Map<String, RayoService.Station> = emptyMap()
    private var clockJob: Job? = null

    // MARK: Loading

    fun start() {
        if (clockJob != null) return
        rebuildChannels()
        clockJob = viewModelScope.launch {
            while (isActive) {
                delay(15_000)
                tick(clock())
            }
        }
        viewModelScope.launch { load() }
        viewModelScope.launch { loadLiveSource() }
    }

    fun refresh() = viewModelScope.launch { load(forceRefresh = true) }

    suspend fun load(forceRefresh: Boolean = false) {
        if (schedules.isEmpty()) state = LoadState.Loading
        val ids = ChannelLineup.channels(region).map { it.id }.toSet() +
            RADIO_CATALOGUE.map { it.id }.filterNot { it.startsWith("radio:") }
        // Sky and Rayo download alongside the Freeview feed.
        val skyJob = viewModelScope.async { loadSky() }
        val rayoJob = viewModelScope.async { loadRayo() }
        try {
            apply(epg.load(ids, forceRefresh))
        } catch (e: Exception) {
            when {
                tunerSchedules.isNotEmpty() -> {
                    internetSchedules = emptyMap()
                    assembleSchedules()
                    state = LoadState.Ready(EpgSource.Tuner)
                }
                internetSchedules.isEmpty() || state == LoadState.Ready(EpgSource.Sample) -> {
                    internetSchedules = SampleSchedule.make(ChannelLineup.channels(region), now)
                    assembleSchedules()
                    state = LoadState.Ready(EpgSource.Sample)
                }
                else -> state = LoadState.Failed(e.message ?: "Couldn't refresh listings")
            }
        }
        skyJob.await()
        rayoJob.await()
    }

    fun apply(snapshot: EpgSnapshot) {
        logos = snapshot.logos
        internetSchedules = snapshot.programmes
        assembleSchedules()
        rebuildChannels()
        state = LoadState.Ready(snapshot.source)
    }

    fun selectRegion(new: Region) {
        if (new == region) return
        region = new
        prefs.edit().putString(KEY_REGION, new.id).apply()
        rebuildChannels()
        viewModelScope.launch { load() }
    }

    fun selectIncludesSky(enabled: Boolean) {
        if (enabled == includesSky) return
        includesSky = enabled
        prefs.edit().putBoolean(KEY_SKY, enabled).apply()
        if (!enabled) {
            // Drop Sky TV straight away (radio stays), even if the refresh fails.
            skyChannels = skyChannels.filter { it.isRadio }
            val keep = skyChannels.map { it.id }.toSet()
            skySchedules = skySchedules.filterKeys { it in keep }
            assembleSchedules()
            rebuildChannels()
        }
        viewModelScope.launch { loadSky() }
    }

    private suspend fun loadSky() {
        val used = ChannelLineup.channels(region).map { it.number }.toSet()
        val (loaded, programmes) = runCatching { sky.load(used, includesSky, now) }.getOrNull() ?: return
        skyChannels = loaded
        skySchedules = programmes
        assembleSchedules()
        rebuildChannels()
    }

    /** Live details (streams, logos, show on air, song) for Rayo stations. */
    private suspend fun loadRayo() {
        val codes = RADIO_CATALOGUE.mapNotNull { station -> station.rayoCode?.let { it to station.id } }.toMap()
        val stations = rayo.stations(codes.keys, codes)
        rayoStations = stations
        radioSchedules = stations.mapNotNull { (code, s) -> s.onAir?.let { codes.getValue(code) to listOf(it) } }.toMap()
        stations.forEach { (code, s) -> s.nowPlaying?.let { nowPlaying[codes.getValue(code)] = it } }
        assembleSchedules()
        rebuildChannels()
    }

    /** Updates the song on a Rayo station (called while its radio screen is showing). */
    suspend fun refreshNowPlaying(channel: Channel) {
        val code = RADIO_CATALOGUE.firstOrNull { it.id == channel.id }?.rayoCode ?: return
        rayo.nowPlaying(code)?.let { nowPlaying[channel.id] = it }
    }

    /**
     * Internet listings first, then Sky's, then the live TV source's guide and Rayo's
     * on-air shows for anything still empty; radio without listings gets a
     * day-long "live" entry.
     */
    private fun assembleSchedules() {
        val merged = HashMap(internetSchedules)
        skySchedules.forEach { (id, list) -> merged.putIfAbsent(id, list) }
        for ((id, list) in tunerSchedules) if (merged[id].isNullOrEmpty()) merged[id] = list
        for ((id, list) in radioSchedules) if (merged[id].isNullOrEmpty()) merged[id] = list
        for (station in RADIO_CATALOGUE) if (merged[station.id].isNullOrEmpty()) merged[station.id] = listOf(liveRadioListing(station))
        schedules = merged
    }

    private fun liveRadioListing(station: CatalogueStation): Programme {
        val start = SampleSchedule.alignedDown(now, 24 * 60)
        val strapline = station.rayoCode?.let { rayoStations[it]?.strapline }
        return Programme(station.id, station.name, synopsis = strapline ?: station.tagline ?: "Live radio · ${station.region}",
            start = start, end = start.plus(Duration.ofDays(2)))
    }

    private val catalogueChannels: List<Channel>
        get() = RADIO_CATALOGUE.map { s ->
            val r = s.rayoCode?.let { rayoStations[it] }
            Channel(s.number, s.name, s.id, ChannelCategory.RADIO, brand = r?.colour ?: "1F4FD1", logo = r?.logo)
        }

    /** TV in Sky's order, then radio, like the Sky guide. */
    private fun rebuildChannels() {
        channels = (ChannelLineup.channels(region) + skyChannels + catalogueChannels)
            .map { c -> logos[c.id]?.let { c.copy(logo = it) } ?: c }
            .sortedWith(compareBy({ if (it.isRadio) 1 else 0 }, { it.number }))
    }

    fun tick(date: Instant) {
        val previousEarliest = earliestWindowStart
        now = date
        // Keep the window pinned to "now" if the viewer hasn't scrolled away.
        if (windowStart == previousEarliest || windowStart.isBefore(earliestWindowStart)) windowStart = earliestWindowStart
    }

    // MARK: Channels

    val visibleChannels: List<Channel>
        get() = when (category) {
            ChannelCategory.ALL -> channels.filter { !it.isRadio }
            ChannelCategory.FAVOURITES -> channels.filter { it.id in favourites }
            else -> channels.filter { it.category == category }
        }

    fun channel(id: String) = channels.firstOrNull { it.id == id }

    fun isFavourite(channel: Channel) = channel.id in favourites

    fun toggleFavourite(channel: Channel) {
        favourites = if (channel.id in favourites) favourites - channel.id else favourites + channel.id
        prefs.edit().putStringSet(KEY_FAVOURITES, favourites).apply()
    }

    // MARK: Listings

    fun current(channel: Channel) = schedules[channel.id]?.firstOrNull { it.isOn(now) }

    fun next(channel: Channel) = schedules[channel.id]?.firstOrNull { !it.start.isBefore(now) }

    fun upcoming(after: Programme, limit: Int = 5) =
        schedules[after.channelId].orEmpty().filter { !it.start.isBefore(after.end) }.take(limit)

    // MARK: Live TV

    /** Every stream to try for a channel, best first (the player moves on if one fails). */
    fun streams(channel: Channel): List<String> {
        val own = listOfNotNull(tunerStreams[channel.id])
        if (!channel.isRadio) return own
        val station = RADIO_CATALOGUE.firstOrNull { it.id == channel.id }
        val radio = when {
            channel.id.startsWith("sky:") -> listOfNotNull(SKY_RADIO[channel.number]?.stream)
            station?.fixedStream != null -> listOf(station.fixedStream!!)
            else -> station?.rayoCode?.let { rayoStations[it]?.streams }.orEmpty()
        }
        return own + radio
    }

    val tunedChannel: Channel? get() = tunedChannelId?.let(::channel)

    fun tune(channel: Channel) {
        tunedChannelId = channel.id
    }

    /** Channel up / down: TV through TV channels, radio through radio stations. */
    fun channelAfter(channel: Channel, offset: Int): Channel? {
        val list = channels.filter { it.isRadio == channel.isRadio }
        val index = list.indexOfFirst { it.id == channel.id }
        if (list.isEmpty() || index < 0) return null
        return list[Math.floorMod(index + offset, list.size)]
    }

    fun useLiveSource(source: LiveSource?) {
        liveSource = source
        prefs.edit().apply {
            when (source) {
                null -> remove(KEY_SOURCE_TYPE).remove(KEY_SOURCE_VALUE)
                is LiveSource.ChannelsDvr -> putString(KEY_SOURCE_TYPE, "channels").putString(KEY_SOURCE_VALUE, source.server)
                is LiveSource.Playlist -> putString(KEY_SOURCE_TYPE, "playlist").putString(KEY_SOURCE_VALUE, source.url)
            }
        }.apply()
        viewModelScope.launch { loadLiveSource() }
    }

    /** Connects to a source and returns an error message, or null on success (used by the Live TV screen). */
    suspend fun connect(source: LiveSource): String? = runCatching { fetch(source) }.fold(
        onSuccess = { useLiveSource(source); null },
        onFailure = { "Couldn't connect: ${it.message ?: it.javaClass.simpleName}" },
    )

    suspend fun loadLiveSource() {
        val source = liveSource ?: run {
            tunerStreams = emptyMap(); tunerSchedules = emptyMap(); liveStatus = null
            assembleSchedules()
            return
        }
        try {
            val data = fetch(source)
            tunerStreams = data.streams
            tunerSchedules = data.guide
            if (data.guide.isNotEmpty() && state == LoadState.Ready(EpgSource.Sample)) {
                // Real listings from the live TV source beat generated sample ones.
                internetSchedules = emptyMap()
                state = LoadState.Ready(EpgSource.Tuner)
            }
            assembleSchedules()
            val tv = channels.count { !it.isRadio }
            liveStatus = "${source.label}: ${data.streams.size} of $tv channels can play live" +
                if (data.guide.isNotEmpty()) " · guide for ${data.guide.size} channels from your live TV source" else ""
        } catch (e: Exception) {
            liveStatus = "Couldn't reach ${source.label}: ${e.message ?: "unknown error"}"
        }
    }

    private suspend fun fetch(source: LiveSource): TunerData {
        val all = channels
        return when (source) {
            is LiveSource.ChannelsDvr -> ChannelsDvr.load(source.server, all, now)
            is LiveSource.Playlist -> PlaylistSource.load(source.url, all)
        }
    }

    private fun readLiveSource(): LiveSource? {
        val value = prefs.getString(KEY_SOURCE_VALUE, null) ?: return null
        return when (prefs.getString(KEY_SOURCE_TYPE, null)) {
            "channels" -> LiveSource.ChannelsDvr(value)
            "playlist" -> LiveSource.Playlist(value)
            else -> null
        }
    }

    // MARK: Search

    data class SearchResults(
        val channels: List<Channel> = emptyList(),
        val onNow: List<Programme> = emptyList(),
        val later: List<Programme> = emptyList(),
    ) {
        val isEmpty get() = channels.isEmpty() && onNow.isEmpty() && later.isEmpty()
    }

    /** Channels by name and programmes by title (words in any order, ignoring case and accents). */
    fun search(query: String, limit: Int = 60): SearchResults {
        val terms = fold(query).split(" ").filter { it.isNotEmpty() }
        if (terms.isEmpty()) return SearchResults()
        fun matches(text: String) = fold(text).let { f -> terms.all { f.contains(it) } }
        val onNow = ArrayList<Programme>()
        val later = ArrayList<Programme>()
        val seen = HashSet<String>()
        for (c in channels) for (p in schedules[c.id].orEmpty()) {
            if (!p.end.isAfter(now) || !matches(p.title) || !seen.add(p.id)) continue
            if (p.isOn(now)) onNow += p else later += p
        }
        val order = channels.withIndex().associate { it.value.id to it.index }
        return SearchResults(
            channels = channels.filter { matches(it.name) },
            onNow = onNow.sortedBy { order[it.channelId] ?: 0 },
            later = later.sortedBy { it.start }.take(limit),
        )
    }

    private fun fold(text: String) =
        Normalizer.normalize(text.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "")

    // MARK: Timeline window

    val windowEnd: Instant get() = windowStart.plus(WINDOW_SPAN)
    val earliestWindowStart: Instant get() = SampleSchedule.alignedDown(now, 30)
    val latestWindowStart: Instant
        get() {
            val lastEnd = schedules.values.mapNotNull { it.lastOrNull()?.end }.maxOrNull() ?: now.plus(Duration.ofDays(1))
            val latest = SampleSchedule.alignedDown(lastEnd.minus(WINDOW_SPAN), 30)
            return if (latest.isAfter(earliestWindowStart)) latest else earliestWindowStart
        }
    val isAtNow: Boolean get() = !windowStart.isAfter(earliestWindowStart)

    /** Moves the window by whole 30 minute slots. Returns true if it moved. */
    fun shiftWindow(slots: Int): Boolean {
        var target = windowStart.plus(SLOT.multipliedBy(slots.toLong()))
        if (target.isBefore(earliestWindowStart)) target = earliestWindowStart
        if (target.isAfter(latestWindowStart)) target = latestWindowStart
        if (target == windowStart) return false
        windowStart = target
        return true
    }

    fun jump(to: Instant) {
        var aligned = SampleSchedule.alignedDown(to, 30)
        if (aligned.isBefore(earliestWindowStart)) aligned = earliestWindowStart
        if (aligned.isAfter(latestWindowStart)) aligned = latestWindowStart
        windowStart = aligned
    }

    fun jumpToNow() {
        windowStart = earliestWindowStart
    }

    /**
     * The listings in a grid row for the current window, with holes filled by
     * placeholder cells so every slot can take focus.
     */
    fun segments(channel: Channel): List<Programme> {
        val start = windowStart
        val end = windowEnd
        val listings = schedules[channel.id].orEmpty().filter { it.overlaps(start, end) }
        val result = ArrayList<Programme>()
        var cursor = start
        var holeStart: Instant? = null // null: the hole began before the window
        for (p in listings) {
            if (p.start.isAfter(cursor)) result += placeholders(channel.id, holeStart, cursor, p.start)
            result += p
            if (p.end.isAfter(cursor)) cursor = p.end
            holeStart = cursor
        }
        if (cursor.isBefore(end)) result += placeholders(channel.id, holeStart, cursor, end)
        return result
    }

    /** Splits a hole on the absolute 30 minute grid so placeholder ids stay stable as the window pages. */
    private fun placeholders(channelId: String, holeStart: Instant?, visible: Instant, end: Instant): List<Programme> {
        val cells = ArrayList<Programme>()
        var slotStart = SampleSchedule.alignedDown(visible, 30)
        while (slotStart.isBefore(end)) {
            val slotEnd = slotStart.plus(SLOT)
            val cellStart = if (holeStart != null && holeStart.isAfter(slotStart)) holeStart else slotStart
            val cellEnd = if (slotEnd.isBefore(end)) slotEnd else end
            val visibleStart = if (cellStart.isAfter(visible)) cellStart else visible
            if (cellEnd.isAfter(visibleStart)) cells += Programme.placeholder(channelId, cellStart, cellEnd)
            slotStart = slotEnd
        }
        return cells
    }
}
