package com.jackwallner.glp.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PurchaseActivationTest {
    private class MapStore : StringStore {
        private val values = mutableMapOf<String, String>()
        override fun getString(key: String) = values[key]
        override fun putString(key: String, value: String) { values[key] = value }
    }

    @Test fun completedTransactionWithoutProStaysPendingAcrossRestarts() {
        val prefs = MapStore()
        val activation = PurchaseActivation(prefs)
        assertEquals(PurchaseOutcome.PENDING, activation.completed(false))
        assertTrue(activation.pending)
        assertTrue(PurchaseActivation(prefs).pending)
    }

    @Test fun unresolvedEntitlementsDoNotClearPending() {
        val activation = PurchaseActivation(MapStore())
        activation.completed(false)
        activation.entitlementUpdated(false)
        assertTrue(activation.pending)
    }

    @Test fun verifiedActivationClearsPersistedPending() {
        val prefs = MapStore()
        val activation = PurchaseActivation(prefs)
        activation.completed(false)
        activation.entitlementUpdated(true)
        assertFalse(activation.pending)
        assertFalse(PurchaseActivation(prefs).pending)
    }

    @Test fun onlyActiveProIsPurchaseSuccess() {
        val activation = PurchaseActivation(MapStore())
        assertEquals(PurchaseOutcome.PURCHASED, activation.completed(true))
        assertFalse(activation.pending)
    }
}
