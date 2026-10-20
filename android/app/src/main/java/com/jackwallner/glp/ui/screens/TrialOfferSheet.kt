package com.jackwallner.glp.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ShowChart
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.glp.ui.theme.Brand

/** What the pitch needs from the store, already localized. Never a hardcoded amount. */
data class TrialOfferContent(val trialValue: Int?, val trialUnit: String?, val priceLabel: String?, val isPill: Boolean)

data class ProBullet(val icon: ImageVector, val title: String, val detail: String)

/** The Pro pitch, worded per dose form. Mirrors iOS `ProFeatures`. */
fun proBullets(isPill: Boolean): List<ProBullet> = if (isPill) listOf(
    ProBullet(Icons.Outlined.ScreenLockPortrait, "Lock Screen countdown", "Your wait ticks down in a notification on the Lock Screen"),
    ProBullet(Icons.Outlined.Inventory2, "Refill reminders", "A heads-up a week before your pills run out"),
    ProBullet(Icons.Outlined.NotificationsActive, "Missed-dose nudges", "A second reminder if the day slips by unlogged"),
) else listOf(
    ProBullet(Icons.Outlined.NotificationsActive, "Dose-day nudges", "A second reminder before a shot slips your schedule"),
    ProBullet(Icons.Outlined.Inventory2, "Refill reminders", "A heads-up a week before your pens run out"),
    ProBullet(Icons.AutoMirrored.Outlined.ShowChart, "Drift alerts", "Know when shots creep later week over week"),
)

object TrialCopy {
    private fun unit(content: TrialOfferContent) = content.trialUnit?.lowercase()?.takeIf { it in setOf("day", "week", "month") }
    fun period(content: TrialOfferContent): String? {
        val value = content.trialValue ?: return null; val unit = unit(content) ?: return null
        return "$value ${if (value == 1) unit else "${unit}s"}"
    }
    fun headline(content: TrialOfferContent) = period(content)?.let { "$it of Pro, free." } ?: "Try Simple GLP Pro free."
    fun subheadline(content: TrialOfferContent): String {
        val pitch = if (content.isPill) "A Lock Screen countdown and refill reminders" else "Dose-day nudges and refill reminders"
        return if (period(content) != null) "$pitch, on autopilot. Free until your trial ends." else "$pitch, free for eligible new subscribers."
    }
    fun button(content: TrialOfferContent): String {
        val value = content.trialValue; val unit = unit(content)
        return if (value == null || unit == null) "Start My Free Trial" else "Start My $value-${unit.replaceFirstChar(Char::uppercase)} Free Trial"
    }
    fun disclosure(content: TrialOfferContent): String {
        val renew = "Renews automatically; cancel anytime in Google Play > Payments & subscriptions before it ends."
        return period(content)?.let { "Free for $it. $renew" } ?: renew
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun TrialOfferSheet(content: TrialOfferContent, purchasing: Boolean, error: String?, restoring: Boolean,
                                onStart: () -> Unit, onSeeAll: () -> Unit, onRestore: () -> Unit, onLink: (String) -> Unit, onDismiss: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = { if (!purchasing) onDismiss() }, sheetState = state, containerColor = MaterialTheme.colorScheme.background,
        properties = ModalBottomSheetProperties(shouldDismissOnBackPress = !purchasing)) {
        TrialOfferBody(content, purchasing, error, restoring, onStart, onSeeAll, onRestore, onLink, onDismiss)
    }
}

@Composable fun TrialOfferBody(content: TrialOfferContent, purchasing: Boolean, error: String?, restoring: Boolean,
                               onStart: () -> Unit, onSeeAll: () -> Unit, onRestore: () -> Unit, onLink: (String) -> Unit, onDismiss: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Column(Modifier.semantics { testTagsAsResourceId = true }.testTag("trial-offer").fillMaxWidth().verticalScroll(rememberScrollState())
        .padding(horizontal = 24.dp).padding(bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Box(Modifier.size(72.dp).background(Brush.linearGradient(listOf(colors.primary, Brand)), CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.AutoAwesome, null, Modifier.size(32.dp), tint = Color.White)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(TrialCopy.headline(content), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Text(TrialCopy.subheadline(content), style = MaterialTheme.typography.bodyMedium, color = colors.onSurfaceVariant, textAlign = TextAlign.Center)
        }
        proBullets(content.isPill).take(2).forEach { bullet ->
            Row(Modifier.fillMaxWidth().background(colors.surface, MaterialTheme.shapes.large).padding(16.dp), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(40.dp).background(colors.primaryContainer, CircleShape), contentAlignment = Alignment.Center) { Icon(bullet.icon, null, tint = colors.primary) }
                Column { Text(bullet.title, style = MaterialTheme.typography.titleSmall); Text("${bullet.detail}.", style = MaterialTheme.typography.bodySmall, color = colors.onSurfaceVariant) }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Outlined.Shield, null, Modifier.size(16.dp), tint = colors.onSurfaceVariant)
            Text("All on-device. Your log never leaves your phone.", style = MaterialTheme.typography.bodySmall, color = colors.onSurfaceVariant)
        }
        trialDaysOf(content)?.let { days ->
            Column(Modifier.fillMaxWidth().background(colors.surface, MaterialTheme.shapes.large).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                TimelineStep(Icons.Outlined.LockOpen, "Today", "Full access unlocks. No payment now.")
                TimelineStep(Icons.Outlined.Event, "Day $days", "Trial ends. Keep Pro, or cancel in Google Play. Your call.")
            }
        }
        error?.let { Text(it, color = colors.error, style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center) }
        Button(onStart, Modifier.fillMaxWidth().height(56.dp).testTag("trial-start"), enabled = !purchasing && !restoring) {
            if (purchasing) CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp, color = colors.onPrimary) else Text(TrialCopy.button(content))
        }
        content.priceLabel?.let { Text("then $it", style = MaterialTheme.typography.titleSmall, modifier = Modifier.testTag("trial-price")) }
        Text(TrialCopy.disclosure(content), style = MaterialTheme.typography.bodySmall, color = colors.onSurfaceVariant, textAlign = TextAlign.Center)
        Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
            TextButton(onSeeAll, enabled = !purchasing) { Text("See all plans") }
            TextButton(onDismiss, Modifier.testTag("trial-dismiss"), enabled = !purchasing) { Text("Not now") }
        }
        Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
            TextButton(onRestore, enabled = !purchasing && !restoring) { Text(if (restoring) "Restoring…" else "Restore") }
            TextButton({ onLink("https://jackwallner.github.io/simpleglp/terms.html") }) { Text("Terms") }
            TextButton({ onLink("https://jackwallner.github.io/simpleglp/privacy-policy.html") }) { Text("Privacy") }
        }
    }
}

private fun trialDaysOf(content: TrialOfferContent): Int? {
    val value = content.trialValue ?: return null; val unit = content.trialUnit ?: return null
    return com.jackwallner.glp.data.trialDays(value, unit)
}

@Composable private fun TimelineStep(icon: ImageVector, title: String, detail: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
        Column { Text(title, style = MaterialTheme.typography.titleSmall); Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}
