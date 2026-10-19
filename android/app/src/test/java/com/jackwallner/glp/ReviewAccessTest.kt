package com.jackwallner.glp

import java.security.MessageDigest

import org.junit.Assert.*
import org.junit.Test

import com.jackwallner.glp.model.ReviewAccess

class ReviewAccessTest {
    private val fixture = "local-review-fixture"
    private val digest = MessageDigest.getInstance("SHA-256").digest(fixture.toByteArray()).joinToString("") { "%02x".format(it) }
    private var saved: String? = null
    private fun access(hash: String = digest) = ReviewAccess(hash, { saved }, { saved = it })

    @Test fun unconfiguredAccessCannotUnlock() {
        assertFalse(access("").activate(fixture))
        assertFalse(access("invalid").isGranted)
        assertNull(saved)
    }

    @Test fun wrongOrBlankCodeDoesNotGrantAccess() {
        assertFalse(access().activate("wrong"))
        assertFalse(access().activate(" "))
        assertFalse(access().isGranted)
        assertNull(saved)
    }

    @Test fun validCodePersistsOnlyDigestAcrossRecreation() {
        assertTrue(access().activate(" $fixture "))
        assertTrue(access().isGranted)
        assertEquals(digest, saved)
        assertNotEquals(fixture, saved)
    }

    @Test fun rotatingDigestInvalidatesExistingAccess() {
        assertTrue(access().activate(fixture))
        assertFalse(access("0".repeat(64)).isGranted)
    }
}
