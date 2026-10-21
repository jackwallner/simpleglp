package com.jackwallner.glp

import android.content.Intent
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The Play reviewer unlock. Pass the throwaway code whose SHA-256 is in
 * local.properties with `-Pandroid.testInstrumentationRunnerArguments.reviewCode=...`.
 */
@RunWith(AndroidJUnit4::class)
class ReviewerUnlockTest {
    @get:Rule val compose = createEmptyComposeRule()
    private var scenario: ActivityScenario<MainActivity>? = null
    private val context get() = ApplicationProvider.getApplicationContext<GLPApplication>()
    @After fun close() { scenario?.close() }

    @Test fun longPressOnVersionRejectsAWrongCodeAndUnlocksWithTheRightOne() {
        val code = checkNotNull(InstrumentationRegistry.getArguments().getString("reviewCode")) {
            "Supply the throwaway reviewer code as the reviewCode instrumentation argument."
        }
        val intent = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra("test_reset", true).putExtra("uitesting", true).putExtra("seed_shot", true)
        scenario = ActivityScenario.launch(intent)
        compose.waitForIdle()
        assertFalse(context.graph.store.isPro)

        compose.onNode(hasText("Settings") and hasClickAction()).performClick()
        compose.onNodeWithTag("version-row").performScrollTo().performTouchInput { longClick() }

        compose.onNodeWithTag("reviewer-code").performTextInput("wrong")
        compose.onNodeWithText("Unlock").performClick()
        compose.onNodeWithText("That code isn't valid.").assertIsDisplayed()
        assertFalse(context.graph.store.isPro)

        compose.onNodeWithTag("reviewer-code").performTextClearance()
        compose.onNodeWithTag("reviewer-code").performTextInput(code)
        compose.onNodeWithText("Unlock").performClick()
        compose.waitForIdle()
        assertTrue(context.graph.store.isPro)
        compose.onAllNodes(hasTestTag("reviewer-code")).fetchSemanticsNodes().let { assertTrue(it.isEmpty()) }
        compose.onNodeWithText("Pro is active").performScrollTo().assertIsDisplayed()
    }
}
