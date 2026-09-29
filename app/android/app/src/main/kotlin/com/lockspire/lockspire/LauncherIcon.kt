// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

package com.lockspire.lockspire

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Tema → alias del manifiesto con su ícono (ADR 0031). */
private val launcherAliases = mapOf(
    "lineage" to ".LauncherLineage",
    "pixel" to ".LauncherPixel",
    "ubuntu" to ".LauncherUbuntu",
    "mint" to ".LauncherMint",
    "windows" to ".LauncherWindows",
)

/**
 * Deja activo solo el alias del lanzador del tema elegido, para que el
 * ícono de Lockspire en el lanzador siga al tema (ADR 0031). Un tema sin
 * ícono propio ("Colores del sistema") usa el de Lineage. Si ya está
 * activo no toca nada: cambiar componentes hace que algunos lanzadores
 * quiten el acceso directo.
 */
fun registerLauncherIconChannel(context: Context, messenger: BinaryMessenger) {
    MethodChannel(messenger, "com.lockspire.lockspire/launcher_icon")
        .setMethodCallHandler { call, result ->
            if (call.method != "setTheme") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val theme = call.argument<String>("theme") ?: "lineage"
            val wanted = launcherAliases[theme] ?: launcherAliases.getValue("lineage")
            val pm = context.packageManager
            fun component(alias: String) = ComponentName(context.packageName, context.packageName + alias)
            fun isEnabled(alias: String): Boolean =
                when (pm.getComponentEnabledSetting(component(alias))) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
                    // Por defecto: lo que dice el manifiesto (solo Lineage).
                    else -> alias == ".LauncherLineage"
                }
            val active = launcherAliases.values.filter(::isEnabled)
            if (active == listOf(wanted)) {
                result.success(false)
                return@setMethodCallHandler
            }
            // Primero se activa el nuevo y después se apagan los demás: nunca
            // queda la app sin ícono en el lanzador.
            pm.setComponentEnabledSetting(
                component(wanted),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            for (alias in launcherAliases.values) {
                if (alias == wanted) continue
                pm.setComponentEnabledSetting(
                    component(alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
            result.success(true)
        }
}
