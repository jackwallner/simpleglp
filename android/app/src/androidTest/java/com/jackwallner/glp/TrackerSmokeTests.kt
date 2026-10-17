package com.jackwallner.glp

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.jackwallner.glp.model.*
import com.jackwallner.glp.data.NotificationService
import org.junit.After
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant

@RunWith(AndroidJUnit4::class)
class TrackerSmokeTests {
    @get:Rule val compose = createEmptyComposeRule()
    private var scenario: ActivityScenario<MainActivity>? = null
    private val context get() = ApplicationProvider.getApplicationContext<GLPApplication>()
    private fun launch(pill: Boolean? = null, pro: Boolean = false) {
        val intent = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra("test_reset", true).putExtra("uitesting", true).putExtra("test_pro", pro)
        if (pill != null) intent.putExtra(if (pill) "seed_pill" else "seed_shot", true)
        if (android.os.Build.VERSION.SDK_INT >= 33) InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand("pm grant ${context.packageName} android.permission.POST_NOTIFICATIONS").close()
        scenario = ActivityScenario.launch(intent)
        compose.waitForIdle()
    }
    private fun node(text: String) = compose.onNodeWithText(text, useUnmergedTree = true)
    private fun tab(text: String) = compose.onNode(hasText(text) and hasClickAction())
    @After fun close() { scenario?.close() }
    @Test fun firstRunSavesPlan() {
        launch()
        repeat(5) { node("Continue").performClick() }
        node("Get Started").performClick()
        node("I took my shot").assertIsDisplayed()
        assertNotNull(context.graph.tracker.plan)
    }
    @Test fun shotLogUndoRestoresHistory() {
        launch(false)
        val before = context.graph.tracker.events.size
        node("I took my shot").performClick()
        assertEquals(before + 1, context.graph.tracker.events.size)
        node("Undo").performClick()
        assertEquals(before, context.graph.tracker.events.size)
    }
    @Test fun pillStartsWaitAndUndoCancelsIt() {
        launch(true)
        node("I took my pill").performClick()
        compose.onNodeWithTag("wait_timer", useUnmergedTree = true).assertExists()
        node("Undo").performClick()
        compose.onNodeWithTag("wait_timer", useUnmergedTree = true).assertDoesNotExist()
    }
    @Test fun duplicateDailyCannotDoubleLog() {
        launch(true)
        node("I took my pill").performClick()
        val count = context.graph.tracker.events.size
        node("I took my pill").performClick()
        node("Already logged").assertIsDisplayed()
        node("Cancel").performClick()
        assertEquals(count, context.graph.tracker.events.size)
    }
    @Test fun freeSupplyShowsDismissiblePaywall() {
        launch(false)
        tab("Settings").performClick()
        node("Supply & refills · Pro").performScrollTo().performClick()
        node("Stay ahead of your routine").assertIsDisplayed()
        node("Not now").performScrollTo().performClick()
        node("Medication & schedule").assertExists()
        assertFalse(context.graph.store.isPro)
    }
    @Test fun proSupplyCountsDownAndUndoRestores() {
        launch(true, true)
        scenario!!.onActivity { context.graph.tracker.savePlan(context.graph.tracker.plan!!.copy(supplyCount = 30, supplyUpdatedAt = Instant.now())) }
        node("I took my pill").performClick()
        assertEquals(29, SupplyMath.remaining(context.graph.tracker.plan!!, context.graph.tracker.events))
        node("Undo").performClick()
        assertEquals(30, SupplyMath.remaining(context.graph.tracker.plan!!, context.graph.tracker.events))
    }
    @Test fun importedAndEditedDetailsPersistAfterRecreation() {
        launch(false)
        scenario!!.onActivity { context.graph.tracker.edit(context.graph.tracker.events.first().copy(notes = "Test note", site = "Left thigh")) }
        scenario!!.recreate()
        tab("History").performClick()
        node("Test note").performScrollTo().assertIsDisplayed()
        node("Left thigh").assertExists()
    }
    @Test fun appearanceAndBackNavigationWork() {
        launch(true)
        tab("Settings").performClick()
        node("Appearance").performScrollTo().performClick()
        node("Dark").performClick()
        assertEquals("dark", context.graph.tracker.appearance)
        node("Medication & schedule").performScrollTo().performClick()
        compose.onNodeWithContentDescription("Back").performClick()
        node("Medication & schedule").assertExists()
    }
    @Test fun keyboardInputResizesAndSavesLogEarlier() {
        launch(false)
        node("Log earlier").performClick()
        compose.onNode(hasSetTextAction() and hasText("Notes")).performScrollTo().performClick().performTextInput("Keyboard note")
        node("Save").performScrollTo().performClick()
        assertTrue(context.graph.tracker.events.any { it.notes == "Keyboard note" })
    }
    @Test fun deletingActivePillCancelsWait() {
        launch(true)
        node("I took my pill").performClick()
        scenario!!.onActivity {
            val e = context.graph.tracker.events.maxBy { it.timestamp }
            context.graph.tracker.edit(e.copy(notes = "Current pill"))
        }
        tab("History").performClick()
        node("Current pill").performScrollTo().performClick()
        node("Delete this pill").performScrollTo().performClick()
        node("Delete").performClick()
        tab("One Tap").performClick()
        compose.onNodeWithTag("wait_timer", useUnmergedTree = true).assertDoesNotExist()
    }
    @Test fun shotPlanCanChangeToDailyPill() {
        launch(false)
        tab("Settings").performClick()
        node("Medication & schedule").performScrollTo().performClick()
        node("How do you take it?").performScrollTo().performClick()
        node("Daily pill").performClick()
        node("Save plan").performScrollTo().performClick()
        assertEquals(DoseForm.PILL, context.graph.tracker.plan!!.form)
        assertEquals(1, context.graph.tracker.plan!!.cadence)
        assertEquals(30, context.graph.tracker.plan!!.wait)
    }

    @Test fun freePillDoesNotPostOngoingCountdown() {
        launch(true)
        node("I took my pill").performClick()
        val manager = context.getSystemService(NotificationManager::class.java)
        assertFalse(manager.activeNotifications.any { it.id == NotificationService.COUNTDOWN_ID })
        compose.onNodeWithTag("wait_timer", useUnmergedTree = true).assertExists()
    }
    @Test fun proPillPostsChronometerAndUndoRemovesIt() {
        launch(true, true)
        node("I took my pill").performClick()
        val manager = context.getSystemService(NotificationManager::class.java)
        compose.waitUntil(5000) { manager.activeNotifications.any { it.id == NotificationService.COUNTDOWN_ID } }
        val notification = manager.activeNotifications.single { it.id == NotificationService.COUNTDOWN_ID }.notification
        assertTrue(notification.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
        assertTrue(notification.timeoutAfter in 1..1800000L)
        val deadline = DoseRoutine.waitEnd(context.graph.tracker.plan!!, context.graph.tracker.events, Instant.now())!!
        assertEquals(deadline.toEpochMilli(), notification.`when`)
        node("Undo").performClick()
        compose.waitUntil(5000) { manager.activeNotifications.none { it.id == NotificationService.COUNTDOWN_ID } }
    }

    @Test fun firstRunPillFreeExitKeepsDailyPlan() {
        launch()
        node("Continue").performClick()
        node("How do you take it?").performScrollTo().performClick()
        node("Pill").performClick()
        node("Continue").performClick()
        node("Your daily routine").assertExists()
        repeat(3) { node("Continue").performClick() }
        node("Get Started").performClick()
        node("I took my pill").assertIsDisplayed()
        assertEquals(DoseForm.PILL, context.graph.tracker.plan!!.form)
        assertEquals(1, context.graph.tracker.plan!!.cadence)
        assertEquals(30, context.graph.tracker.plan!!.wait)
        assertFalse(context.graph.store.isPro)
    }
    @Test fun onboardingDraftAndFixedCtaSurviveBackAndRecreation() {
        launch()
        fun bounds(tag: String) = compose.onNodeWithTag(tag, useUnmergedTree = true).fetchSemanticsNode().boundsInRoot
        val initialCta = bounds("onboarding-primary")
        val initialFooter = bounds("onboarding-footer")
        node("Continue").performClick()
        node("Current dose").performScrollTo().performClick()
        node("0.5 mg").performClick()
        node("Continue").performClick()
        assertEquals(initialCta.top, bounds("onboarding-primary").top, 1f)
        node("Back").performClick()
        scenario!!.recreate()
        node("0.5 mg").assertExists()
        repeat(4) { node("Continue").performClick() }
        assertEquals(initialCta.top, bounds("onboarding-primary").top, 1f)
        assertEquals(initialCta.height, bounds("onboarding-primary").height, 1f)
        assertEquals(initialFooter.top, bounds("onboarding-footer").top, 1f)
        node("Get Started").performClick()
        assertEquals(0.5, context.graph.tracker.plan!!.doseMg, 0.0)
    }
    @Test fun memberOnboardingSkipsThePurchaseOffer() {
        launch(pro = true)
        repeat(5) { node("Continue").performClick() }
        node("I took my shot").assertIsDisplayed()
        assertTrue(context.graph.store.isPro)
        node("Get Started").assertDoesNotExist()
    }

}
