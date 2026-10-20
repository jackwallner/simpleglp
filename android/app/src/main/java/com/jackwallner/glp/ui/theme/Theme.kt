package com.jackwallner.glp.ui.theme

import android.app.Activity
import androidx.core.view.WindowCompat
import androidx.compose.ui.platform.LocalView
import androidx.compose.runtime.SideEffect
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Brand = Color(0xFF2FBF71)
private val Light = lightColorScheme(primary = Color(0xFF217F4A), onPrimary = Color.White, primaryContainer = Color(0xFFD8EFDE), secondary = Color(0xFF217F4A), secondaryContainer = Color(0xFFD8EFDE), onSecondaryContainer = Color(0xFF173D26), surfaceContainer = Color(0xFFEAF0E7), surfaceContainerLowest = Color(0xFFFDFCF7), surfaceContainerLow = Color(0xFFF3F5F1), surfaceContainerHigh = Color(0xFFE4E9DF), surfaceContainerHighest = Color(0xFFDDE3D8), background = Color(0xFFF3F5F1), surface = Color(0xFFFDFCF7), surfaceVariant = Color(0xFFE4E9DF), onSurface = Color(0xFF1A1A1A), onSurfaceVariant = Color(0xFF606459), outline = Color(0xFFD8D8D1))
private val Dark = darkColorScheme(primary = Brand, onPrimary = Color(0xFF092B17), primaryContainer = Color(0xFF1C3A28), secondary = Brand, secondaryContainer = Color(0xFF1C3A28), onSecondaryContainer = Color(0xFFD8EFDE), surfaceContainer = Color(0xFF1C211C), surfaceContainerLowest = Color(0xFF121311), surfaceContainerLow = Color(0xFF181A17), surfaceContainerHigh = Color(0xFF2A2D28), surfaceContainerHighest = Color(0xFF30332D), background = Color(0xFF121311), surface = Color(0xFF232421), surfaceVariant = Color(0xFF30332D), onSurface = Color(0xFFF2F4EF), onSurfaceVariant = Color(0xFFA3A59D), outline = Color(0xFF484844))
@Composable fun GLPTheme(appearance: String, content: @Composable () -> Unit) {
    val dark = appearance == "dark" || appearance == "system" && isSystemInDarkTheme()
    val view = LocalView.current
    SideEffect {
        (view.context as? Activity)?.window?.let { window ->
            val controller = WindowCompat.getInsetsController(window, view)
            controller.isAppearanceLightStatusBars = !dark
            controller.isAppearanceLightNavigationBars = !dark
        }
    }
    MaterialTheme(colorScheme = if (dark) Dark else Light, content = content)
}
