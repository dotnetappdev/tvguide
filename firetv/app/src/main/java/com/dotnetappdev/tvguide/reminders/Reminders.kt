package com.dotnetappdev.tvguide.reminders

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import com.dotnetappdev.tvguide.MainActivity
import com.dotnetappdev.tvguide.R
import com.dotnetappdev.tvguide.data.Channel
import com.dotnetappdev.tvguide.data.Programme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

/** A programme the viewer asked to be reminded about (stored with Room). */
@Entity(tableName = "reminders")
data class Reminder(
    @PrimaryKey val programmeId: String,
    val channelId: String,
    val channelName: String,
    val title: String,
    val start: Long,
    val end: Long,
)

@Dao
interface ReminderDao {
    @Query("SELECT * FROM reminders ORDER BY start")
    fun observeAll(): Flow<List<Reminder>>

    @Query("SELECT * FROM reminders ORDER BY start")
    suspend fun all(): List<Reminder>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(reminder: Reminder)

    @Query("DELETE FROM reminders WHERE programmeId = :id")
    suspend fun delete(id: String)

    @Query("DELETE FROM reminders WHERE `end` < :now")
    suspend fun deleteExpired(now: Long)
}

@Database(entities = [Reminder::class], version = 1, exportSchema = false)
abstract class ReminderDatabase : RoomDatabase() {
    abstract fun reminders(): ReminderDao

    companion object {
        @Volatile private var instance: ReminderDatabase? = null
        fun get(context: Context): ReminderDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(context.applicationContext, ReminderDatabase::class.java, "reminders.db").build()
                .also { instance = it }
        }
    }
}

/**
 * Reminders: stored in Room, a notification a minute before the start
 * (AlarmManager), and an in-app alert while the guide is open.
 */
class ReminderStore(private val context: Context) {
    private val dao = ReminderDatabase.get(context).reminders()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val alerted = HashSet<String>()

    val reminders: Flow<List<Reminder>> = dao.observeAll()

    init {
        scope.launch {
            dao.deleteExpired(System.currentTimeMillis() / 1000)
            dao.all().forEach { schedule(context, it) }
        }
    }

    fun toggle(programme: Programme, channel: Channel, isSet: Boolean) = scope.launch {
        if (isSet) {
            dao.delete(programme.id)
            cancel(context, programme.id)
        } else if (!programme.isPlaceholder && programme.start.epochSecond > System.currentTimeMillis() / 1000) {
            val reminder = Reminder(programme.id, channel.id, channel.name, programme.title, programme.start.epochSecond, programme.end.epochSecond)
            dao.insert(reminder)
            schedule(context, reminder)
        }
    }

    fun remove(reminder: Reminder) = scope.launch {
        dao.delete(reminder.programmeId)
        cancel(context, reminder.programmeId)
    }

    /** The next reminder that should pop up now in the app, if any. */
    fun due(list: List<Reminder>, nowSeconds: Long): Reminder? = list.firstOrNull {
        it.programmeId !in alerted && it.start - nowSeconds <= LEAD_SECONDS && nowSeconds < it.end
    }?.also { alerted += it.programmeId }

    companion object {
        const val LEAD_SECONDS = 60L
        const val CHANNEL = "reminders"
        const val EXTRA_CHANNEL_ID = "channelId"

        fun schedule(context: Context, reminder: Reminder) {
            val at = (reminder.start - LEAD_SECONDS) * 1000
            if (at < System.currentTimeMillis() - 60_000) return
            val alarms = context.getSystemService(AlarmManager::class.java)
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(context, reminder))
        }

        fun cancel(context: Context, programmeId: String) {
            val intent = Intent(context, ReminderReceiver::class.java).setAction(programmeId)
            PendingIntent.getBroadcast(context, programmeId.hashCode(), intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE)
                ?.let { context.getSystemService(AlarmManager::class.java).cancel(it) }
        }

        private fun pending(context: Context, r: Reminder): PendingIntent {
            val intent = Intent(context, ReminderReceiver::class.java).setAction(r.programmeId)
                .putExtra("title", r.title).putExtra("channelName", r.channelName)
                .putExtra(EXTRA_CHANNEL_ID, r.channelId).putExtra("start", r.start)
            return PendingIntent.getBroadcast(context, r.programmeId.hashCode(), intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL) == null) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL, "Programme reminders", NotificationManager.IMPORTANCE_HIGH))
            }
        }
    }
}

/** Posts the "starting soon" notification; selecting it opens the guide on that channel. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        ReminderStore.ensureChannel(context)
        val channelId = intent.getStringExtra(ReminderStore.EXTRA_CHANNEL_ID)
        val open = PendingIntent.getActivity(context, channelId.hashCode(),
            Intent(context, MainActivity::class.java).putExtra(ReminderStore.EXTRA_CHANNEL_ID, channelId)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = NotificationCompat.Builder(context, ReminderStore.CHANNEL)
            .setSmallIcon(R.drawable.ic_reminder)
            .setContentTitle("Starting soon: ${intent.getStringExtra("title")}")
            .setContentText("On ${intent.getStringExtra("channelName")} – select to watch")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(intent.action.hashCode(), notification)
    }
}

/** Alarms don't survive a restart; schedule them again. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                ReminderDatabase.get(context).reminders().all().forEach { ReminderStore.schedule(context, it) }
            } finally {
                pending.finish()
            }
        }
    }
}
