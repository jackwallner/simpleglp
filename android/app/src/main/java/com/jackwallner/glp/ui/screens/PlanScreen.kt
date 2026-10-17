package com.jackwallner.glp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import com.jackwallner.glp.model.*
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

@Composable fun PlanScreen(existing: Plan?, onSave: (Plan) -> Unit) {
    var form by remember { mutableStateOf(existing?.form ?: DoseForm.INJECTION) }
    var medication by remember { mutableStateOf(existing?.medication ?: Medication.OZEMPIC) }
    var custom by remember { mutableStateOf(existing?.customName ?: "") }
    var dose by remember { mutableStateOf(mg(existing?.doseMg ?: 0.25)) }
    var start by remember { mutableStateOf(existing?.start ?: LocalDate.now()) }
    var time by remember { mutableStateOf(existing?.time ?: LocalTime.of(9, 0)) }
    var interval by remember { mutableStateOf((existing?.intervalDays ?: 7).toString()) }
    var wait by remember { mutableStateOf((existing?.waitMinutes ?: 0).toString()) }
    var reminder by remember { mutableStateOf(existing?.reminderEnabled ?: true) }
    var lead by remember { mutableStateOf(existing?.reminderLeadMinutes ?: 0) }
    var steps by remember { mutableStateOf(existing?.steps.orEmpty()) }
    var stepDate by remember { mutableStateOf(LocalDate.now().plusDays(7)) }
    var stepDose by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    Page(if (existing == null) "Simple GLP" else "Medication & schedule") {
        if (existing == null) {
            Text("One tap. Logged.", style = MaterialTheme.typography.headlineMedium)
            Text("On a pill, the same tap starts your wait-before-eating countdown. Reminders, history, and a streak are there if you want them.")
        }
        Panel("Your medication") {
            Choice("How do you take it?", form, DoseForm.entries, { if (it == DoseForm.PILL) "Daily pill" else "Shot" }) { value ->
                form = value; medication = Medication.entries.first { it.form == value }; dose = mg(medication.doses.first()); interval = value.interval.toString(); time = LocalTime.of(value.hour, 0); wait = medication.wait.toString()
            }
            Choice("Medication", medication, Medication.entries.filter { it.form == form }, { it.label }) {
                medication = it; dose = mg(it.doses.firstOrNull() ?: 0.0); wait = it.wait.toString()
            }
            if (medication.custom) OutlinedTextField(custom, { custom = it }, Modifier.fillMaxWidth(), label = { Text("Medication name") })
            if (medication.doses.isNotEmpty()) Choice("Current dose", dose, (medication.doses.map(::mg) + dose).distinct(), { "$it mg" }) { dose = it }
            OutlinedTextField(dose, { dose = it }, Modifier.fillMaxWidth(), label = { Text("Current dose (mg)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
            Text("Set this to match your prescriber's instructions. Simple GLP records your plan and never recommends a dose.", style = MaterialTheme.typography.bodySmall)
        }
        Panel("Your schedule") {
            DateRow("First dose", start) { start = it }
            TimeRow("Planned time", time) { time = it }
            if (form == DoseForm.INJECTION) OutlinedTextField(interval, { interval = it }, Modifier.fillMaxWidth(), label = { Text("Repeat every (days)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
            else Text("Every day")
            if (form == DoseForm.PILL) {
                OutlinedTextField(wait, { wait = it }, Modifier.fillMaxWidth(), label = { Text("Wait before eating (minutes)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
                Text("Your own setting. Follow the instructions for your medication. Set 0 for no countdown.", style = MaterialTheme.typography.bodySmall)
            }
            Toggle("Dose reminders", reminder) { reminder = it }
            if (reminder) Choice("Lead time", lead, listOf(0, 15, 30, 60, 120), { if (it == 0) "At planned time" else "$it min before" }) { lead = it }
            Text("Android may deliver reminders a little late to save battery. Allow notifications when asked.", style = MaterialTheme.typography.bodySmall)
        }
        if (existing != null) Panel("Dose schedule") {
            Text("Record dose changes already agreed with your prescriber.")
            steps.sortedBy { it.start }.forEach { step ->
                Text("${display(step.start)} · ${mg(step.doseMg)} mg")
                RowAction("Remove change") { steps = steps - step }
            }
            DateRow("Change date", stepDate) { stepDate = it }
            OutlinedTextField(stepDose, { stepDose = it }, Modifier.fillMaxWidth(), label = { Text("Dose (mg)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
            RowAction("Add dose change") {
                val amount = stepDose.toDoubleOrNull()
                if (amount != null && amount.isFinite() && amount > 0) { steps = steps + DoseStep(stepDate.atTime(time).atZone(ZoneId.systemDefault()).toInstant(), amount); stepDose = "" }
                else error = "Enter a dose greater than zero."
            }
        }
        Text("Tracking only. Simple GLP isn't medical advice and doesn't diagnose or treat any condition.", style = MaterialTheme.typography.bodySmall)
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        Action(if (existing == null) "Start tracking" else "Save plan") {
            val amount = dose.toDoubleOrNull(); val cadence = if (form == DoseForm.PILL) 1 else interval.toIntOrNull(); val minutes = wait.toIntOrNull()
            when {
                amount == null || !amount.isFinite() || amount <= 0 -> error = "Enter a dose greater than zero."
                cadence == null || cadence !in 1..365 -> error = "Enter an interval from 1 to 365 days."
                form == DoseForm.PILL && (minutes == null || minutes !in 0..240) -> error = "Enter a wait from 0 to 240 minutes."
                medication.custom && custom.isBlank() -> error = "Enter your medication name."
                else -> onSave((existing ?: Plan()).copy(medication = medication, customName = custom.trim(), doseMg = amount,
                    start = if (cadence == 1) minOf(start, LocalDate.now()) else start, time = time, intervalDays = cadence,
                    waitMinutes = if (form == DoseForm.PILL) minutes ?: 0 else 0, reminderEnabled = reminder, reminderLeadMinutes = lead, steps = steps))
            }
        }
    }
}
