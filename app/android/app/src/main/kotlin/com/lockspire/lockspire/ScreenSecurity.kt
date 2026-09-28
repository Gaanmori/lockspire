// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

package com.lockspire.lockspire

import android.app.Activity
import android.content.pm.ApplicationInfo
import android.view.WindowManager

/**
 * Impide capturas de pantalla, grabaciones y que el contenido aparezca en
 * la miniatura de "apps recientes" (revisión 2026-09-25, hallazgo S5).
 * Se aplica a toda Activity que pueda mostrar la bóveda desbloqueada.
 *
 * **Solo en builds de release** (pedido del usuario, 2026-09-28): los builds
 * de desarrollo son depurables y permiten capturas para poder reportar y
 * revisar la interfaz. La condición es la marca `debuggable` del propio APK,
 * que ningún build publicado (F-Droid, release firmado) tiene; así la
 * protección no depende de acordarse de volver a activarla antes de lanzar.
 */
fun Activity.protectFromScreenCapture() {
    val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    if (debuggable) return
    window.setFlags(
        WindowManager.LayoutParams.FLAG_SECURE,
        WindowManager.LayoutParams.FLAG_SECURE,
    )
}
