package com.jackwallner.glp.ui.screens

import java.time.LocalDate
import java.time.LocalTime

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DateRange
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Medication
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.outlined.TouchApp
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import kotlinx.coroutines.launch

import com.jackwallner.glp.MainActivity
import com.jackwallner.glp.data.PurchaseOutcome
import com.jackwallner.glp.data.StoreService
import com.jackwallner.glp.model.DoseForm
import com.jackwallner.glp.model.Medication
import com.jackwallner.glp.model.Plan

private val OnboardingPlanSaver = listSaver<Plan, Any>(
    save = { listOf(it.medication.name, it.customName, it.start.toString(), it.time.toSecondOfDay(), it.reminderEnabled, it.reminderLeadMinutes) },
    restore = { Plan(medication = Medication.valueOf(it[0] as String), customName = it[1] as String,
        start = LocalDate.parse(it[2] as String), time = LocalTime.ofSecondOfDay((it[3] as Int).toLong()),
        reminderEnabled = it[4] as Boolean, reminderLeadMinutes = it[5] as Int) },
)

/** The same six first-run stages as iOS, with manual health context on Android. */
@Composable
fun OnboardingScreen(store: StoreService, activity: MainActivity, onComplete: (Plan, Boolean) -> Unit) {
    var step by rememberSaveable { mutableStateOf(0) }
    var draft by rememberSaveable(stateSaver = OnboardingPlanSaver) { mutableStateOf(Plan()) }
    var dose by rememberSaveable { mutableStateOf("0.25") }
    var cadence by rememberSaveable { mutableStateOf("7") }
    var wait by rememberSaveable { mutableStateOf("0") }
    var customDose by rememberSaveable { mutableStateOf(false) }
    var askForDetails by rememberSaveable { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var purchasing by remember { mutableStateOf(false) }
    var showPlans by remember { mutableStateOf(false) }
    var finished by remember { mutableStateOf(false) }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    val trialStep = step == 5
    val pill = draft.form == DoseForm.PILL
    val annual = store.packages.firstOrNull { it.packageType == PackageType.ANNUAL }
    val preferred = annual ?: store.packages.firstOrNull { it.packageType == PackageType.MONTHLY } ?: store.packages.firstOrNull()

    fun validateMedication(): Double {
        val amount = dose.toDoubleOrNull()
        require(amount != null && amount.isFinite() && amount > 0) { "Enter a dose greater than 0 mg." }
        require(!draft.medication.custom || draft.customName.isNotBlank()) { "Enter the medication name." }
        return amount
    }

    fun validatedPlan(): Plan {
        val amount = validateMedication()
        val days = if (pill) 1 else cadence.toIntOrNull()
        require(days != null && days in 1..365) { "Enter an interval from 1 to 365 days." }
        val minutes = if (pill) wait.toIntOrNull() else 0
        require(minutes != null && minutes in 0..240) { "Enter a wait from 0 to 240 minutes." }
        return draft.copy(customName = draft.customName.trim(), doseMg = amount, intervalDays = days,
            waitMinutes = minutes, start = if (pill) LocalDate.now() else draft.start)
    }

    fun finish() {
        if (finished) return
        runCatching { onComplete(validatedPlan(), askForDetails); finished = true }
            .onFailure { error = it.message ?: "Your medication plan could not be saved. Please try again." }
    }

    LaunchedEffect(Unit) { if (store.packages.isEmpty() && !store.busy) store.refresh() }
    LaunchedEffect(step) { scroll.scrollTo(0) }
    LaunchedEffect(step, store.resolved, store.isPro) {
        if (trialStep && store.resolved && store.isPro) finish()
    }
    BackHandler(step > 0 && !purchasing) { error = null; step -= 1 }

    Column(Modifier.fillMaxSize().imePadding().padding(horizontal = 24.dp, vertical = 12.dp)) {
        Text("Simple GLP", Modifier.fillMaxWidth(), textAlign = TextAlign.Center, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(16.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            repeat(6) { index ->
                Box(Modifier.weight(1f).height(6.dp).background(
                    if (index <= step) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.4f), RoundedCornerShape(3.dp)))
            }
        }
        Text("Step ${step + 1} of 6", Modifier.padding(top = 8.dp), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Column(Modifier.weight(1f).verticalScroll(scroll).padding(top = 20.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            when (step) {
                0 -> {
                    OnboardingHeader(0, "One big button.", "Weekly shot or daily pill: tap it when you take your dose. That's it.")
                    Text("On a pill, the same tap starts your wait-before-eating countdown. Reminders, history, and a streak are there if you want them.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                1 -> {
                    OnboardingHeader(1, "What are you taking?", "Pick how you take it, then your medication and current dose.")
                    Panel {
                        Choice("How do you take it?", draft.form, DoseForm.entries, { if (it == DoseForm.PILL) "Pill" else "Shot" }) { form ->
                            val medication = Medication.entries.first { it.form == form }
                            draft = draft.copy(medication = medication, time = LocalTime.of(form.hour, 0))
                            dose = mg(medication.doses.firstOrNull() ?: 0.25); customDose = medication.custom
                            cadence = form.interval.toString(); wait = medication.wait.toString()
                        }
                        Choice("Medication", draft.medication, Medication.entries.filter { it.form == draft.form }, { it.label }) { medication ->
                            draft = draft.copy(medication = medication); wait = medication.wait.toString()
                            if (medication.doses.isEmpty()) customDose = true
                            else if (dose.toDoubleOrNull() !in medication.doses) { dose = mg(medication.doses.first()); customDose = false }
                        }
                        if (draft.medication.custom) OutlinedTextField(draft.customName, { draft = draft.copy(customName = it) }, Modifier.fillMaxWidth(), label = { Text("Medication name") })
                        if (customDose || draft.medication.doses.isEmpty()) {
                            OutlinedTextField(dose, { dose = it }, Modifier.fillMaxWidth(), label = { Text("Current dose (mg)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
                            if (draft.medication.doses.isNotEmpty()) TextButton({ customDose = false; dose = mg(draft.medication.doses.first()) }) { Text("Use standard dose") }
                        } else {
                            Choice("Current dose", dose, draft.medication.doses.map(::mg), { "$it mg" }) { dose = it }
                            TextButton({ customDose = true }) { Text("Use custom dose") }
                        }
                        Text("Set this to match your prescriber's instructions. Simple GLP records your plan and never recommends a dose.", style = MaterialTheme.typography.bodySmall)
                    }
                }
                2 -> {
                    OnboardingHeader(2, if (pill) "Your daily routine" else "How often do you dose?",
                        if (pill) "When you usually take it, and how long you wait before eating or drinking." else "Set your first dose and we'll keep the rhythm from there.")
                    Panel {
                        if (!pill) DateRow("First dose", draft.start) { draft = draft.copy(start = it) }
                        TimeRow(if (pill) "Usual time" else "Planned time", draft.time) { draft = draft.copy(time = it) }
                        if (pill) {
                            OutlinedTextField(wait, { wait = it }, Modifier.fillMaxWidth(), label = { Text("Wait before eating (minutes)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
                            Text("Tapping ‘I took my pill’ starts your countdown and pings you when it's done. Match the wait to your prescriber's instructions, or set 0 for no countdown.", style = MaterialTheme.typography.bodySmall)
                        } else OutlinedTextField(cadence, { cadence = it }, Modifier.fillMaxWidth(), label = { Text("Repeat every (days)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
                    }
                }
                3 -> {
                    OnboardingHeader(3, "Reminders", if (pill) "A nudge each day, skipped once you've logged your pill." else "A gentle nudge so a busy week doesn't push your shot.")
                    Panel {
                        Toggle(if (pill) "Remind me daily" else "Remind me on shot day", draft.reminderEnabled) { draft = draft.copy(reminderEnabled = it) }
                        if (draft.reminderEnabled) {
                            Choice("Lead time", draft.reminderLeadMinutes, (0..180 step 15).toList(), { "$it min before" }) { draft = draft.copy(reminderLeadMinutes = it) }
                            Text("We'll ask permission to send notifications. If you decline, reminders won't fire. You can enable them later in Android Settings.", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
                4 -> {
                    OnboardingHeader(4, "Health context", "Keep useful context with your dose log.")
                    Panel {
                        Toggle("Ask for details after logging", askForDetails) { askForDetails = it }
                        Text("Add notes, symptoms, and a site when you log a dose. You can skip details and change this in Settings.")
                        Text("Health context included in a CSV import stays with your history. Automatic health capture isn't included in this Android version.", style = MaterialTheme.typography.bodySmall)
                        Text("This adds context to your log. It isn't medical advice.", style = MaterialTheme.typography.bodySmall)
                    }
                }
                else -> {
                    val ready = store.resolved && !store.isPro
                    OnboardingHeader(5, if (!ready) "Your plan is ready" else if (pill) "Make the daily routine effortless" else "Get more from every shot",
                        if (ready) "Simple GLP Pro takes care of the parts that are easy to forget." else "You can start tracking while we check your membership.")
                    if (ready) Panel {
                        if (pill) Text("See your running wait countdown on the Lock Screen")
                        Text("Track your supply and get refill reminders")
                        Text("Stay ahead of your routine with Proactive Alerts")
                        Text("Your dose history stays private, on your device")
                    }
                    Text("Tracking only. Simple GLP isn't medical advice and doesn't diagnose or treat any condition.", style = MaterialTheme.typography.bodySmall)
                }
            }
            if (!trialStep) error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
        if (trialStep) {
            TextButton(::finish, Modifier.fillMaxWidth().testTag("onboarding-free"), enabled = !purchasing) { Text("Get Started") }
            if (store.resolved) preferred?.let { Text(onboardingDisclosure(it), Modifier.fillMaxWidth(), style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center) }
            error?.let { Text(it, Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.error, textAlign = TextAlign.Center) }
        }
        Spacer(Modifier.height(12.dp))
        Button(onClick = {
            error = null
            if (!trialStep) {
                runCatching {
                    if (step == 1) validateMedication()
                    if (step == 2) validatedPlan()
                    step += 1
                }.onFailure { error = it.message }
            } else if (!store.resolved || store.isPro) finish()
            else if (preferred == null) showPlans = true
            else {
                purchasing = true
                scope.launch {
                    try {
                        when (store.purchase(activity, preferred)) {
                            PurchaseOutcome.PURCHASED, PurchaseOutcome.PENDING -> finish()
                            PurchaseOutcome.CANCELLED -> error = "Purchase wasn't completed. Tap again, or choose Get Started."
                        }
                    } catch (failure: kotlinx.coroutines.CancellationException) { throw failure }
                    catch (_: Exception) { error = "Couldn't complete the purchase. Please try again, or choose Get Started." }
                    finally { purchasing = false }
                }
            }
        }, modifier = Modifier.fillMaxWidth().height(56.dp).testTag("onboarding-primary"), enabled = !purchasing) {
            if (purchasing) CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
            else Text(if (!trialStep || !store.resolved || store.isPro) "Continue" else onboardingCTA(preferred))
        }
        Box(Modifier.fillMaxWidth().height(48.dp).testTag("onboarding-footer"), contentAlignment = Alignment.Center) {
            if (trialStep) Row(horizontalArrangement = Arrangement.Center) {
                TextButton({ open(activity, "https://jackwallner.github.io/simpleglp/terms.html") }, enabled = !purchasing) { Text("Terms") }
                TextButton({ open(activity, "https://jackwallner.github.io/simpleglp/privacy-policy.html") }, enabled = !purchasing) { Text("Privacy") }
                TextButton({ scope.launch { store.restore(); if (store.isPro) finish() else error = store.error } }, enabled = !purchasing && !store.busy) { Text("Restore") }
            } else if (step > 0) TextButton({ step -= 1; error = null }, enabled = !purchasing) { Text("Back") }
        }
    }
    if (showPlans) PaywallScreen(store, activity, dismiss = { showPlans = false; finish() }, isPill = pill)
}

@Composable
private fun OnboardingHeader(step: Int, title: String, subtitle: String) {
    val icon = when (step) {
        0 -> Icons.Outlined.TouchApp
        1 -> Icons.Outlined.Medication
        2 -> Icons.Outlined.DateRange
        3 -> Icons.Outlined.Notifications
        4 -> Icons.Outlined.FavoriteBorder
        else -> Icons.Outlined.StarOutline
    }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Box(Modifier.size(76.dp).background(MaterialTheme.colorScheme.primaryContainer, CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(36.dp), tint = MaterialTheme.colorScheme.primary)
        }
        Text(title, Modifier.testTag("onboarding-step-$step"), style = MaterialTheme.typography.headlineLarge)
        Text(subtitle, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun onboardingCTA(pkg: Package?): String = when {
    pkg == null -> "See Pro plans"
    pkg.packageType == PackageType.LIFETIME -> "Unlock Pro forever"
    pkg.product.defaultOption?.freePhase != null -> "Start free trial"
    pkg.packageType == PackageType.ANNUAL -> "Subscribe yearly"
    pkg.packageType == PackageType.MONTHLY -> "Subscribe monthly"
    else -> "Subscribe"
}

private fun onboardingDisclosure(pkg: Package): String {
    val price = pkg.product.price.formatted
    if (pkg.packageType == PackageType.LIFETIME) return "$price one-time. No subscription."
    val period = if (pkg.packageType == PackageType.ANNUAL) "year" else "month"
    val trial = pkg.product.defaultOption?.freePhase?.billingPeriod
    val prefix = if (trial == null) "" else "${trial.value} ${trial.unit.name.lowercase()}${if (trial.value == 1) "" else "s"} free, then "
    return "$prefix$price per $period. Renews automatically unless canceled in Google Play."
}
