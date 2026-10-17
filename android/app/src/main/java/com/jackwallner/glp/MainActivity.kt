package com.jackwallner.glp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import com.jackwallner.glp.ui.screens.RootScreen
import com.jackwallner.glp.ui.theme.GLPTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val graph get() = (application as GLPApplication).graph
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState); enableEdgeToEdge()
        if (savedInstanceState == null) DebugLaunchOptions.apply(intent, graph)
        val prefs = getSharedPreferences("reviews", MODE_PRIVATE)
        prefs.edit().putInt("launches", prefs.getInt("launches", 0) + 1).apply()
        lifecycleScope.launch { graph.store.refresh(); graph.notifications.sync(graph.tracker, graph.store.isPro, graph.store.resolved) }
        setContent { GLPTheme(graph.tracker.appearance) { RootScreen(graph, this, DebugLaunchOptions.automation(intent)) } }
    }
}
