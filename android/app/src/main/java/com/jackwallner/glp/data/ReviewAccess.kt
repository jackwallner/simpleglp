package com.jackwallner.glp.data

import android.content.SharedPreferences
import androidx.core.content.edit
import java.security.MessageDigest

/** The few string reads and writes `ReviewAccess` needs, so JVM tests can use a map. */
interface StringStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
}

class PreferencesStringStore(private val prefs: SharedPreferences) : StringStore {
    override fun getString(key: String): String? = prefs.getString(key, null)
    override fun putString(key: String, value: String) { prefs.edit { putString(key, value) } }
}

/**
 * The Play reviewer unlock. The build holds only the SHA-256 of the private
 * code (`PLAY_REVIEW_CODE_SHA256`). A matching code stores that digest on this
 * install, and access holds only while the stored digest still equals the one
 * built in, so rotating the digest revokes every earlier grant. It is never a
 * purchase and is never sent to RevenueCat.
 */
class ReviewAccess(private val store: StringStore, private val expectedDigest: String) {
    private val configured get() = DIGEST_PATTERN.matches(expectedDigest)

    val isGranted get() = configured && store.getString(KEY) == expectedDigest

    fun activate(code: String): Boolean {
        if (!configured || code.isBlank()) return false
        val digest = sha256(code.trim())
        if (!MessageDigest.isEqual(digest.toByteArray(), expectedDigest.toByteArray())) return false
        store.putString(KEY, digest)
        return true
    }

    companion object {
        private const val KEY = "reviewAccessDigest"
        private val DIGEST_PATTERN = Regex("[a-f0-9]{64}")

        fun sha256(text: String): String =
            MessageDigest.getInstance("SHA-256").digest(text.toByteArray()).joinToString("") { "%02x".format(it) }
    }
}
