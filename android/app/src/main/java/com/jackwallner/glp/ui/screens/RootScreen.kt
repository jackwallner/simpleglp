package com.jackwallner.glp.ui.screens

import android.Manifest
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import com.google.android.play.core.review.ReviewManagerFactory
import com.jackwallner.glp.AppGraph
import com.jackwallner.glp.MainActivity
import com.jackwallner.glp.data.Csv
import com.jackwallner.glp.data.PurchaseOutcome
import com.jackwallner.glp.data.TrialOfferPolicy
import com.jackwallner.glp.data.TrialSource
import com.jackwallner.glp.model.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun RootScreen(graph: AppGraph, activity: MainActivity, automation: Boolean) {
    val tracker = graph.tracker; val store = graph.store; val scope = rememberCoroutineScope()
    var tab by remember { mutableIntStateOf(0) }
    var route by remember { mutableStateOf<String?>(null) }
    var edit by remember { mutableStateOf<DoseEvent?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var undo by remember { mutableStateOf<String?>(null) }
    var duplicate by remember { mutableStateOf(false) }
    var deleteAll by remember { mutableStateOf(false) }
    var paywall by remember { mutableStateOf(false) }
    var now by remember { mutableStateOf(Instant.now()) }
    var pendingImport by remember { mutableStateOf<String?>(null) }
    val snackbar = remember { SnackbarHostState() }
    var trialSource by remember { mutableStateOf<TrialSource?>(null) }
    var trialPitchScheduled by remember { mutableStateOf(false) }
    var trialPurchasing by remember { mutableStateOf(false) }
    var trialError by remember { mutableStateOf<String?>(null) }
    var paywallAfterTrial by remember { mutableStateOf(false) }
    // True only while the system notification dialog is on screen; the rating ask never stacks on it.
    var permissionOpen by remember { mutableStateOf(false) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { permissionOpen = false; graph.notifications.sync(tracker, store.isPro, store.resolved) }
    fun sync(prompt: Boolean = false) {
        graph.notifications.sync(tracker, store.isPro, store.resolved)
        if (prompt && Build.VERSION.SDK_INT >= 33 && !graph.notifications.permitted()) { permissionOpen = true; permission.launch(Manifest.permission.POST_NOTIFICATIONS) }
    }
    fun paid(destination: String) { if (store.isPro) route = destination else paywall = true }
    fun resumed() = activity.lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED)
    fun nothingPresented() = route == null && !paywall && !duplicate && message == null && !deleteAll && pendingImport == null && trialSource == null && !permissionOpen && resumed()
    // Play's review card with no question in front of it. A blocked ask stays pending for the next moment.
    fun positiveMoment() {
        if (automation) return
        graph.reviews.recordPositiveMoment()
        scope.launch {
            delay(3500)
            val clear = tab in listOf(0, 3) && nothingPresented() && !trialPitchScheduled
            if (!graph.reviewShownThisSession && clear && graph.reviews.shouldAsk(tracker.plan != null, permissionOpen)) {
                graph.reviewShownThisSession = true
                graph.reviews.markShown()
                val manager = ReviewManagerFactory.create(activity)
                manager.requestReviewFlow().addOnSuccessListener { info -> manager.launchReviewFlow(activity, info) }
            }
        }
    }
    fun offerTrial(source: TrialSource, delayMs: Long) {
        if (automation || graph.promoShownThisSession) return
        trialPitchScheduled = true
        scope.launch {
            delay(delayMs)
            trialPitchScheduled = false
            if (TrialOfferPolicy.shouldPresent(source, tracker.plan != null, store.resolved, store.isPro, store.hadPro, store.trialPackage != null,
                    graph.promoShownThisSession, nothingPresented(), graph.trialOffers.seen, graph.trialOffers.seenPatterns)) {
                graph.promoShownThisSession = true
                graph.trialOffers.markSeen(source)
                trialError = null; trialSource = source
            }
        }
    }
    fun log() {
        runCatching {
            val first = tracker.events.isEmpty()
            val event = tracker.log(); now = Instant.now(); undo = event.id
            if (tracker.promptDetails) { edit = event; route = "details" }
            sync(true)
            if (first) offerTrial(TrialSource.FIRST_DOSE, 4000)
            positiveMoment()
        }.onFailure { message = "Your dose could not be saved. Please try again." }
    }
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri != null) runCatching {
            val stream = checkNotNull(activity.contentResolver.openOutputStream(uri))
            stream.bufferedWriter().use { it.write(Csv.export(tracker.events)) }
            message = "CSV exported."; positiveMoment()
        }.onFailure { message = "Couldn't export. Please try again." }
    }
    val import = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) runCatching {
            activity.contentResolver.openInputStream(uri)?.bufferedReader()?.use { reader ->
                val text = reader.readText(); require(text.length <= 10_000_000); Csv.parse(text); pendingImport = text
            } ?: error("Unreadable file")
        }.onFailure { message = "Couldn't read this CSV. Choose a Simple GLP export." }
    }
    LaunchedEffect(Unit) { while (true) { now = Instant.now(); delay(1000) } }
    LaunchedEffect(store.isPro, store.resolved) { sync() }
    // Existing users who never saw the pitch get it once Home has rendered; Patterns is the second touch.
    LaunchedEffect(tab, store.resolved, store.trialPackage != null) {
        if (tab == 0 && tracker.events.isNotEmpty() && !graph.trialOffers.seen) offerTrial(TrialSource.EXISTING_USER, 3000)
        if (tab == 2 && !graph.trialOffers.seenPatterns) offerTrial(TrialSource.PATTERNS, 450)
    }
    LaunchedEffect(undo) {
        if (undo != null) {
            val result = snackbar.showSnackbar("${tracker.plan?.form?.noun?.replaceFirstChar(Char::uppercase)} logged", "Undo", duration = SnackbarDuration.Long)
            if (result == SnackbarResult.ActionPerformed) { undo?.let(tracker::remove); sync() }
            undo = null
        }
    }
    BackHandler(route != null) { route = null; edit = null }
    Scaffold(modifier = Modifier.semantics { testTagsAsResourceId = true }, containerColor = MaterialTheme.colorScheme.background,
        topBar = { if (route != null) TopAppBar(title = {}, navigationIcon = { IconButton({ route = null; edit = null }) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back") } }) },
        snackbarHost = { SnackbarHost(snackbar) },
        bottomBar = {
            if (tracker.plan != null && route == null) NavigationBar {
                listOf("One Tap", "History", "Patterns", "Settings").forEachIndexed { index, label ->
                    val icon = listOf(Icons.Outlined.AddCircleOutline, Icons.Outlined.History, Icons.Outlined.BarChart, Icons.Outlined.Settings)[index]
                    NavigationBarItem(tab == index, { tab = index }, { Icon(icon, label) }, label = { Text(label) })
                }
            }
        }) { padding ->
        Box(Modifier.padding(padding)) {
            val plan = tracker.plan
            when {
                tracker.corruption != null -> Page("Data unavailable") { Text(tracker.corruption!!); Text("Use your saved CSV backup to restore after resetting this device."); RowAction("Reset local data") { deleteAll = true } }
                plan == null -> OnboardingScreen(store, activity) { value, askForDetails ->
                    tracker.savePlan(value)
                    tracker.updatePromptDetails(askForDetails)
                    route = null
                    sync(true)
                }
                route == "plan" -> PlanScreen(plan) { value ->
                    runCatching { tracker.savePlan(value); route = null; sync(true) }.onFailure { message = "Your plan could not be saved. Please try again." }
                }
                route == "details" || route == "earlier" -> LogScreen(plan, edit, { at, amount, site, notes, context ->
                    runCatching {
                        if (edit != null) tracker.edit(edit!!.copy(timestamp = at, doseMg = amount, site = site, notes = notes, context = context))
                        else {
                            tracker.log(at, site, notes, context, amount)
                        }
                        route = null; edit = null; sync(true)
                    }.onFailure { message = "Your dose could not be saved. Please try again." }
                }, if (edit == null) null else ({ edit?.id?.let(tracker::remove); edit = null; route = null; sync() }))
                route == "supply" && store.isPro -> SupplyScreen(plan, tracker.events) { tracker.savePlan(it); sync(true) }
                route == "alerts" && store.isPro -> AlertsScreen(plan, tracker.alerts) { tracker.updateAlerts(it); sync(true) }
                route == "schedule" -> ScheduleScreen(plan, now)
                tab == 0 -> HomeScreen(plan, tracker.events, now, store.isPro, onLog = {
                    val already = DoseRoutine.alreadyLogged(Instant.now(), plan, tracker.events)
                    if (already) duplicate = true else log()
                }, onEarlier = { edit = null; route = "earlier" }, onPlan = { route = "plan" }, onSupply = { paid("supply") }, onUpgrade = { paywall = true })
                tab == 1 -> HistoryScreen(plan, tracker.events, now, { edit = it; route = "details" }, { edit = null; route = "earlier" })
                tab == 2 -> PatternsScreen(plan, tracker.events, now, { paid("alerts") }, { paid("supply") })
                else -> Page("Settings") {
                    Panel("Plan") {
                        RowAction("Medication & schedule") { route = "plan" }; RowAction("Dose schedule") { route = "schedule" }
                        RowAction("Supply & refills${if (store.isPro) "" else " · Pro"}") { paid("supply") }
                        RowAction("Proactive Alerts${if (store.isPro) "" else " · Pro"}") { paid("alerts") }
                    }
                    Panel("Your preferences") {
                        Choice("Appearance", tracker.appearance, listOf("system", "light", "dark"), { it.replaceFirstChar(Char::uppercase) }, tracker::updateAppearance)
                        Toggle("Ask for details after logging", tracker.promptDetails, tracker::updatePromptDetails)
                        RowAction("Notification settings") { activity.startActivity(Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, activity.packageName)) }
                        Text("Health context: Apple Health is not available on Android. Imported context stays with your logs.", style = MaterialTheme.typography.bodySmall)
                    }
                    Panel("Simple GLP Pro") {
                        Text(if (store.isPro) "Pro is active" else if (plan.form == DoseForm.PILL) "Lock Screen wait countdown, supply tracking, refill reminders, and Proactive Alerts." else "Supply tracking, refill reminders, and Proactive Alerts.")
                        if (!store.isPro) RowAction("See Pro plans") { paywall = true }
                        RowAction("Restore purchases") { scope.launch { store.restore(); message = store.error; sync() } }
                        RowAction("Manage subscription") { open(activity, "https://play.google.com/store/account/subscriptions?package=com.jackwallner.glp") }
                    }
                    Panel("Your data") {
                        RowAction("Export CSV") { export.launch("SimpleGLP_Export_${LocalDate.now()}.csv") }
                        RowAction("Import CSV") { import.launch(arrayOf("text/*", "application/csv", "application/octet-stream")) }
                        RowAction("Delete all data") { deleteAll = true }
                    }
                    Panel("Support") {
                        RowAction("Send Feedback") { open(activity, "mailto:jackwallner@gmail.com?subject=Simple%20GLP%20feedback") }
                        RowAction("Rate Simple GLP") { graph.reviews.markOpenedListing(); open(activity, "https://play.google.com/store/apps/details?id=com.jackwallner.glp") }
                        listOf("Support" to "support.html", "Privacy Policy" to "privacy-policy.html", "Terms of Use" to "terms.html").forEach { (label, path) -> RowAction(label) { open(activity, "https://jackwallner.github.io/simpleglp/$path") } }
                        Text("Tracking only. Simple GLP isn't medical advice and doesn't diagnose or treat any condition.", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
    }
    if (duplicate) AlertDialog(onDismissRequest = { duplicate = false }, title = { Text("Already logged") }, text = { Text("You've already logged this ${tracker.plan?.form?.noun}. Check History before adding another entry.") }, confirmButton = { TextButton({ duplicate = false; tab = 1 }) { Text("View history") } }, dismissButton = { TextButton({ duplicate = false }) { Text("Cancel") } })
    trialSource?.let { source ->
        val pkg = store.trialPackage
        val trial = pkg?.product?.defaultOption?.freePhase?.billingPeriod
        val price = pkg?.product?.price?.formatted?.let { "$it per year" }
        fun close() { trialSource = null; trialPurchasing = false; trialError = null; if (paywallAfterTrial) { paywallAfterTrial = false; paywall = true } }
        TrialOfferSheet(TrialOfferContent(trial?.value, trial?.unit?.name, price, tracker.plan?.form == DoseForm.PILL), trialPurchasing, trialError, store.busy,
            onStart = {
                if (pkg == null) { paywallAfterTrial = true; close() }
                else { trialPurchasing = true; trialError = null; scope.launch {
                    try {
                        when (store.purchase(activity, pkg)) {
                            PurchaseOutcome.PURCHASED, PurchaseOutcome.PENDING -> { trialPurchasing = false; close(); sync() }
                            PurchaseOutcome.CANCELLED -> trialError = "Trial wasn't started. Tap again, or pick a different plan."
                        }
                    } catch (failure: kotlinx.coroutines.CancellationException) { throw failure }
                    catch (_: Exception) { trialError = "Couldn't start your trial. Please try again." }
                    finally { trialPurchasing = false }
                } }
            },
            onSeeAll = { paywallAfterTrial = true; close() },
            onRestore = { scope.launch { store.restore(); if (store.isPro) { close(); sync() } else trialError = store.error } },
            onLink = { open(activity, it) },
            onDismiss = { close() })
    }
    if (paywall) PaywallScreen(store, activity, { paywall = false }, isPill = tracker.plan?.form == DoseForm.PILL)
    if (message != null) AlertDialog(onDismissRequest = { message = null }, title = { Text("Simple GLP") }, text = { Text(message!!) }, confirmButton = { TextButton({ message = null }) { Text("OK") } })
    if (pendingImport != null) AlertDialog(onDismissRequest = { pendingImport = null }, title = { Text("Import CSV?") }, text = { Text("Imported doses are added to your history. Existing entries stay. Schedule status is recomputed against your current plan.") }, confirmButton = { TextButton({
        runCatching { tracker.importCsv(pendingImport!!) }.onSuccess { message = "$it doses imported."; sync() }.onFailure { message = "Couldn't import this CSV. Your existing history is unchanged." }; pendingImport = null
    }) { Text("Import") } }, dismissButton = { TextButton({ pendingImport = null }) { Text("Cancel") } })
    if (deleteAll) AlertDialog(onDismissRequest = { deleteAll = false }, title = { Text("Delete all data?") }, text = { Text("Your plan, history, and settings will be removed from this device. Export a CSV first if you want to keep your logs.") }, confirmButton = { TextButton({ tracker.clearAll(); graph.notifications.cancelAll(); deleteAll = false; route = null; tab = 0 }) { Text("Delete all data") } }, dismissButton = { TextButton({ deleteAll = false }) { Text("Cancel") } })
}
fun open(context: Context, url: String) { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } }
