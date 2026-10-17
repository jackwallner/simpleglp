package com.jackwallner.glp.data

import com.jackwallner.glp.model.*
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime

object Codec {
    fun plan(value: Plan): String = JSONObject().apply {
        put("medication", value.medication.name); put("customName", value.customName); put("doseMg", value.doseMg)
        put("start", value.start.toString()); put("time", value.time.toString()); put("intervalDays", value.intervalDays)
        put("waitMinutes", value.waitMinutes); put("reminderEnabled", value.reminderEnabled)
        put("reminderLeadMinutes", value.reminderLeadMinutes); put("supplyCount", value.supplyCount)
        put("supplyUpdatedAt", value.supplyUpdatedAt?.toString())
        put("steps", JSONArray(value.steps.map { JSONObject().put("start", it.start.toString()).put("doseMg", it.doseMg).put("note", it.note) }))
    }.toString()
    fun plan(text: String): Plan = JSONObject(text).let { o ->
        Plan(Medication.valueOf(o.getString("medication")), o.optString("customName"), o.getDouble("doseMg"),
            LocalDate.parse(o.getString("start")), LocalTime.parse(o.getString("time")), o.getInt("intervalDays"),
            o.getInt("waitMinutes"), o.getBoolean("reminderEnabled"), o.optInt("reminderLeadMinutes"), o.optInt("supplyCount"),
            o.optString("supplyUpdatedAt").takeIf { it.isNotBlank() }?.let(Instant::parse),
            o.optJSONArray("steps")?.let { a -> (0 until a.length()).map { a.getJSONObject(it).let { s -> DoseStep(Instant.parse(s.getString("start")), s.getDouble("doseMg"), s.optString("note")) } } }.orEmpty())
    }
    fun events(values: List<DoseEvent>): String = JSONArray(values.map { e -> JSONObject().apply {
        put("id", e.id); put("timestamp", e.timestamp.toString()); put("medication", e.medication); put("doseMg", e.doseMg)
        put("scheduledDate", e.scheduledDate?.toString()); put("status", e.status.name); put("minutes", e.minutesFromSchedule)
        put("site", e.site); put("notes", e.notes); put("context", JSONArray(e.context))
    } }).toString()
    fun events(text: String): List<DoseEvent> = JSONArray(text).let { a -> (0 until a.length()).map { a.getJSONObject(it).let { o ->
        DoseEvent(o.getString("id"), Instant.parse(o.getString("timestamp")), o.getString("medication"), o.getDouble("doseMg"),
            o.optString("scheduledDate").takeIf(String::isNotBlank)?.let(Instant::parse), MatchStatus.valueOf(o.getString("status")),
            if (o.has("minutes")) o.getInt("minutes") else null, o.optString("site"), o.optString("notes"),
            o.optJSONArray("context")?.let { c -> (0 until c.length()).map(c::getString) } ?: List(17) { "" })
    } } }
}

object Csv {
    val columns = listOf("timestamp", "medication", "dose_mg", "schedule_status", "injection_site", "notes", "nausea", "appetite", "food_noise", "wellbeing", "body_mass_kg", "blood_glucose_mg_per_dl", "steps_today", "active_energy_kcal_today", "exercise_minutes_today", "sleep_hours_last_night", "resting_heart_rate_bpm", "recent_heart_rate_average_bpm", "workouts_last_24h", "water_ml_today", "caffeine_mg_today", "dietary_energy_kcal_today", "protein_grams_today")
    fun escape(field: String): String = if (field.any { it in ",\"\r\n" }) "\"${field.replace("\"", "\"\"") }\"" else field
    fun export(events: List<DoseEvent>): String = (listOf(columns.joinToString(",")) + events.sortedBy { it.timestamp }.map { e ->
        (listOf(e.timestamp.toString(), e.medication, e.doseMg.toString(), e.status.raw, e.site, e.notes) + e.context.take(17).let { it + List((17-it.size).coerceAtLeast(0)) { "" } }).joinToString(",", transform = ::escape)
    }).joinToString("\n")
    fun parse(text: String): List<List<String>> {
        val records = mutableListOf<List<String>>(); val row = mutableListOf<String>(); val field = StringBuilder()
        var quotes = false; var i = 0
        fun flushField() { row += field.toString(); field.clear() }
        fun flushRow() { flushField(); if (row.size != 1 || row[0].isNotEmpty()) records += row.toList(); row.clear() }
        while (i < text.length) {
            val c = text[i]
            if (quotes) {
                if (c == '"') {
                    if (i+1 < text.length && text[i+1] == '"') { field.append('"'); i++ } else quotes = false
                } else field.append(c)
            } else when (c) {
                '"' -> quotes = true
                ',' -> flushField()
                '\r', '\n' -> { flushRow(); if (c == '\r' && i+1 < text.length && text[i+1] == '\n') i++ }
                else -> field.append(c)
            }
            i++
        }
        require(!quotes) { "The CSV contains an unfinished quoted field." }
        if (field.isNotEmpty() || row.isNotEmpty()) flushRow()
        return records
    }
    fun import(text: String, plan: Plan?, existing: List<DoseEvent>): List<DoseEvent> {
        val known = existing.toMutableList(); val imported = mutableListOf<DoseEvent>()
        parse(text.removePrefix("\uFEFF")).forEach { c ->
            val at = c.firstOrNull()?.let { runCatching { Instant.parse(it) }.getOrNull() } ?: return@forEach
            if (c.size < 3) return@forEach
            val match = ScheduleEngine.match(at, plan, known)
            val event = DoseEvent(timestamp = at, medication = c[1].ifBlank { "GLP-1" }, doseMg = c[2].toDoubleOrNull() ?: 0.0,
                scheduledDate = match.scheduled, status = match.status, minutesFromSchedule = match.minutes,
                site = c.getOrElse(4) { "" }, notes = c.getOrElse(5) { "" }, context = (6..22).map { c.getOrElse(it) { "" } })
            known += event; imported += event
        }
        return imported
    }
}
