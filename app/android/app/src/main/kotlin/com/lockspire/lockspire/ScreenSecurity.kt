// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

package com.lockspire.lockspire

import android.app.Activity
import android.view.WindowManager

/**
 * Impide capturas de pantalla, grabaciones y que el contenido aparezca en
 * la miniatura de "apps recientes" (revisión 2026-09-25, hallazgo S5).
 * Se aplica a toda Activity que pueda mostrar la bóveda desbloqueada.
 */
fun Activity.protectFromScreenCapture() {
    window.setFlags(
        WindowManager.LayoutParams.FLAG_SECURE,
        WindowManager.LayoutParams.FLAG_SECURE,
    )
}
