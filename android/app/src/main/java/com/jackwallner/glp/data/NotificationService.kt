package com.jackwallner.glp.data

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
import androidx.core.content.ContextCompat
import com.jackwallner.glp.MainActivity
import com.jackwallner.glp.R
import com.jackwallner.glp.model.*
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import java.time.DayOfWeek
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

class NotificationService(private val context: Context) {
    private val alarms = context.getSystemService(AlarmManager::class.java)
    private val manager = context.getSystemService(NotificationManager::class.java)
    init {
        manager.createNotificationChannel(NotificationChannel("dose", "Dose reminders", NotificationManager.IMPORTANCE_DEFAULT))
        manager.createNotificationChannel(NotificationChannel("wait", "Running pill countdown", NotificationManager.IMPORTANCE_LOW))
    }
    fun permitted(): Boolean = (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) && manager.areNotificationsEnabled()
    private fun pending(id: Int, title: String = "", body: String = "", actions: Boolean = false): PendingIntent = PendingIntent.getBroadcast(context, id,
        Intent(context, ReminderReceiver::class.java).putExtra("id", id).putExtra("title", title).putExtra("body", body).putExtra("actions", actions), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancel(ids: Iterable<Int>) { ids.forEach { alarms.cancel(pending(it)); manager.cancel(it) } }
    fun cancelAll() { cancel(0..24) }
    private fun schedule(id: Int, at: Instant, title: String, body: String, actions: Boolean = false) {
        if (at <= Instant.now() || !permitted()) return
        // Inexact alarms need no exact-alarm permission or Play declaration.
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.toEpochMilli(), pending(id, title, body, actions))
    }
    fun sync(store: TrackerStore, isPro: Boolean, entitlementsResolved: Boolean, now: Instant = Instant.now()) {
        cancel((0..14).toList() + 21); val p = store.plan ?: run { cancelAll(); return }; val zone = ZoneId.systemDefault()
        if (p.reminderEnabled) ScheduleEngine.reminderSlots(now, p, store.events, zone).forEachIndexed { index, slot ->
            val title = if (p.form == DoseForm.PILL) "Pill time" else "Shot day"
            val body = if (p.form == DoseForm.PILL) "Time for your ${p.name}. One tap when it's done." else "Your ${p.name} dose is planned for today. One tap when it's done."
            schedule(index, slot.minusSeconds(p.reminderLeadMinutes * 60L), title, body, true)
        }
        val latest = store.events.filter { it.timestamp <= now && it.medication == p.name }.maxByOrNull { it.timestamp }
        val waitEnd = DoseRoutine.waitEnd(p, store.events, now)
        waitEnd?.let { end ->
            if (latest != null) schedule(14, end, "Your ${p.wait}-minute wait is over", "${latest.medication} taken at ${latest.timestamp.atZone(zone).toLocalTime().withSecond(0)}.")
        }
        syncCountdown(p, waitEnd, isPro, entitlementsResolved, now)
        if (!entitlementsResolved) return
        cancel(15..19)
        if (!isPro) return
        SupplyMath.remaining(p, store.events)?.let { count -> SupplyMath.reminder(count, p, now, zone)?.let { at ->
            schedule(15, at, "Refill soon", "About 7 days of ${p.name} left, based on what you've logged.")
        } }
        val prefs = store.alerts
        if (!prefs.enabled) return
        val next = ScheduleEngine.nextUnclaimed(now, p, store.events, zone)
        schedule(16, ProactiveAlerts.lateFire(next, prefs, zone), "Your ${p.form.noun} isn't logged yet", "A quick check-in can help you stay on track.", true)
        if (prefs.patterns) ProactiveAlerts.patterns(store.events, prefs.sensitivity, zone).take(3).forEachIndexed { index, (weekday, _) ->
            var at = now.atZone(zone).with(TemporalAdjusters.nextOrSame(DayOfWeek.of(weekday))).withHour(9).withMinute(0).withSecond(0)
            if (at.toInstant() <= now) at = at.plusWeeks(1)
            if (!prefs.isQuiet(at.hour)) schedule(17 + index, at.toInstant(), "Simple GLP pattern", "Most of your logged ${p.form.noun}s happen on ${at.dayOfWeek.name.lowercase().replaceFirstChar(Char::uppercase)}. Want to log today's dose?")
        }
    }
    private fun syncCountdown(plan: Plan, end: Instant?, isPro: Boolean, resolved: Boolean, now: Instant) {
        if (end == null || !permitted() || (resolved && !isPro)) {
            manager.cancel(COUNTDOWN_ID)
            return
        }
        if (!resolved) {
            val existing = manager.activeNotifications.firstOrNull { it.id == COUNTDOWN_ID }
            if (existing != null && existing.notification.`when` != end.toEpochMilli()) manager.cancel(COUNTDOWN_ID)
            return
        }
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val endLabel = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withZone(ZoneId.systemDefault()).format(end)
        val notification = NotificationCompat.Builder(context, "wait")
            .setSmallIcon(R.drawable.ic_notification).setContentTitle("Your wait timer")
            .setContentText("${plan.wait}-minute wait · ends $endLabel")
            .setWhen(end.toEpochMilli()).setShowWhen(true).setUsesChronometer(true).setChronometerCountDown(true)
            .setTimeoutAfter((end.toEpochMilli() - now.toEpochMilli()).coerceAtLeast(1))
            .setOngoing(true).setOnlyAlertOnce(true).setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC).setCategory(NotificationCompat.CATEGORY_STATUS)
            .setContentIntent(open).build()
        manager.notify(COUNTDOWN_ID, notification)
    }
    fun post(intent: Intent) {
        if (!permitted()) return
        val id = intent.getIntExtra("id", 0)
        if (id == 14) manager.cancel(COUNTDOWN_ID)
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, "dose").setSmallIcon(R.drawable.ic_notification).setContentTitle(intent.getStringExtra("title")).setContentText(intent.getStringExtra("body")).setContentIntent(open).setAutoCancel(true)
        if (intent.getBooleanExtra("actions", false)) {
            fun action(name: String): PendingIntent = PendingIntent.getBroadcast(context, 100 + id * 2 + if (name == "log") 0 else 1,
                Intent(context, ReminderReceiver::class.java).setAction(name).putExtra("id", id).putExtra("title", intent.getStringExtra("title")).putExtra("body", intent.getStringExtra("body")), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            notification.addAction(0, "Took it", action("log")).addAction(0, "Remind me in 15 min", action("snooze"))
        }
        manager.notify(id, notification.build())
    }
    companion object { const val COUNTDOWN_ID = 22 }
    fun snooze(intent: Intent) { manager.cancel(intent.getIntExtra("id", 0)); schedule(21, Instant.now().plusSeconds(900), intent.getStringExtra("title") ?: "Dose reminder", intent.getStringExtra("body") ?: "", true) }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val graph = (context.applicationContext as com.jackwallner.glp.GLPApplication).graph
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_TIME_CHANGED -> {
                val pending = goAsync()
                CoroutineScope(SupervisorJob() + Dispatchers.Main).launch {
                    try { withTimeoutOrNull(8000) { graph.store.refresh() }; graph.notifications.sync(graph.tracker, graph.store.isPro, graph.store.resolved) }
                    finally { pending.finish() }
                }
            }
            "log" -> {
                val p = graph.tracker.plan ?: return
                val now = Instant.now()
                if (!DoseRoutine.alreadyLogged(now, p, graph.tracker.events)) graph.tracker.log(now)
                graph.notifications.sync(graph.tracker, graph.store.isPro, graph.store.resolved)
            }
            "snooze" -> graph.notifications.snooze(intent)
            else -> graph.notifications.post(intent)
        }
    }
}
