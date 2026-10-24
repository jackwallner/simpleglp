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
import kotlinx.coroutines.delay

enum class PurchaseOutcome { PURCHASED, PENDING, CANCELLED }

class PurchaseActivation(private val store: StringStore) {
    var pending = store.getString(KEY) == "true"; private set

    fun completed(isPro: Boolean): PurchaseOutcome {
        update(isPro)
        return if (isPro) PurchaseOutcome.PURCHASED else PurchaseOutcome.PENDING
    }

    private fun update(isPro: Boolean) {
        pending = !isPro
        store.putString(KEY, pending.toString())
    }

    fun entitlementUpdated(isPro: Boolean) { if (isPro && pending) update(true) }

    companion object { private const val KEY = "purchasePending" }
}

class StoreService(
    context: Context,
    private val reviewAccess: ReviewAccess = ReviewAccess(
        PreferencesStringStore(context.getSharedPreferences("reviewAccess", Context.MODE_PRIVATE)), BuildConfig.PLAY_REVIEW_CODE_SHA256),
) {
    private val activation = PurchaseActivation(PreferencesStringStore(context.getSharedPreferences("billing", Context.MODE_PRIVATE)))
    var purchasePending by mutableStateOf(activation.pending); private set
    var refreshingPurchase by mutableStateOf(false); private set
    var isPro by mutableStateOf(reviewAccess.isGranted); private set
    /** Any Pro entitlement on record, active or lapsed. Lapsed members never get a trial pitch. */
    var hadPro by mutableStateOf(false); private set
    var resolved by mutableStateOf(false); private set
    var packages by mutableStateOf<List<Package>>(emptyList()); private set
    var error by mutableStateOf<String?>(null); private set
    var busy by mutableStateOf(false); private set
    private var configured = false
    private var testStore = false
    private var debugPro = false
    init {
        val key = BuildConfig.REVENUECAT_API_KEY
        if ((BuildConfig.DEBUG && key.startsWith("test_")) || (!BuildConfig.DEBUG && key.startsWith("goog_"))) {
            Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
            val builder = PurchasesConfiguration.Builder(context, key)
            // Test Store runs share one tester instead of a fresh anonymous customer
            // per install, so test runs don't inflate the live project's New and
            // Active Customers. Never with the Play key: real buyers would share one
            // identity.
            if (key.startsWith("test_")) builder.appUserID(QA_APP_USER_ID)
            Purchases.configure(builder.build())
            Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener(::apply)
            configured = true
            testStore = key.startsWith("test_")
        } else resolved = true
    }
    fun forceProForDebug(value: Boolean) { if (BuildConfig.DEBUG) { debugPro = value; isPro = value || reviewAccess.isGranted; resolved = true } }
    /**
     * The Play reviewer code. Unlocks Pro on this install only: no purchase is
     * recorded, and a customer-info refresh does not take it back.
     */
    fun activateReviewAccess(code: String): Boolean {
        if (!reviewAccess.activate(code)) return false
        isPro = true
        resolved = true
        return true
    }
    private fun apply(info: CustomerInfo) {
        isPro = debugPro || reviewAccess.isGranted || ENTITLEMENTS.any { info.entitlements.active[it]?.isActive == true }
        activation.entitlementUpdated(isPro)
        purchasePending = activation.pending
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
                .filter { it.product.id.substringBefore(":") in PRODUCTS || (testStore && it.product.id in TEST_STORE_PRODUCTS) }
            error = if (packages.isEmpty()) "Plans are temporarily unavailable. Please try again." else null
        } catch (e: CancellationException) { throw e } catch (_: Exception) { error = "Couldn't load plans. Check your connection and try again." }
        finally { busy = false }
    }
    suspend fun purchase(activity: Activity, pkg: Package): PurchaseOutcome {
        check(configured)
        if (purchasePending) return PurchaseOutcome.PENDING
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
            apply(result.customerInfo)
            activation.completed(isPro).also { purchasePending = activation.pending }
        } catch (e: PurchasesTransactionException) {
            when {
                e.userCancelled || e.code == PurchasesErrorCode.PurchaseCancelledError -> PurchaseOutcome.CANCELLED
                e.code == PurchasesErrorCode.PaymentPendingError -> activation.completed(false).also { purchasePending = activation.pending }
                else -> throw IllegalStateException("Couldn't complete the purchase. Please try again.")
            }
        }
    }
    suspend fun refreshPendingPurchase() {
        if (!configured || !purchasePending || refreshingPurchase) return
        refreshingPurchase = true
        try {
            repeat(3) { attempt ->
                if (!purchasePending) return
                if (attempt > 0) delay(1000)
                try { apply(Purchases.sharedInstance.awaitCustomerInfo(CacheFetchPolicy.FETCH_CURRENT)); error = null }
                catch (e: CancellationException) { throw e }
                catch (_: Exception) { error = "Couldn't refresh your subscription status. Check your connection and try again." }
            }
        } finally { refreshingPurchase = false }
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
        const val PENDING_MESSAGE = "Purchase pending. Pro isn't active yet. Refresh status or continue free while activation finishes."
        private const val QA_APP_USER_ID = "qa-android"
        val ENTITLEMENTS = listOf("GLP Pro", "SimpleGLPPro", "pro")
        /** RevenueCat Test Store product IDs; only accepted with a debug `test_` key. */
        val TEST_STORE_PRODUCTS = setOf("monthly", "yearly", "lifetime")
        val PRODUCTS = setOf("com.jackwallner.glp.pro.monthly", "com.jackwallner.glp.pro.yearly", "com.jackwallner.glp.pro.lifetime")
    }
}
