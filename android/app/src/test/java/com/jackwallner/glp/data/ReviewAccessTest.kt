package com.jackwallner.glp.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReviewAccessTest {
    private class MapStore : StringStore {
        val values = mutableMapOf<String, String>()
        override fun getString(key: String) = values[key]
        override fun putString(key: String, value: String) { values[key] = value }
    }

    // A throwaway fixture, not a real reviewer code.
    private val fixture = "local-review-fixture"
    private val digest = ReviewAccess.sha256(fixture)

    @Test
    fun digestIsLowercaseSha256Hex() {
        assertTrue(Regex("[a-f0-9]{64}").matches(digest))
        assertEquals(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            ReviewAccess.sha256(""),
        )
    }

    @Test
    fun unconfiguredAccessCannotUnlock() {
        assertFalse(ReviewAccess(MapStore(), "").activate(fixture))
        assertFalse(ReviewAccess(MapStore(), "invalid").activate("invalid"))
        assertFalse(ReviewAccess(MapStore(), "").isGranted)
    }

    @Test
    fun wrongOrBlankCodeDoesNotGrantAccess() {
        val store = MapStore()
        val access = ReviewAccess(store, digest)
        assertFalse(access.activate("wrong"))
        assertFalse(access.activate("  "))
        assertFalse(access.isGranted)
        assertTrue(store.values.isEmpty())
    }

    @Test
    fun validCodePersistsOnlyTheDigest() {
        val store = MapStore()
        assertTrue(ReviewAccess(store, digest).activate(" $fixture "))
        assertTrue(ReviewAccess(store, digest).isGranted)
        assertEquals(mapOf("reviewAccessDigest" to digest), store.values)
    }

    @Test
    fun rotatingTheDigestRevokesAnExistingGrant() {
        val store = MapStore()
        assertTrue(ReviewAccess(store, digest).activate(fixture))
        assertFalse(ReviewAccess(store, ReviewAccess.sha256("another-fixture")).isGranted)
        assertFalse(ReviewAccess(store, "").isGranted)
    }
}
