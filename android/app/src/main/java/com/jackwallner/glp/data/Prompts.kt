package com.jackwallner.glp.data

import android.content.SharedPreferences
import androidx.core.content.edit

/** Rating-ask pacing, ported from iOS `ReviewPromptTracker`. No question ever precedes the Play card. */
object ReviewPolicy {
    const val MINIMUM_LAUNCHES = 2
    const val COOLDOWN_MS = 30L * 86_400_000

    /**
     * `permissionQuestionOpen` is true only while the system notification dialog is on screen.
     * A permission that was never asked (reminders off) must not block the ask.
     */
    fun shouldAsk(launches: Int, lastShownMs: Long, rated: Boolean, pending: Boolean, setupDone: Boolean, permissionQuestionOpen: Boolean, nowMs: Long): Boolean =
        pending && !permissionQuestionOpen && setupDone && !rated && launches >= MINIMUM_LAUNCHES && nowMs - lastShownMs >= COOLDOWN_MS
}

/** Persists the review counters. Keys predate the port's first build and stay stable. */
class ReviewPrompts(private val prefs: SharedPreferences) {
    fun recordLaunch() { prefs.edit { putInt("launches", prefs.getInt("launches", 0) + 1) } }
    /** A blocked ask keeps the moment pending, so the next positive moment can ask. */
    fun recordPositiveMoment() { prefs.edit { putBoolean("pending", true) } }
    fun shouldAsk(setupDone: Boolean, permissionQuestionOpen: Boolean, nowMs: Long = System.currentTimeMillis()): Boolean =
        ReviewPolicy.shouldAsk(prefs.getInt("launches", 0), prefs.getLong("last", 0), prefs.getBoolean("rated", false),
            prefs.getBoolean("pending", false), setupDone, permissionQuestionOpen, nowMs)
    fun markShown(nowMs: Long = System.currentTimeMillis()) { prefs.edit { putLong("last", nowMs); putBoolean("pending", false) } }
    /** Only opening the store listing ends the passive asks. Sending feedback never does. */
    fun markOpenedListing() { prefs.edit { putBoolean("rated", true); putLong("last", System.currentTimeMillis()); putBoolean("pending", false) } }
}

enum class TrialSource { FIRST_DOSE, EXISTING_USER, PATTERNS }

/** One-shot trial pitch gating, ported from iOS `RootTabView.presentTrialOfferIfReady`. */
object TrialOfferPolicy {
    fun shouldPresent(source: TrialSource, setupDone: Boolean, resolved: Boolean, isPro: Boolean, hadPro: Boolean, hasTrial: Boolean,
                      shownThisSession: Boolean, screenClear: Boolean, seen: Boolean, seenPatterns: Boolean): Boolean {
        // Never pitch before entitlements resolve, to a lapsed member, or over anything else on screen.
        if (!setupDone || !resolved || isPro || hadPro || !hasTrial || shownThisSession || !screenClear) return false
        return when (source) {
            TrialSource.FIRST_DOSE, TrialSource.EXISTING_USER -> !seen
            TrialSource.PATTERNS -> !seenPatterns
        }
    }
}

class TrialOffers(private val prefs: SharedPreferences) {
    val seen get() = prefs.getBoolean("seen", false)
    val seenPatterns get() = prefs.getBoolean("seenPatterns", false)
    /**
     * Marked at presentation so it stays one-shot if the app dies with the sheet up. A first-dose
     * dismissal leaves the Patterns touch available for a later session.
     */
    fun markSeen(source: TrialSource) {
        prefs.edit {
            putBoolean("seen", true)
            if (source == TrialSource.PATTERNS) putBoolean("seenPatterns", true)
        }
    }
}

/** Trial length from a Play billing period, in days for the timeline. */
fun trialDays(value: Int, unit: String): Int? = when (unit.uppercase()) {
    "DAY" -> value
    "WEEK" -> value * 7
    "MONTH" -> value * 30
    else -> null
}
