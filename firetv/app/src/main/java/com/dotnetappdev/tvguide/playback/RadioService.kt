package com.dotnetappdev.tvguide.playback

import android.content.Context
import android.content.Intent
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Plays radio in the background (it keeps going when you press Home, like a
 * music app) and publishes a media session, so Fire TV shows what's playing.
 * If a station's stream fails it moves on to the station's next stream.
 */
class RadioService : MediaSessionService() {
    private var session: MediaSession? = null
    private var streams: List<String> = emptyList()
    private var index = 0
    private var station = ""
    private var show = ""

    override fun onCreate() {
        super.onCreate()
        val player = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(), true)
            .setHandleAudioBecomingNoisy(true)
            .build()
        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                if (index + 1 < streams.size) {
                    index++
                    playCurrent()
                }
            }
        })
        session = MediaSession.Builder(this, player).build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            ACTION_PLAY -> {
                streams = intent.getStringArrayListExtra(EXTRA_STREAMS).orEmpty()
                station = intent.getStringExtra(EXTRA_STATION).orEmpty()
                show = intent.getStringExtra(EXTRA_SHOW).orEmpty()
                index = 0
                playCurrent()
            }
            ACTION_UPDATE -> {
                show = intent.getStringExtra(EXTRA_SHOW).orEmpty()
                session?.player?.let { p ->
                    p.currentMediaItem?.let { item -> p.replaceMediaItem(0, item.buildUpon().setMediaMetadata(metadata()).build()) }
                }
            }
            ACTION_STOP -> {
                session?.player?.stop()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun playCurrent() {
        val player = session?.player ?: return
        val url = streams.getOrNull(index) ?: return
        player.setMediaItem(MediaItem.Builder().setUri(url).setMediaMetadata(metadata()).build())
        player.prepare()
        player.play()
    }

    private fun metadata() = MediaMetadata.Builder().setTitle(show.ifEmpty { station }).setArtist(station).setStation(station).build()

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    override fun onTaskRemoved(rootIntent: Intent?) {
        session?.player?.stop()
        stopSelf()
    }

    override fun onDestroy() {
        session?.run {
            player.release()
            release()
        }
        session = null
        super.onDestroy()
    }

    companion object {
        private const val ACTION_PLAY = "play"
        private const val ACTION_UPDATE = "update"
        private const val ACTION_STOP = "stop"
        private const val EXTRA_STREAMS = "streams"
        private const val EXTRA_STATION = "station"
        private const val EXTRA_SHOW = "show"

        fun play(context: Context, streams: List<String>, station: String, show: String?) {
            context.startService(Intent(context, RadioService::class.java).setAction(ACTION_PLAY)
                .putStringArrayListExtra(EXTRA_STREAMS, ArrayList(streams))
                .putExtra(EXTRA_STATION, station).putExtra(EXTRA_SHOW, show))
        }

        fun updateShow(context: Context, show: String?) {
            context.startService(Intent(context, RadioService::class.java).setAction(ACTION_UPDATE).putExtra(EXTRA_SHOW, show))
        }

        fun stop(context: Context) {
            context.startService(Intent(context, RadioService::class.java).setAction(ACTION_STOP))
        }
    }
}
