package com.jackwallner.glp

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.jackwallner.glp.ui.screens.TrialOfferBody
import com.jackwallner.glp.ui.screens.TrialOfferContent
import com.jackwallner.glp.ui.theme.GLPTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TrialOfferSheetTests {
    @get:Rule val compose = createComposeRule()
    private var started = 0; private var dismissed = 0; private var seeAll = 0

    private fun show(content: TrialOfferContent, purchasing: Boolean = false, error: String? = null, pending: Boolean = false) = compose.setContent {
        GLPTheme("light") { TrialOfferBody(content, purchasing, error, false, { started++ }, { seeAll++ }, {}, {}, { dismissed++ }, pending = pending) }
    }

    @Test fun pillPitchShowsLengthPriceAndTermsBeforePurchase() {
        show(TrialOfferContent(7, "DAY", "$29.99 per year", isPill = true))
        compose.onNodeWithText("7 days of Pro, free.").assertIsDisplayed()
        compose.onNodeWithText("Lock Screen countdown").assertExists()
        compose.onNodeWithText("Day 7").assertExists()
        compose.onNodeWithTag("trial-price").performScrollTo().assertTextEquals("then $29.99 per year")
        compose.onNodeWithText("Free for 7 days. Renews automatically", substring = true).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Terms").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Privacy").assertIsDisplayed()
        compose.onNodeWithText("Start My 7-Day Free Trial").performScrollTo().performClick()
        assertEquals(1, started)
    }

    @Test fun shotPitchNeverQuotesAPriceItDoesNotHave() {
        show(TrialOfferContent(null, null, null, isPill = false))
        compose.onNodeWithText("Try Simple GLP Pro free.").assertIsDisplayed()
        compose.onNodeWithText("Dose-day nudges").assertExists()
        compose.onNodeWithTag("trial-price").assertDoesNotExist()
        compose.onNodeWithText("Day ", substring = true).assertDoesNotExist()
        compose.onNodeWithTag("trial-dismiss").performScrollTo().performClick()
        compose.onNodeWithText("See all plans").performClick()
        assertEquals(1, dismissed); assertEquals(1, seeAll)
    }

    @Test fun pendingPurchaseShowsRefreshAndKeepsTheFreeExit() {
        show(TrialOfferContent(7, "DAY", "$29.99 per year", isPill = false), pending = true)
        compose.onNodeWithText("Purchase pending.", substring = true).performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("trial-start").performScrollTo().assertTextEquals("Refresh status").assertIsEnabled()
        compose.onNodeWithText("Start My 7-Day Free Trial").assertDoesNotExist()
        compose.onNodeWithTag("trial-dismiss").performScrollTo().assertTextEquals("Continue free").performClick()
        assertEquals(1, dismissed)
        assertEquals(0, started)
    }

    @Test fun purchaseInFlightLocksTheExits() {
        show(TrialOfferContent(7, "DAY", "$29.99 per year", isPill = false), purchasing = true, error = "Trial wasn't started. Tap again, or pick a different plan.")
        compose.onNodeWithTag("trial-start").performScrollTo().assertIsNotEnabled()
        compose.onNodeWithTag("trial-dismiss").assertIsNotEnabled()
        compose.onNodeWithText("Trial wasn't started", substring = true).assertExists()
    }
}
