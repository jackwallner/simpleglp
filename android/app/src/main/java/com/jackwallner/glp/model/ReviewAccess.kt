package com.jackwallner.glp.model

import java.security.MessageDigest

class ReviewAccess(
    private val expectedDigest: String,
    private val savedDigest: () -> String?,
    private val persistDigest: (String) -> Unit,
) {
    private val configured get() = expectedDigest.matches(Regex("[a-f0-9]{64}"))
    val isGranted get() = configured && savedDigest() == expectedDigest

    fun activate(code: String): Boolean {
        if (!configured || code.isBlank()) return false
        val digest = MessageDigest.getInstance("SHA-256").digest(code.trim().toByteArray())
            .joinToString("") { "%02x".format(it) }
        if (!MessageDigest.isEqual(digest.toByteArray(), expectedDigest.toByteArray())) return false
        persistDigest(digest)
        return true
    }
}
