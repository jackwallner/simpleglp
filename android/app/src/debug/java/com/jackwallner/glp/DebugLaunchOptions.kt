package com.jackwallner.glp

import android.content.Intent
import com.jackwallner.glp.model.*
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime

object DebugLaunchOptions {
    fun apply(intent: Intent, graph: AppGraph) {
        if (intent.getBooleanExtra("test_reset", false)) graph.tracker.clearAll()
        graph.store.forceProForDebug(intent.getBooleanExtra("test_pro", false))
        val pill = intent.getBooleanExtra("seed_pill", false)
        if (pill || intent.getBooleanExtra("seed_shot", false)) {
            graph.tracker.clearAll()
            graph.tracker.savePlan(Plan(medication = if (pill) Medication.WEGOVY_PILL else Medication.ZEPBOUND, doseMg = if (pill) 1.5 else 2.5,
                start = LocalDate.now().minusDays(28), time = LocalTime.of(if (pill) 7 else 9, 0), intervalDays = if (pill) 1 else 7, waitMinutes = if (pill) 30 else 0))
            (4 downTo 1).forEach { graph.tracker.log(Instant.now().minusSeconds(it * if (pill) 86400L else 7 * 86400L)) }
        }
        intent.getStringExtra("appearance")?.let(graph.tracker::updateAppearance)
    }
    fun automation(intent: Intent): Boolean = intent.getBooleanExtra("uitesting", false)
}
