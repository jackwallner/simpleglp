package com.jackwallner.glp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.jackwallner.glp.MainActivity
import com.jackwallner.glp.data.PurchaseOutcome
import com.jackwallner.glp.data.StoreService
import com.revenuecat.purchases.PackageType
import kotlinx.coroutines.launch

@Composable fun PaywallScreen(store: StoreService, activity: MainActivity, dismiss: () -> Unit, isPill: Boolean = false) {
    val scope = rememberCoroutineScope(); var busy by remember { mutableStateOf(false) }; var result by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { store.refresh() }
    Dialog(onDismissRequest = { if (!busy) dismiss() }) {
        Surface(shape = MaterialTheme.shapes.large, modifier = Modifier.semantics { testTagsAsResourceId = true }) {
            Column(Modifier.verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("Simple GLP Pro", style = MaterialTheme.typography.headlineMedium)
                Text("Stay ahead of your routine")
                Text((if (isPill) "Lock Screen wait countdown\n" else "") + "Supply tracking & refill reminders\nProactive Alerts\nKeep logging, history, reminders, the in-app pill timer, and Patterns free.")
                if (store.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                store.packages.forEach { pkg ->
                    val lifetime = pkg.packageType == PackageType.LIFETIME
                    val label = when (pkg.packageType) { PackageType.MONTHLY -> "Monthly"; PackageType.ANNUAL -> "Yearly"; PackageType.LIFETIME -> "Lifetime"; else -> pkg.product.title }
                    val period = when (pkg.packageType) { PackageType.MONTHLY -> " / month"; PackageType.ANNUAL -> " / year"; else -> "" }
                    val freePhase = pkg.product.defaultOption?.freePhase
                    val trial = freePhase?.billingPeriod?.let { "${it.value} ${it.unit.name.lowercase()} free trial, then " }.orEmpty()
                    Text("$label · $trial${pkg.product.price.formatted}$period${if (lifetime) " · one-time purchase" else ""}")
                    Action("Continue with $label", !busy && store.resolved) {
                        busy = true; scope.launch {
                            runCatching { store.purchase(activity, pkg) }.onSuccess { outcome ->
                                when (outcome) { PurchaseOutcome.PURCHASED -> dismiss(); PurchaseOutcome.PENDING -> result = "Payment pending. Pro unlocks when Google Play completes your purchase."; PurchaseOutcome.CANCELLED -> Unit }
                            }.onFailure { result = it.message ?: "Couldn't complete the purchase." }; busy = false
                        }
                    }
                }
                store.error?.let { Text(it, style = MaterialTheme.typography.bodySmall) }; result?.let { Text(it) }
                if (store.packages.isEmpty()) TextButton({ scope.launch { store.refresh() } }, enabled = !store.busy) { Text("Retry") }
                Text("Subscriptions renew automatically unless canceled. Cancel in Google Play > Payments & subscriptions. Any trial converts to the displayed recurring price unless canceled before it ends.", style = MaterialTheme.typography.bodySmall)
                TextButton({ scope.launch { store.restore(); if (store.isPro) dismiss() } }, enabled = !busy && !store.busy) { Text("Restore purchases") }
                Row {
                    TextButton({ open(activity, "https://jackwallner.github.io/simpleglp/privacy-policy.html") }) { Text("Privacy") }
                    TextButton({ open(activity, "https://jackwallner.github.io/simpleglp/terms.html") }) { Text("Terms") }
                }
                TextButton(dismiss, enabled = !busy) { Text("Not now") }
            }
        }
    }
}
