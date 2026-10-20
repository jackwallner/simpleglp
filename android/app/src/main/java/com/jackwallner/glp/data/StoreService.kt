package com.jackwallner.glp.data

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.glp.BuildConfig
import com.revenuecat.purchases.*
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import kotlinx.coroutines.CancellationException

enum class PurchaseOutcome { PURCHASED, PENDING, CANCELLED }

class StoreService(context: Context) {
    var isPro by mutableStateOf(false); private set
    /** Any Pro entitlement on record, active or lapsed. Lapsed members never get a trial pitch. */
    var hadPro by mutableStateOf(false); private set
    var resolved by mutableStateOf(false); private set
    var packages by mutableStateOf<List<Package>>(emptyList()); private set
    var error by mutableStateOf<String?>(null); private set
    var busy by mutableStateOf(false); private set
    private var configured = false
    private var debugPro = false
    init {
        val key = BuildConfig.REVENUECAT_API_KEY
        if ((BuildConfig.DEBUG && key.startsWith("test_")) || (!BuildConfig.DEBUG && key.startsWith("goog_"))) {
            Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
            Purchases.configure(PurchasesConfiguration.Builder(context, key).build())
            Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener(::apply)
            configured = true
        } else resolved = true
    }
    fun forceProForDebug(value: Boolean) { if (BuildConfig.DEBUG) { debugPro = value; isPro = value; resolved = true } }
    private fun apply(info: CustomerInfo) {
        isPro = debugPro || ENTITLEMENTS.any { info.entitlements.active[it]?.isActive == true }
        hadPro = isPro || ENTITLEMENTS.any { info.entitlements.all[it] != null }
        resolved = true
    }
    suspend fun refresh() {
        if (!configured) { error = "Plans are unavailable in this build. Logging and reminders are free."; return }
        busy = true
        try {
            apply(Purchases.sharedInstance.awaitCustomerInfo())
            val offerings = Purchases.sharedInstance.awaitOfferings()
            packages = (offerings.all["default"] ?: offerings.current)?.availablePackages.orEmpty()
                .filter { it.product.id.substringBefore(":") in PRODUCTS }
            error = if (packages.isEmpty()) "Plans are temporarily unavailable. Please try again." else null
        } catch (e: CancellationException) { throw e } catch (_: Exception) { error = "Couldn't load plans. Check your connection and try again." }
        finally { busy = false }
    }
    suspend fun purchase(activity: Activity, pkg: Package): PurchaseOutcome {
        check(configured)
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
            apply(result.customerInfo)
            if (isPro) PurchaseOutcome.PURCHASED else PurchaseOutcome.PENDING
        } catch (e: PurchasesTransactionException) {
            when {
                e.userCancelled || e.code == PurchasesErrorCode.PurchaseCancelledError -> PurchaseOutcome.CANCELLED
                e.code == PurchasesErrorCode.PaymentPendingError -> PurchaseOutcome.PENDING
                else -> throw IllegalStateException("Couldn't complete the purchase. Please try again.")
            }
        }
    }
    suspend fun restore() {
        if (!configured) { error = "Purchases are unavailable in this build."; return }
        busy = true
        try { apply(Purchases.sharedInstance.awaitRestore()); error = if (isPro) "Purchases restored." else "No active Simple GLP Pro purchase was found for this account." }
        catch (e: CancellationException) { throw e } catch (_: Exception) { error = "Couldn't restore purchases. Try again." }
        finally { busy = false }
    }
    /** The yearly package when Play offers this account a free phase on it; drives the one-tap trial pitch. */
    val trialPackage: Package? get() = packages.firstOrNull { it.packageType == PackageType.ANNUAL && it.product.defaultOption?.freePhase != null }
    companion object {
        val ENTITLEMENTS = listOf("GLP Pro", "SimpleGLPPro", "pro")
        val PRODUCTS = setOf("com.jackwallner.glp.pro.monthly", "com.jackwallner.glp.pro.yearly", "com.jackwallner.glp.pro.lifetime")
    }
}
