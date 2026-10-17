package com.jackwallner.glp

import com.jackwallner.glp.data.Codec
import com.jackwallner.glp.data.Csv
import com.jackwallner.glp.model.*
import org.json.JSONArray
import org.junit.Assert.*
import org.junit.Test
import java.time.*

class ParityTests {
    private val zone = ZoneId.of("America/Los_Angeles")
    private fun date(day: Int, hour: Int = 7, minute: Int = 0, month: Int = 3): Instant = LocalDateTime.of(2026, month, day, hour, minute).atZone(zone).toInstant()
    private fun plan(start: Int = 1, hour: Int = 7, cadence: Int = 1) = Plan(Medication.WEGOVY_PILL, doseMg = 1.5, start = LocalDate.of(2026, 3, start), time = LocalTime.of(hour, 0), intervalDays = cadence, waitMinutes = 30)
    private fun event(at: Instant, p: Plan = plan(), existing: List<DoseEvent> = emptyList()): DoseEvent {
        val m = ScheduleEngine.match(at, p, existing, zone)
        return DoseEvent(timestamp = at, medication = p.name, doseMg = m.dose, scheduledDate = m.scheduled, status = m.status, minutesFromSchedule = m.minutes)
    }
    @Test fun catalogMatchesCompiledIosSource() {
        val text = javaClass.getResourceAsStream("/ios-medications.json")!!.bufferedReader().readText()
        val rows = JSONArray(text)
        assertEquals(11, rows.length()); assertEquals(rows.length(), Medication.entries.size)
        Medication.entries.forEachIndexed { index, m ->
            val row = rows.getJSONObject(index)
            assertEquals(row.getString("name"), m.label)
            assertEquals(row.getString("form"), if (m.form == DoseForm.PILL) "pill" else "injection")
            assertEquals(row.getBoolean("custom"), m.custom); assertEquals(row.getInt("wait"), m.wait)
            val steps = row.getJSONArray("doses"); assertEquals(steps.length(), m.doses.size)
            m.doses.forEachIndexed { j, dose -> assertEquals(steps.getDouble(j), dose, 0.0) }
        }
    }
    @Test fun shotHasNoWait() { assertEquals(0, Plan(waitMinutes = 30).wait); assertEquals(30, plan().wait) }
    @Test fun dailyNearTimeOnSchedule() { val m = ScheduleEngine.match(date(5, 8, 30), plan(), zone = zone); assertEquals(MatchStatus.ON_SCHEDULE, m.status); assertEquals(date(5), m.scheduled) }
    @Test fun lateNightPillBelongsToOwnDay() { val m = ScheduleEngine.match(date(5, 23), plan(), zone = zone); assertEquals(MatchStatus.LATE, m.status); assertEquals(date(5), m.scheduled) }
    @Test fun duplicateDailyIsManual() { val m = ScheduleEngine.match(date(5, 12), plan(), listOf(event(date(5))), zone); assertEquals(MatchStatus.EXTRA, m.status); assertNull(m.scheduled) }
    @Test fun beforeDailyStartIsManual() { assertEquals(MatchStatus.EXTRA, ScheduleEngine.match(date(2), plan(start = 3), zone = zone).status) }
    @Test fun threeHourDailyBoundaryInclusive() { assertEquals(MatchStatus.ON_SCHEDULE, ScheduleEngine.match(date(5, 10), plan(), zone = zone).status); assertEquals(MatchStatus.LATE, ScheduleEngine.match(date(5, 10, 1), plan(), zone = zone).status) }
    @Test fun weeklyEarlyClaimsFutureOccurrence() {
        val p = plan(cadence = 7); val e = event(date(7), p)
        assertEquals(date(8), e.scheduledDate); assertEquals(MatchStatus.EARLY, e.status)
        assertEquals(date(15), ScheduleEngine.nextDue(date(8), p, listOf(e), zone))
    }
    @Test fun weeklyMissedDoseRemainsDue() { assertEquals(date(8), ScheduleEngine.nextDue(date(10), plan(cadence = 7), emptyList(), zone)) }
    @Test fun dailyTodayDueUntilTaken() { val p = plan(); assertEquals(date(5), ScheduleEngine.nextDue(date(5, 6), p, emptyList(), zone)); assertEquals(date(6), ScheduleEngine.nextDue(date(5, 8), p, listOf(event(date(5))), zone)) }
    @Test fun futureEventDoesNotClaimTodayTaken() { assertEquals(date(5), ScheduleEngine.nextDue(date(5, 6), plan(), listOf(event(date(5))), zone)) }
    @Test fun futurePlanIsNotDueToday() { assertEquals(date(8), ScheduleEngine.nextDue(date(5), plan(start = 8), emptyList(), zone)) }
    @Test fun streakAllowsTodayUnlogged() { val dates = listOf(date(3), date(4), date(5)); assertEquals(3, DailyAdherence.streak(dates, date(6, 6), zone)); assertEquals(4, DailyAdherence.streak(dates + date(6), date(6, 8), zone)) }
    @Test fun streakBreaksWithGap() { val dates = listOf(date(1), date(2), date(4), date(5)); assertEquals(2, DailyAdherence.streak(dates, date(5, 9), zone)); assertEquals(0, DailyAdherence.streak(dates, date(7, 9), zone)) }
    @Test fun longestDeduplicatesDays() { assertEquals(3, DailyAdherence.longest(listOf(date(1), date(1, 9), date(2), date(3), date(5)), zone)) }
    @Test fun monthSummaryStartsAtPlan() { assertEquals(2 to 3, DailyAdherence.summary(listOf(date(4), date(5)), LocalDate.of(2026, 3, 3), LocalDate.of(2026, 3, 5), zone)) }
    @Test fun supplyCountsOnlyAfterRefill() { val p = plan().copy(supplyCount = 30, supplyUpdatedAt = date(10, 12)); val events = listOf(9, 10, 11, 12).map { event(date(it)) }; assertEquals(28, SupplyMath.remaining(p, events)); assertNull(SupplyMath.remaining(p.copy(supplyUpdatedAt = null), events)) }
    @Test fun undoRestoresSupply() { val p = plan().copy(supplyCount = 1, supplyUpdatedAt = date(1)); val e = event(date(2)); assertEquals(0, SupplyMath.remaining(p, listOf(e))); assertEquals(1, SupplyMath.remaining(p, emptyList())) }
    @Test fun supplyNeverNegative() { assertEquals(0, SupplyMath.remaining(plan().copy(supplyCount = 0, supplyUpdatedAt = date(1)), listOf(event(date(2))))) }
    @Test fun refillReminderSevenDaysAhead() { val p = plan(); assertEquals(date(13), SupplyMath.reminder(10, p, date(10, 12), zone)); assertNull(SupplyMath.reminder(7, p, date(10, 12), zone)); assertTrue(SupplyMath.isLow(7, p)); assertFalse(SupplyMath.isLow(8, p)); assertEquals(21, SupplyMath.daysLeft(3, p.copy(intervalDays = 7))) }
    @Test fun reminderSkipsClaimedToday() { val p = plan(hour = 9); val e = event(date(5, 7), p); val slots = ScheduleEngine.reminderSlots(date(5, 7, 5), p, listOf(e), zone); assertEquals(date(6, 9), slots.first()); assertEquals(14, slots.size) }
    @Test fun reminderIncludesTodayIfFuture() { assertEquals(date(5, 9), ScheduleEngine.reminderSlots(date(5, 7), plan(hour = 9), emptyList(), zone).first()) }
    @Test fun lateNudgeSkipsMissedDayOnceMovedOn() { val p = plan(); val early = event(date(10, 6), p); assertEquals(date(11), ScheduleEngine.nextUnclaimed(date(10, 6, 5), p, listOf(early), zone)) }
    @Test fun lateNudgeTargetsUnloggedToday() { val p = plan(); assertEquals(date(10), ScheduleEngine.nextUnclaimed(date(10, 9), p, listOf(event(date(9))), zone)) }
    @Test fun quietHoursCrossMidnight() { val prefs = AlertPreferences(); assertTrue(prefs.isQuiet(23)); assertTrue(prefs.isQuiet(6)); assertFalse(prefs.isQuiet(7)); assertFalse(prefs.copy(start = 7, end = 7).isQuiet(7)); assertEquals(date(6), ProactiveAlerts.lateFire(date(5, 20), prefs, zone)) }
    @Test fun patternsRequireSixEvents() { val events = (1..5).map { event(date(it)) }; assertTrue(ProactiveAlerts.patterns(events, 0.0, zone).isEmpty()); val weekly = listOf(1, 8, 15, 22, 29).map { event(date(it)) } + event(date(2)); assertEquals(1, ProactiveAlerts.patterns(weekly, 0.0, zone).size) }
    @Test fun dailyScheduleKeepsWallTimeAcrossDst() { val p = plan(); val next = ScheduleEngine.nextExpected(date(7, 8), p, zone); assertEquals(date(8), next.toInstant()); assertEquals(7, next.hour); assertEquals(23 * 3600L, date(8).epochSecond - date(7).epochSecond) }
    @Test fun invalidCadenceClamped() { assertEquals(1, plan(cadence = 0).cadence) }
    @Test fun doseStepsUseLatestPastChange() { val p = plan().copy(steps = listOf(DoseStep(date(3), 4.0), DoseStep(date(8), 9.0))); assertEquals(1.5, ScheduleEngine.dose(date(2), p), 0.0); assertEquals(4.0, ScheduleEngine.dose(date(5), p), 0.0) }
    @Test fun csvRoundTripQuotesNewlinesAndContext() {
        val e = event(date(5)).copy(medication = "Custom, med", notes = "note \"one\"\nline two", context = (0..16).map(Int::toString))
        val exported = Csv.export(listOf(e)); assertEquals(23, Csv.parse(exported).first().size)
        val imported = Csv.import(exported, plan(), emptyList()).single()
        assertEquals(e.notes, imported.notes); assertEquals(e.medication, imported.medication); assertEquals(e.context, imported.context); assertEquals(e.timestamp, imported.timestamp)
    }
    @Test fun csvImportAddsAndRecomputesDuplicate() { val e = event(date(5)); val imported = Csv.import(Csv.export(listOf(e)), plan(), listOf(e)); assertEquals(1, imported.size); assertEquals(MatchStatus.EXTRA, imported.single().status) }
    @Test fun csvHandlesCrLfAndInvalidRows() { val text = "timestamp,medication,dose_mg\r\ninvalid,a,1\r\n${date(5)},a,1\r\n"; assertEquals(1, Csv.import(text, plan(), emptyList()).size); assertEquals(listOf(listOf("a", "b")), Csv.parse("a,b\r\n")) }
    @Test(expected = IllegalArgumentException::class) fun malformedCsvRejectedAtomically() { Csv.parse("timestamp,\"unfinished") }
    @Test fun planAndEventsPersistWithoutLoss() { val p = plan().copy(supplyUpdatedAt = date(1), steps = listOf(DoseStep(date(3), 4.0))); assertEquals(p, Codec.plan(Codec.plan(p))); val e = event(date(5)).copy(notes = "hello\nworld"); assertEquals(listOf(e), Codec.events(Codec.events(listOf(e)))) }
    @Test fun waitRemovedWhenLoggedDoseUndoneOrDeleted() { val e = event(date(5)); assertEquals(date(5, 7, 30), DoseRoutine.waitEnd(plan(), listOf(e), date(5, 7, 10))); assertNull(DoseRoutine.waitEnd(plan(), emptyList(), date(5, 7, 10))) }
    @Test fun backdatedExpiredDoseDoesNotRestartWait() { assertNull(DoseRoutine.waitEnd(plan(), listOf(event(date(4))), date(5))) }
    @Test fun waitFollowsEditedPlanAndDoseTimestamp() { val e = event(date(5)); assertEquals(date(5, 8), DoseRoutine.waitEnd(plan().copy(waitMinutes = 60), listOf(e), date(5, 7, 10))); assertNull(DoseRoutine.waitEnd(Plan(waitMinutes = 60), listOf(e), date(5, 7, 10))); assertNull(DoseRoutine.waitEnd(plan().copy(waitMinutes = 0), listOf(e), date(5, 7, 10))) }
    @Test fun handsFreeDailyDuplicateUsesDayAndWeeklyUsesTwelveHours() { val e = event(date(5)); assertTrue(DoseRoutine.alreadyLogged(date(5, 23), plan(), listOf(e), zone)); assertFalse(DoseRoutine.alreadyLogged(date(6), plan(), listOf(e), zone)); assertTrue(DoseRoutine.alreadyLogged(date(5, 18), plan(cadence = 7), listOf(e), zone)); assertFalse(DoseRoutine.alreadyLogged(date(5, 19), plan(cadence = 7), listOf(e), zone)) }
    @Test fun importPreservesExistingIdsAndCreatesNewOnes() { val e = event(date(5)); val existing = listOf(e); val imported = Csv.import(Csv.export(existing), plan(), existing); assertEquals(e.id, existing.single().id); assertNotEquals(e.id, imported.single().id) }

    @Test fun negativeMinuteTieRoundsAwayFromZeroLikeSwift() { assertEquals(-1, ScheduleEngine.match(date(5).minusSeconds(30), plan(), zone = zone).minutes) }

    @Test fun changingMedicationCannotStartPhantomPillWait() { val p = plan(); val different = event(date(5)).copy(medication = "Rybelsus"); assertNull(DoseRoutine.waitEnd(p, listOf(different), date(5, 7, 10))); assertEquals(date(5, 7, 30), DoseRoutine.waitEnd(p, listOf(event(date(5))), date(5, 7, 10))) }

    @Test fun subsecondDailyWindowAndMinuteBoundariesMatchSwift() { assertEquals(MatchStatus.LATE, ScheduleEngine.match(date(5, 10).plusNanos(1), plan(), zone = zone).status); assertEquals(0, ScheduleEngine.match(date(5).minusSeconds(30).plusNanos(1), plan(), zone = zone).minutes) }

}
