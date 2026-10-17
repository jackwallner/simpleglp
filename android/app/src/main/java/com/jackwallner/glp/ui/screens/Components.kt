package com.jackwallner.glp.ui.screens

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

fun display(at: Instant): String = DateTimeFormatter.ofPattern("EEE, MMM d · h:mm a").withZone(ZoneId.systemDefault()).format(at)
fun mg(value: Double): String = if (value == value.toLong().toDouble()) value.toLong().toString() else value.toString()
@Composable fun Page(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(title, style = MaterialTheme.typography.headlineLarge)
        content(); Spacer(Modifier.height(12.dp))
    }
}
@Composable fun Panel(title: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (title != null) Text(title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}
@Composable fun Action(text: String, enabled: Boolean = true, onClick: () -> Unit) {
    Button(onClick, Modifier.fillMaxWidth().heightIn(min = 50.dp), enabled = enabled) { Text(text) }
}
@Composable fun RowAction(text: String, onClick: () -> Unit) {
    TextButton(onClick, Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(text, Modifier.fillMaxWidth()) }
}
@Composable fun Toggle(title: String, value: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text(title, Modifier.weight(1f).padding(top = 12.dp)); Switch(value, onChange) }
}
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun <T> Choice(label: String, value: T, options: List<T>, name: (T) -> String = { it.toString() }, change: (T) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded, { expanded = it }) {
        OutlinedTextField(name(value), {}, Modifier.fillMaxWidth().menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable), readOnly = true, label = { Text(label) }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) })
        ExposedDropdownMenu(expanded, { expanded = false }) { options.forEach { item -> DropdownMenuItem({ Text(name(item)) }, { change(item); expanded = false }) } }
    }
}
@Composable fun DateRow(label: String, value: LocalDate, change: (LocalDate) -> Unit) {
    val context = LocalContext.current
    OutlinedButton({ DatePickerDialog(context, { _, y, m, d -> change(LocalDate.of(y, m + 1, d)) }, value.year, value.monthValue - 1, value.dayOfMonth).show() }, Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text("$label: ${value.format(DateTimeFormatter.ofPattern("MMM d, yyyy"))}") }
}
@Composable fun TimeRow(label: String, value: LocalTime, change: (LocalTime) -> Unit) {
    val context = LocalContext.current
    OutlinedButton({ TimePickerDialog(context, { _, h, m -> change(LocalTime.of(h, m)) }, value.hour, value.minute, false).show() }, Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text("$label: ${value.format(DateTimeFormatter.ofPattern("h:mm a"))}") }
}
