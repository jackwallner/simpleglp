package com.jackwallner.glp.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.jackwallner.glp.model.*
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable fun HomeScreen(plan: Plan, events: List<DoseEvent>, now: Instant, pro: Boolean, onLog: () -> Unit, onEarlier: () -> Unit, onPlan: () -> Unit, onSupply: () -> Unit, onUpgrade: () -> Unit) {
    val zone = ZoneId.systemDefault(); val last = events.filter { it.timestamp <= now }.maxByOrNull { it.timestamp }
    val today = now.atZone(zone).toLocalDate()
    val takenToday = events.any { it.timestamp <= now && it.timestamp.atZone(zone).toLocalDate() == today }
    val ends = DoseRoutine.waitEnd(plan, events, now)
    Page("One Tap") {
        Text("${plan.name} · ${mg(ScheduleEngine.dose(now, plan))} mg", style = MaterialTheme.typography.titleLarge)
        Panel {
            Text(if (plan.form == DoseForm.PILL && takenToday) "Today's pill is logged" else "One tap. Logged.", style = MaterialTheme.typography.headlineMedium)
            Text("Log the ${plan.form.noun} you've taken. Your plan stays here.")
            Action("I took my ${plan.form.noun}", onClick = onLog)
            TextButton(onEarlier, Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text("Log earlier") }
        }
        if (ends != null) Panel("Your wait-before-eating countdown") {
            val seconds = (ends.epochSecond - now.epochSecond).coerceAtLeast(0)
            Text("${seconds / 60}:${(seconds % 60).toString().padStart(2, '0')}", style = MaterialTheme.typography.displayMedium, modifier = Modifier.testTag("wait_timer"))
            Text("${plan.wait}-minute wait · ends ${display(ends)}")
            Text("Your own timer, based on your plan. Follow your medication's instructions.", style = MaterialTheme.typography.bodySmall)
        }
        if (ends != null && !pro) Panel("Keep your wait on the Lock Screen") {
            Text("With Pro and notifications enabled, your countdown keeps running on the Lock Screen.")
            RowAction("See Simple GLP Pro plans", onUpgrade)
        }
        Panel("Next planned ${plan.form.noun}") {
            Text(display(ScheduleEngine.nextDue(now, plan, events)), style = MaterialTheme.typography.titleLarge)
            Text(if (plan.cadence == 7) "Weekly · ${plan.time.format(DateTimeFormatter.ofPattern("h:mm a"))}" else "Every ${plan.cadence} ${if (plan.cadence == 1) "day" else "days"} · ${plan.time.format(DateTimeFormatter.ofPattern("h:mm a"))}")
            RowAction("Edit medication & schedule", onPlan)
        }
        if (plan.cadence == 1) Panel("Your streak") {
            Text("${DailyAdherence.streak(events.map { it.timestamp }, now)} days", style = MaterialTheme.typography.headlineMedium)
            val taken = events.map { it.timestamp.atZone(zone).toLocalDate() }.toSet()
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                (6 downTo 0).forEach { offset -> val day = today.minusDays(offset.toLong())
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(day.dayOfWeek.name.take(1), style = MaterialTheme.typography.labelMedium)
                        Box(Modifier.size(32.dp).background(if (day in taken) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant, CircleShape), contentAlignment = Alignment.Center) { Text(if (day in taken) "✓" else day.dayOfMonth.toString()) }
                    }
                }
            }
        }
        if (last != null) Panel("Last ${plan.form.noun}") {
            Text(display(last.timestamp)); Text("${last.medication} · ${mg(last.doseMg)} mg")
            if (last.site.isNotBlank()) Text("Injection site: ${last.site}")
            Text(last.status.label)
        }
        if (pro && plan.supplyUpdatedAt != null) Panel("Supply & refills") {
            val remaining = SupplyMath.remaining(plan, events) ?: 0
            Text("$remaining ${if (plan.form == DoseForm.PILL) "pills" else "doses"} left · about ${SupplyMath.daysLeft(remaining, plan)} days")
            if (SupplyMath.isLow(remaining, plan)) Text("Time to line up a refill.")
            RowAction("Update supply", onSupply)
        }
        Text("Tracking only. Simple GLP isn't medical advice and doesn't diagnose or treat any condition.", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable fun HistoryScreen(plan: Plan, events: List<DoseEvent>, now: Instant, edit: (DoseEvent) -> Unit, earlier: () -> Unit) {
    val zone = ZoneId.systemDefault(); var month by remember { mutableStateOf(YearMonth.now()) }
    Page("History") {
        RowAction("Log earlier", earlier)
        if (plan.cadence == 1) Panel("Month at a glance") {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                TextButton({ month = month.minusMonths(1) }) { Text("Previous") }
                Text(month.format(DateTimeFormatter.ofPattern("MMM yyyy")), Modifier.padding(top = 12.dp))
                TextButton({ month = month.plusMonths(1) }, enabled = month < YearMonth.now()) { Text("Next") }
            }
            val dates = events.map { it.timestamp.atZone(zone).toLocalDate() }.toSet()
            val end = minOf(month.atEndOfMonth(), now.atZone(zone).toLocalDate())
            val summary = DailyAdherence.summary(events.map { it.timestamp }, maxOf(month.atDay(1), plan.start), end, zone)
            Text("${summary.first} of ${summary.second} planned days logged")
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("M", "T", "W", "T", "F", "S", "S").forEach { Text(it, Modifier.weight(1f), style = MaterialTheme.typography.labelMedium) }
            }
            val cells = List(month.atDay(1).dayOfWeek.value - 1) { 0 } + (1..month.lengthOfMonth()).toList()
            cells.chunked(7).forEach { week ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    week.forEach { day ->
                        if (day == 0) Spacer(Modifier.weight(1f))
                        else {
                            val date = month.atDay(day)
                            Box(Modifier.weight(1f).height(34.dp).background(if (date in dates) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant, CircleShape), contentAlignment = Alignment.Center) { Text("$day${if (date in dates) " ✓" else ""}", style = MaterialTheme.typography.labelSmall) }
                        }
                    }
                    repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
        if (events.isEmpty()) Panel { Text("No ${plan.form.noun}s logged yet. Your history will appear here.") }
        events.sortedByDescending { it.timestamp }.forEach { event ->
            Card(onClick = { edit(event) }, modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(display(event.timestamp), style = MaterialTheme.typography.titleMedium)
                    Text("${event.medication} · ${mg(event.doseMg)} mg"); Text(event.status.label)
                    if (event.site.isNotBlank()) Text(event.site)
                    if (event.notes.isNotBlank()) Text(event.notes)
                    Text("Details", color = MaterialTheme.colorScheme.primary)
                }
            }
        }
    }
}

@Composable fun PatternsScreen(plan: Plan, events: List<DoseEvent>, now: Instant, alerts: () -> Unit, supply: () -> Unit) {
    val zone = ZoneId.systemDefault()
    Page("Patterns") {
        if (events.size < 5) Panel { Text("Keep logging your ${plan.form.noun}s. Insights appear once you've logged 5. You have ${events.size} so far.") }
        else {
            if (plan.cadence == 1) Panel("Last 30 days") {
                val today = now.atZone(zone).toLocalDate()
                val summary = DailyAdherence.summary(events.map { it.timestamp }, maxOf(plan.start, today.minusDays(29)), today, zone)
                Text("${summary.first} of ${summary.second} days logged", style = MaterialTheme.typography.titleLarge)
                Text("Current streak: ${DailyAdherence.streak(events.map { it.timestamp }, now)} days")
                Text("Best streak: ${DailyAdherence.longest(events.map { it.timestamp })} days")
            } else Panel("Schedule adherence") {
                val onTime = events.count { it.status == MatchStatus.ON_SCHEDULE }
                Text("${onTime * 100 / events.size}% on schedule", style = MaterialTheme.typography.titleLarge)
                Text("$onTime of ${events.size} ${plan.form.noun}s logged within the expected window.")
            }
            Panel("Timing pattern") {
                if (plan.form == DoseForm.PILL) {
                    val minutes = events.map { it.timestamp.atZone(zone).hour * 60 + it.timestamp.atZone(zone).minute }.sorted()
                    val median = minutes[minutes.size / 2]
                    Text("Usually around ${java.time.LocalTime.of(median / 60, median % 60).format(DateTimeFormatter.ofPattern("h:mm a"))}")
                    Text("Median time of day across your logged pills.")
                } else {
                    val day = events.groupingBy { it.timestamp.atZone(zone).dayOfWeek }.eachCount().maxBy { it.value }.key
                    Text("Most shots on ${day.name.lowercase().replaceFirstChar(Char::uppercase)}")
                    Text("Weekday preference from your history.")
                }
            }
        }
        Panel("Proactive Alerts") { Text(if (plan.form == DoseForm.PILL) "Missed-dose nudges." else "Pattern detection and dose-day nudges."); RowAction("Proactive Alerts", alerts) }
        Panel("Supply & refills") { Text("Count down what's on hand and get a heads-up before you run out."); RowAction("Supply & refills", supply) }
    }
}

@Composable fun ScheduleScreen(plan: Plan, now: Instant) {
    val zone = ZoneId.systemDefault()
    Page("Dose schedule") {
        Text("Your saved plan. Follow your prescriber's instructions.")
        var cursor = plan.anchor(zone)
        if (cursor.toInstant() < now) cursor = ScheduleEngine.onOrBefore(now, plan, zone) ?: cursor
        repeat(12) {
            val at = cursor.toInstant()
            Panel { Text(display(at)); Text("${plan.name} · ${mg(ScheduleEngine.dose(at, plan))} mg") }
            cursor = cursor.plusDays(plan.cadence.toLong())
        }
    }
}

@Composable fun SupplyScreen(plan: Plan, events: List<DoseEvent>, save: (Plan) -> Unit) {
    val remaining = SupplyMath.remaining(plan, events)
    var count by remember { mutableStateOf((remaining ?: if (plan.form == DoseForm.PILL) 30 else 4).toString()) }
    var saved by remember { mutableStateOf(false) }
    Page("Supply & refills") {
        if (remaining != null) Panel("Right now") {
            Text("$remaining ${if (plan.form == DoseForm.PILL) "pills" else "doses"} left · about ${SupplyMath.daysLeft(remaining, plan)} days")
            if (SupplyMath.isLow(remaining, plan)) Text("Time to line up a refill.")
        }
        Panel("Refill") {
            OutlinedTextField(count, { count = it; saved = false }, Modifier.fillMaxWidth(), label = { Text(if (plan.form == DoseForm.PILL) "Pills on hand" else "Doses on hand") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
            Action(if (remaining == null) "Start tracking" else "I refilled: set to $count", count.toIntOrNull() in 0..400) { save(plan.copy(supplyCount = count.toInt(), supplyUpdatedAt = Instant.now())); saved = true }
            if (saved) Text("Supply saved.")
            Text("Every ${plan.form.noun} you log counts down from this number. You'll get a heads-up about 7 days before you run out.")
            if (remaining != null) RowAction("Stop tracking supply") { save(plan.copy(supplyUpdatedAt = null)) }
        }
    }
}

@Composable fun AlertsScreen(plan: Plan, prefs: AlertPreferences, save: (AlertPreferences) -> Unit) {
    Page("Proactive Alerts") {
        Panel {
            Toggle("Proactive Alerts", prefs.enabled) { save(prefs.copy(enabled = it)) }
            Text("If a planned ${plan.form.noun} isn't logged after 4 hours, get a check-in. These alerts are based on your log, not medical advice.")
            Toggle("Quiet hours", prefs.quiet) { save(prefs.copy(quiet = it)) }
            if (prefs.quiet) {
                Choice("Start", prefs.start, (0..23).toList(), { "%02d:00".format(it) }) { save(prefs.copy(start = it)) }
                Choice("End", prefs.end, (0..23).toList(), { "%02d:00".format(it) }) { save(prefs.copy(end = it)) }
            }
            if (plan.form == DoseForm.INJECTION) {
                Toggle("Pattern alerts", prefs.patterns) { save(prefs.copy(patterns = it)) }
                Text("Find recurring dose-day patterns after at least 6 logs.")
                Slider(prefs.sensitivity.toFloat(), { save(prefs.copy(sensitivity = it.toDouble())) })
            }
        }
    }
}
