package com.jackwallner.glp

import android.app.Application
import android.content.Context
import com.jackwallner.glp.data.NotificationService
import com.jackwallner.glp.data.StoreService
import com.jackwallner.glp.data.TrackerStore

class AppGraph(context: Context) {
    val tracker = TrackerStore(context)
    val store = StoreService(context)
    val notifications = NotificationService(context)
}
class GLPApplication : Application() {
    lateinit var graph: AppGraph; private set
    override fun onCreate() { super.onCreate(); graph = AppGraph(this) }
}
