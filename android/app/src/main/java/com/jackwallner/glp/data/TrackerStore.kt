package com.jackwallner.glp.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.glp.model.*
import java.time.Instant

class TrackerStore(context: Context) {
    private val prefs = context.getSharedPreferences("simpleglp", Context.MODE_PRIVATE)
    var plan by mutableStateOf(prefs.getString("plan", null)?.let { runCatching { Codec.plan(it) }.getOrNull() }); private set
    var events by mutableStateOf(runCatching { Codec.events(prefs.getString("events", "[]")!!) }.getOrDefault(emptyList())); private set
    var appearance by mutableStateOf(prefs.getString("appearance", "system")!!); private set
    var promptDetails by mutableStateOf(prefs.getBoolean("promptForDetails", false)); private set
    var alerts by mutableStateOf(AlertPreferences(prefs.getBoolean("proAlertsEnabled", false), prefs.getBoolean("proAlertQuietHoursEnabled", true), prefs.getInt("proAlertQuietStartHour", 22), prefs.getInt("proAlertQuietEndHour", 7), prefs.getBoolean("patternAlertsEnabled", false), prefs.getFloat("patternAlertSensitivity", 0f).toDouble())); private set
    var corruption by mutableStateOf<String?>(null); private set
    init {
        if (prefs.contains("plan") && plan == null) corruption = "Your saved plan could not be read. Your original data has been preserved."
        if (runCatching { Codec.events(prefs.getString("events", "[]")!!) }.isFailure) corruption = "Your saved history could not be read. Your original data has been preserved."
    }
    fun savePlan(value: Plan) { check(corruption == null); prefs.edit().putString("plan", Codec.plan(value)).commit().also { check(it) }; plan = value }
    private fun saveEvents(value: List<DoseEvent>) { check(corruption == null); check(prefs.edit().putString("events", Codec.events(value)).commit()); events = value }
    fun log(at: Instant = Instant.now(), site: String = "", notes: String = "", context: List<String> = List(17) { "" }, doseMg: Double? = null): DoseEvent {
        val p = checkNotNull(plan); val match = ScheduleEngine.match(at, p, events)
        val e = DoseEvent(timestamp = at, medication = p.name, doseMg = doseMg ?: match.dose, scheduledDate = match.scheduled, status = match.status, minutesFromSchedule = match.minutes, site = site, notes = notes, context = context)
        saveEvents(events + e); return e
    }
    fun remove(id: String) { saveEvents(events.filterNot { it.id == id }) }
    fun edit(event: DoseEvent) {
        val match = ScheduleEngine.match(event.timestamp, plan, events.filterNot { it.id == event.id })
        saveEvents(events.map { if (it.id == event.id) event.copy(scheduledDate = match.scheduled, status = match.status, minutesFromSchedule = match.minutes) else it })
    }
    fun importCsv(text: String): Int { val imported = Csv.import(text, plan, events); saveEvents(events + imported); return imported.size }
    fun updateAppearance(value: String) { appearance = value; prefs.edit().putString("appearance", value).apply() }
    fun updatePromptDetails(value: Boolean) { promptDetails = value; prefs.edit().putBoolean("promptForDetails", value).apply() }
    fun updateAlerts(value: AlertPreferences) {
        alerts = value
        prefs.edit().putBoolean("proAlertsEnabled", value.enabled).putBoolean("proAlertQuietHoursEnabled", value.quiet)
            .putInt("proAlertQuietStartHour", value.start).putInt("proAlertQuietEndHour", value.end)
            .putBoolean("patternAlertsEnabled", value.patterns).putFloat("patternAlertSensitivity", value.sensitivity.toFloat()).apply()
    }
    fun clearAll() { check(prefs.edit().clear().commit()); plan = null; events = emptyList(); corruption = null; alerts = AlertPreferences(); appearance = "system"; promptDetails = false }
}
