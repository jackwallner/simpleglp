package com.jackwallner.glp

import android.content.SharedPreferences
import com.jackwallner.glp.data.ReviewPrompts
import com.jackwallner.glp.data.TrialOfferPolicy
import com.jackwallner.glp.data.TrialOffers
import com.jackwallner.glp.data.TrialSource
import com.jackwallner.glp.data.trialDays
import com.jackwallner.glp.ui.screens.TrialCopy
import com.jackwallner.glp.ui.screens.TrialOfferContent
import org.junit.Assert.*
import org.junit.Test

/** In-memory prefs so the persisted trackers run on the JVM exactly as on device. */
private class MemoryPrefs : SharedPreferences {
    val values = mutableMapOf<String, Any?>()
    override fun getAll() = values.toMutableMap()
    override fun getString(key: String, def: String?) = values[key] as? String ?: def
    override fun getStringSet(key: String, def: MutableSet<String>?) = def
    override fun getInt(key: String, def: Int) = values[key] as? Int ?: def
    override fun getLong(key: String, def: Long) = values[key] as? Long ?: def
    override fun getFloat(key: String, def: Float) = values[key] as? Float ?: def
    override fun getBoolean(key: String, def: Boolean) = values[key] as? Boolean ?: def
    override fun contains(key: String) = key in values
    override fun registerOnSharedPreferenceChangeListener(l: SharedPreferences.OnSharedPreferenceChangeListener?) = Unit
    override fun unregisterOnSharedPreferenceChangeListener(l: SharedPreferences.OnSharedPreferenceChangeListener?) = Unit
    override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
        val pending = mutableMapOf<String, Any?>()
        override fun putString(k: String, v: String?) = apply { pending[k] = v }
        override fun putStringSet(k: String, v: MutableSet<String>?) = apply { pending[k] = v }
        override fun putInt(k: String, v: Int) = apply { pending[k] = v }
        override fun putLong(k: String, v: Long) = apply { pending[k] = v }
        override fun putFloat(k: String, v: Float) = apply { pending[k] = v }
        override fun putBoolean(k: String, v: Boolean) = apply { pending[k] = v }
        override fun remove(k: String) = apply { pending[k] = null }
        override fun clear() = apply { values.clear() }
        override fun commit(): Boolean { apply(); return true }
        override fun apply() { pending.forEach { (k, v) -> if (v == null) values.remove(k) else values[k] = v } }
    }
}

class PromptPolicyTests {
    private val day = 86_400_000L
    private fun reviews(launches: Int) = ReviewPrompts(MemoryPrefs()).apply { repeat(launches) { recordLaunch() } }

    @Test fun asksFromTheSecondSession() {
        val r = reviews(2); r.recordPositiveMoment()
        assertTrue(r.shouldAsk(setupDone = true, permissionQuestionOpen = false))
    }
    @Test fun neverAsksInTheFirstSession() {
        val r = reviews(1); r.recordPositiveMoment()
        assertFalse(r.shouldAsk(setupDone = true, permissionQuestionOpen = false))
    }
    @Test fun stillRequiresFinishedSetup() {
        val r = reviews(3); r.recordPositiveMoment()
        assertFalse(r.shouldAsk(setupDone = false, permissionQuestionOpen = false))
    }
    @Test fun needsAPositiveMoment() {
        assertFalse(reviews(3).shouldAsk(setupDone = true, permissionQuestionOpen = false))
    }
    @Test fun openingTheListingEndsTheAsks() {
        val r = reviews(3); r.markOpenedListing(); r.recordPositiveMoment()
        assertFalse(r.shouldAsk(true, false, System.currentTimeMillis() + 400 * day))
    }
    @Test fun waitsOutTheCooldown() {
        val r = reviews(3); val shown = 1_000 * day
        r.markShown(shown); r.recordPositiveMoment()
        assertFalse(r.shouldAsk(true, false, shown + 29 * day))
        assertTrue(r.shouldAsk(true, false, shown + 30 * day))
    }
    @Test fun blockedAskKeepsTheMomentPending() {
        val r = reviews(2); r.recordPositiveMoment()
        assertFalse(r.shouldAsk(setupDone = true, permissionQuestionOpen = true))
        assertTrue(r.shouldAsk(setupDone = true, permissionQuestionOpen = false))
        r.markShown(); assertFalse(r.shouldAsk(true, false))
    }
    @Test fun remindersOffStillGetsAsked() {
        // Notification permission never asked: only an open dialog blocks, never a missing grant.
        val r = reviews(2); r.recordPositiveMoment()
        assertTrue(r.shouldAsk(setupDone = true, permissionQuestionOpen = false))
    }

    private fun present(source: TrialSource = TrialSource.FIRST_DOSE, resolved: Boolean = true, isPro: Boolean = false, hadPro: Boolean = false,
                        hasTrial: Boolean = true, shown: Boolean = false, clear: Boolean = true, seen: Boolean = false, seenPatterns: Boolean = false, setup: Boolean = true) =
        TrialOfferPolicy.shouldPresent(source, setup, resolved, isPro, hadPro, hasTrial, shown, clear, seen, seenPatterns)

    @Test fun trialWaitsForResolvedEntitlements() {
        assertTrue(present()); assertFalse(present(resolved = false))
    }
    @Test fun trialNeverPitchesMembersOrLapsedMembers() {
        assertFalse(present(isPro = true)); assertFalse(present(hadPro = true))
    }
    @Test fun trialNeedsARealTrialOfferAndAClearScreen() {
        assertFalse(present(hasTrial = false)); assertFalse(present(clear = false)); assertFalse(present(shown = true)); assertFalse(present(setup = false))
    }
    @Test fun firstDoseDismissalLeavesThePatternsTouch() {
        val offers = TrialOffers(MemoryPrefs())
        offers.markSeen(TrialSource.FIRST_DOSE)
        assertTrue(offers.seen); assertFalse(offers.seenPatterns)
        assertFalse(present(TrialSource.EXISTING_USER, seen = offers.seen, seenPatterns = offers.seenPatterns))
        assertTrue(present(TrialSource.PATTERNS, seen = offers.seen, seenPatterns = offers.seenPatterns))
        offers.markSeen(TrialSource.PATTERNS)
        assertFalse(present(TrialSource.PATTERNS, seen = offers.seen, seenPatterns = offers.seenPatterns))
    }
    @Test fun trialCopyNamesLengthPriceAndCancellation() {
        val week = TrialOfferContent(7, "DAY", "$29.99 per year", isPill = true)
        assertEquals("7 days of Pro, free.", TrialCopy.headline(week))
        assertEquals("Start My 7-Day Free Trial", TrialCopy.button(week))
        assertEquals("A Lock Screen countdown and refill reminders, on autopilot. Free until your trial ends.", TrialCopy.subheadline(week))
        assertTrue(TrialCopy.disclosure(week).startsWith("Free for 7 days. Renews automatically"))
        assertTrue(TrialCopy.disclosure(week).contains("Google Play > Payments & subscriptions"))
        val unknown = TrialOfferContent(null, null, null, isPill = false)
        assertEquals("Try Simple GLP Pro free.", TrialCopy.headline(unknown))
        assertEquals("Start My Free Trial", TrialCopy.button(unknown))
        assertEquals("Dose-day nudges and refill reminders, free for eligible new subscribers.", TrialCopy.subheadline(unknown))
        assertEquals("1 month of Pro, free.", TrialCopy.headline(TrialOfferContent(1, "MONTH", null, false)))
    }
    @Test fun trialTimelineDays() {
        assertEquals(7, trialDays(7, "DAY")); assertEquals(14, trialDays(2, "WEEK")); assertEquals(30, trialDays(1, "MONTH")); assertNull(trialDays(1, "YEAR"))
    }
}
