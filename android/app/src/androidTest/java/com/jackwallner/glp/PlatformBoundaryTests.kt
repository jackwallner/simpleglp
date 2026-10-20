package com.jackwallner.glp

import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** What the installed app may touch on a real device: Play Console declarations depend on it. */
@RunWith(AndroidJUnit4::class)
class PlatformBoundaryTests {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun requestsNoHealthLocationStorageOrExactAlarmAccess() {
        val info = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
        val requested = info.requestedPermissions.orEmpty().toSet()
        assertTrue(requested.none { it.startsWith("android.permission.health.") })
        val forbidden = setOf("android.permission.ACCESS_FINE_LOCATION", "android.permission.ACCESS_COARSE_LOCATION", "android.permission.READ_EXTERNAL_STORAGE",
            "android.permission.WRITE_EXTERNAL_STORAGE", "android.permission.SCHEDULE_EXACT_ALARM", "android.permission.USE_EXACT_ALARM", "android.permission.ACTIVITY_RECOGNITION",
            "android.permission.BODY_SENSORS", "com.google.android.gms.permission.AD_ID")
        assertTrue("unexpected: ${requested intersect forbidden}", (requested intersect forbidden).isEmpty())
        // Network exists only for RevenueCat and Play Billing; reminders survive reboot.
        assertTrue(requested.containsAll(setOf("android.permission.INTERNET", "android.permission.POST_NOTIFICATIONS", "android.permission.RECEIVE_BOOT_COMPLETED", "com.android.vending.BILLING")))
    }

    @Test fun keepsDoseHistoryOutOfCloudBackup() {
        val flags = context.packageManager.getApplicationInfo(context.packageName, 0).flags
        assertEquals(0, flags and android.content.pm.ApplicationInfo.FLAG_ALLOW_BACKUP)
    }
}
