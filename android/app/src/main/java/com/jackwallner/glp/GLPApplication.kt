package com.jackwallner.glp

import android.app.Application
import android.content.Context
import com.jackwallner.glp.data.NotificationService
import com.jackwallner.glp.data.ReviewPrompts
import com.jackwallner.glp.data.StoreService
import com.jackwallner.glp.data.TrackerStore
import com.jackwallner.glp.data.TrialOffers

class AppGraph(context: Context) {
    val tracker = TrackerStore(context)
    val store = StoreService(context)
    val notifications = NotificationService(context)
    val reviews = ReviewPrompts(context.getSharedPreferences("reviews", Context.MODE_PRIVATE))
    val trialOffers = TrialOffers(context.getSharedPreferences("trialOffer", Context.MODE_PRIVATE))
    /** Per process, like the iOS session flags: one promo and one rating ask per session at most. */
    var promoShownThisSession = false
    var reviewShownThisSession = false
}
class GLPApplication : Application() {
    lateinit var graph: AppGraph; private set
    override fun onCreate() { super.onCreate(); graph = AppGraph(this) }
}
