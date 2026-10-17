package com.jackwallner.glp.ui.screens

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import com.jackwallner.glp.model.*
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

val Sites = listOf("Not recorded", "Abdomen", "Left thigh", "Right thigh", "Left arm", "Right arm", "Other")
@Composable fun LogScreen(plan: Plan, event: DoseEvent?, onSave: (Instant, Double, String, String, List<String>) -> Unit, onDelete: (() -> Unit)?) {
    val zone = ZoneId.systemDefault()
    val initial = event?.timestamp?.atZone(zone)
    var date by remember { mutableStateOf(initial?.toLocalDate() ?: LocalDate.now()) }
    var time by remember { mutableStateOf(initial?.toLocalTime()?.withSecond(0) ?: LocalTime.now().withSecond(0)) }
    var dose by remember { mutableStateOf(mg(event?.doseMg ?: plan.doseMg)) }
    var site by remember { mutableStateOf(event?.site?.takeIf(String::isNotBlank) ?: "Not recorded") }
    var notes by remember { mutableStateOf(event?.notes ?: "") }
    var context by remember { mutableStateOf(event?.context ?: List(17) { "" }) }
    var error by remember { mutableStateOf<String?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    Page(if (event == null) "Log earlier" else "Details") {
        Panel(plan.form.noun.replaceFirstChar(Char::uppercase)) {
            DateRow("When", date) { date = it }; TimeRow("Time taken", time) { time = it }
            OutlinedTextField(dose, { dose = it }, Modifier.fillMaxWidth(), label = { Text("Dose (mg)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
            if (plan.form == DoseForm.INJECTION) Choice("Injection site", site, Sites) { site = it }
            OutlinedTextField(notes, { notes = it }, Modifier.fillMaxWidth(), label = { Text("Notes") }, minLines = 3)
        }
        Panel("How do you feel?") {
            listOf("Nausea", "Appetite", "Food noise", "Wellbeing").forEachIndexed { index, title ->
                Choice(title, context.getOrElse(index) { "" }, listOf("") + (0..5).map(Int::toString), { it.ifBlank { "Not rated" } }) { value -> context = context.toMutableList().also { it[index] = value } }
            }
            Text("0 to 5. Leave any you don't want to rate.", style = MaterialTheme.typography.bodySmall)
        }
        Panel("That day") {
            if (context.drop(4).any(String::isNotBlank)) CsvLabels.forEachIndexed { index, label -> context.getOrNull(index + 4)?.takeIf(String::isNotBlank)?.let { Text("$label: $it") } }
            else Text("Health context unavailable. Android does not read Apple Health. Imported context is preserved with your log.")
        }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        Action("Save") {
            val at = date.atTime(time).atZone(zone).toInstant(); val amount = dose.toDoubleOrNull()
            when {
                at > Instant.now() -> error = "Choose the time you actually took this dose. Future doses can't be logged."
                amount == null || !amount.isFinite() || amount <= 0 -> error = "Enter a dose greater than zero."
                else -> onSave(at, amount, if (site == "Not recorded") "" else site, notes, context)
            }
        }
        if (onDelete != null) RowAction("Delete this ${plan.form.noun}") { confirmDelete = true }
    }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, title = { Text("Delete this entry?") }, text = { Text("This removes the dose and its details. It can't be undone.") }, confirmButton = { TextButton({ confirmDelete = false; onDelete?.invoke() }) { Text("Delete") } }, dismissButton = { TextButton({ confirmDelete = false }) { Text("Cancel") } })
}
val CsvLabels = listOf("Weight (kg)", "Glucose (mg/dL)", "Steps", "Active energy (kcal)", "Exercise (minutes)", "Sleep (hours)", "Resting heart rate", "Average heart rate", "Workouts", "Water (mL)", "Caffeine (mg)", "Energy (kcal)", "Protein (g)")
