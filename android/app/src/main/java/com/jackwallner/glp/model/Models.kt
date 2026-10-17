package com.jackwallner.glp.model

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlin.math.abs
import kotlin.math.roundToInt

enum class DoseForm(val noun: String, val interval: Int, val hour: Int) {
    INJECTION("shot", 7, 9), PILL("pill", 1, 7)
}

enum class Medication(val label: String, val doses: List<Double>, val form: DoseForm = DoseForm.INJECTION, val wait: Int = 0) {
    OZEMPIC("Ozempic", listOf(0.25, 0.5, 1.0, 2.0)),
    WEGOVY("Wegovy", listOf(0.25, 0.5, 1.0, 1.7, 2.4)),
    MOUNJARO("Mounjaro", listOf(2.5, 5.0, 7.5, 10.0, 12.5, 15.0)),
    ZEPBOUND("Zepbound", MOUNJARO.doses),
    COMPOUNDED_SEMAGLUTIDE("Compounded semaglutide", WEGOVY.doses),
    COMPOUNDED_TIRZEPATIDE("Compounded tirzepatide", MOUNJARO.doses),
    OTHER("Other", emptyList()),
    WEGOVY_PILL("Wegovy pill", listOf(1.5, 4.0, 9.0, 25.0), DoseForm.PILL, 30),
    FOUNDAYO("Foundayo", listOf(0.8, 2.5, 5.5, 9.0, 14.5, 17.2), DoseForm.PILL),
    RYBELSUS("Rybelsus", listOf(1.5, 3.0, 4.0, 7.0, 9.0, 14.0), DoseForm.PILL, 30),
    OTHER_PILL("Other pill", emptyList(), DoseForm.PILL);
    val custom: Boolean get() = this == OTHER || this == OTHER_PILL
}

enum class MatchStatus(val raw: String, val label: String) {
    ON_SCHEDULE("onSchedule", "On schedule"), EARLY("early", "A little early"),
    LATE("late", "A little late"), EXTRA("extra", "Manual"), UNKNOWN("unknown", "Not mapped")
}

data class DoseStep(val start: Instant, val doseMg: Double, val note: String = "")
data class Plan(
    val medication: Medication = Medication.OZEMPIC,
    val customName: String = "",
    val doseMg: Double = 0.25,
    val start: LocalDate = LocalDate.now(),
    val time: LocalTime = LocalTime.of(9, 0),
    val intervalDays: Int = 7,
    val waitMinutes: Int = 0,
    val reminderEnabled: Boolean = true,
    val reminderLeadMinutes: Int = 0,
    val supplyCount: Int = 0,
    val supplyUpdatedAt: Instant? = null,
    val steps: List<DoseStep> = emptyList(),
) {
    val cadence: Int get() = intervalDays.coerceAtLeast(1)
    val form: DoseForm get() = medication.form
    val name: String get() = customName.takeIf { medication.custom && it.isNotBlank() } ?: medication.label
    val wait: Int get() = if (form == DoseForm.PILL) waitMinutes.coerceAtLeast(0) else 0
    fun anchor(zone: ZoneId): ZonedDateTime = start.atTime(time).atZone(zone)
}

data class DoseEvent(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Instant,
    val medication: String,
    val doseMg: Double,
    val scheduledDate: Instant? = null,
    val status: MatchStatus = MatchStatus.UNKNOWN,
    val minutesFromSchedule: Int? = null,
    val site: String = "",
    val notes: String = "",
    // iOS CSV context columns, preserved during import/export without HealthKit access.
    val context: List<String> = List(17) { "" },
)

data class DoseMatch(val scheduled: Instant?, val dose: Double, val status: MatchStatus, val minutes: Int?)

object ScheduleEngine {
    fun dose(at: Instant, plan: Plan): Double = plan.steps.sortedBy { it.start }.lastOrNull { it.start <= at }?.doseMg ?: plan.doseMg
    fun onOrBefore(at: Instant, plan: Plan, zone: ZoneId): ZonedDateTime? {
        val first = plan.anchor(zone)
        if (first.toInstant() > at) return null
        val days = ChronoUnit.DAYS.between(first.toLocalDate(), at.atZone(zone).toLocalDate())
        var slot = first.plusDays(days / plan.cadence * plan.cadence)
        while (slot.toInstant() > at) slot = slot.minusDays(plan.cadence.toLong())
        while (slot.plusDays(plan.cadence.toLong()).toInstant() <= at) slot = slot.plusDays(plan.cadence.toLong())
        return slot
    }
    fun nextExpected(at: Instant, plan: Plan, zone: ZoneId): ZonedDateTime =
        onOrBefore(at, plan, zone)?.plusDays(plan.cadence.toLong()) ?: plan.anchor(zone)
    fun claimed(slot: Instant, events: List<DoseEvent>): Boolean = events.any {
        it.scheduledDate?.let { date -> abs(date.epochSecond - slot.epochSecond) < 60 } == true
    }
    fun match(at: Instant, plan: Plan?, events: List<DoseEvent> = emptyList(), zone: ZoneId = ZoneId.systemDefault()): DoseMatch {
        if (plan == null) return DoseMatch(null, 0.0, MatchStatus.UNKNOWN, null)
        val manual = DoseMatch(null, dose(at, plan), MatchStatus.EXTRA, null)
        val slot = if (plan.cadence == 1) {
            val date = at.atZone(zone).toLocalDate()
            if (date < plan.start) return manual
            date.atTime(plan.time).atZone(zone).toInstant()
        } else {
            val anchor = onOrBefore(at, plan, zone)
            val nearby = if (anchor == null) listOf(plan.anchor(zone)) else (-2..2).map { anchor.plusDays(it.toLong() * plan.cadence) }
            val closest = nearby.minBy { abs(it.toEpochSecond() - at.epochSecond) }.toInstant()
            if (abs(closest.epochSecond - at.epochSecond + (closest.nano - at.nano) / 1_000_000_000.0) > 4 * 86400) return manual
            closest
        }
        if (claimed(slot, events)) return manual
        val delta = at.epochSecond - slot.epochSecond + (at.nano - slot.nano) / 1_000_000_000.0
        val window = if (plan.cadence == 1) 3 * 3600 else 18 * 3600
        val status = if (abs(delta) <= window) MatchStatus.ON_SCHEDULE else if (delta < 0) MatchStatus.EARLY else MatchStatus.LATE
        return DoseMatch(slot, dose(slot, plan), status, if (delta < 0) -((-delta / 60.0).roundToInt()) else (delta / 60.0).roundToInt())
    }
    fun nextUnclaimed(now: Instant, plan: Plan, events: List<DoseEvent>, zone: ZoneId): Instant {
        val overdue = onOrBefore(now, plan, zone)?.toInstant()
        if (overdue != null && !claimed(overdue, events) && events.none { it.timestamp >= overdue }) return overdue
        var slot = nextExpected(now, plan, zone)
        while (claimed(slot.toInstant(), events)) slot = slot.plusDays(plan.cadence.toLong())
        return slot.toInstant()
    }
    fun nextDue(now: Instant, plan: Plan, events: List<DoseEvent>, zone: ZoneId = ZoneId.systemDefault()): Instant {
        if (plan.cadence != 1) return nextUnclaimed(now, plan, events, zone)
        val today = now.atZone(zone).toLocalDate()
        val taken = events.any { it.timestamp <= now && it.timestamp.atZone(zone).toLocalDate() == today }
        val slot = today.plusDays(if (taken) 1 else 0).atTime(plan.time).atZone(zone).toInstant()
        return maxOf(slot, plan.anchor(zone).toInstant())
    }
    fun reminderSlots(now: Instant, plan: Plan, events: List<DoseEvent>, zone: ZoneId = ZoneId.systemDefault()): List<Instant> {
        val slots = mutableListOf<Instant>()
        var cursor = nextExpected(now, plan, zone)
        while (slots.size < if (plan.cadence == 1) 14 else 2) {
            if (!claimed(cursor.toInstant(), events)) slots += cursor.toInstant()
            cursor = cursor.plusDays(plan.cadence.toLong())
        }
        return slots
    }
}

object DailyAdherence {
    fun streak(dates: List<Instant>, now: Instant, zone: ZoneId = ZoneId.systemDefault()): Int {
        val days = dates.map { it.atZone(zone).toLocalDate() }.toSet()
        var day = now.atZone(zone).toLocalDate()
        if (day !in days) day = day.minusDays(1)
        var count = 0
        while (day in days) { count++; day = day.minusDays(1) }
        return count
    }
    fun longest(dates: List<Instant>, zone: ZoneId = ZoneId.systemDefault()): Int {
        var best = 0; var run = 0; var previous: LocalDate? = null
        dates.map { it.atZone(zone).toLocalDate() }.distinct().sorted().forEach { day ->
            run = if (previous?.plusDays(1) == day) run + 1 else 1
            best = maxOf(best, run); previous = day
        }
        return best
    }
    fun summary(dates: List<Instant>, start: LocalDate, end: LocalDate, zone: ZoneId): Pair<Int, Int> {
        if (end < start) return 0 to 0
        val days = dates.map { it.atZone(zone).toLocalDate() }.toSet()
        val planned = ChronoUnit.DAYS.between(start, end).toInt() + 1
        return days.count { it in start..end } to planned
    }
}

object SupplyMath {
    fun remaining(plan: Plan, events: List<DoseEvent>): Int? = plan.supplyUpdatedAt?.let { since ->
        (plan.supplyCount - events.count { it.timestamp >= since }).coerceAtLeast(0)
    }
    fun daysLeft(remaining: Int, plan: Plan): Int = remaining * plan.cadence
    fun isLow(remaining: Int, plan: Plan): Boolean = daysLeft(remaining, plan) <= 7
    fun reminder(remaining: Int, plan: Plan, now: Instant, zone: ZoneId): Instant? {
        val offset = daysLeft(remaining, plan) - 7
        if (offset <= 0) return null
        return now.atZone(zone).toLocalDate().plusDays(offset.toLong()).atTime(plan.time).atZone(zone).toInstant().takeIf { it > now }
    }
}

data class AlertPreferences(val enabled: Boolean = false, val quiet: Boolean = true, val start: Int = 22, val end: Int = 7, val patterns: Boolean = false, val sensitivity: Double = 0.0) {
    fun isQuiet(hour: Int): Boolean = quiet && start != end && if (start < end) hour >= start && hour < end else hour >= start || hour < end
}
object ProactiveAlerts {
    fun lateFire(slot: Instant, prefs: AlertPreferences, zone: ZoneId): Instant {
        var fire = slot.plusSeconds(4 * 3600)
        repeat(24) { if (prefs.isQuiet(fire.atZone(zone).hour)) fire = fire.plusSeconds(3600) }
        return fire
    }
    fun patterns(events: List<DoseEvent>, sensitivity: Double, zone: ZoneId): List<Pair<Int, Int>> {
        if (events.size < 6) return emptyList()
        return events.groupingBy { it.timestamp.atZone(zone).dayOfWeek.value }.eachCount().entries
            .filter { it.value.toDouble() / events.size >= 0.45 - 0.20 * sensitivity }
            .sortedByDescending { it.value }.map { it.key to it.value }
    }
}

object DoseRoutine {
    fun alreadyLogged(now: Instant, plan: Plan, events: List<DoseEvent>, zone: ZoneId = ZoneId.systemDefault()): Boolean = events.any {
        it.timestamp <= now && if (plan.cadence == 1) it.timestamp.atZone(zone).toLocalDate() == now.atZone(zone).toLocalDate() else now.epochSecond - it.timestamp.epochSecond < 12 * 3600
    }
    fun waitEnd(plan: Plan, events: List<DoseEvent>, now: Instant): Instant? {
        if (plan.wait <= 0) return null
        val last = events.filter { it.timestamp <= now && it.medication == plan.name }.maxByOrNull { it.timestamp } ?: return null
        return last.timestamp.plusSeconds(plan.wait * 60L).takeIf { it > now }
    }
}
