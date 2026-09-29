// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

package com.lockspire.lockspire

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Ícono de una app instalada como PNG (ADR 0029), para mostrarlo junto a
 * las entradas que la tienen guardada. Local, sin red. Solo ve apps con
 * ícono en el lanzador (`<queries>` del manifiesto), no todas.
 */
fun registerAppIconsChannel(context: Context, messenger: BinaryMessenger) {
    MethodChannel(messenger, "com.lockspire.lockspire/app_icons")
        .setMethodCallHandler { call, result ->
            if (call.method != "getAppIcon") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val pkg = call.argument<String>("package")
            if (pkg.isNullOrBlank()) {
                result.success(null)
                return@setMethodCallHandler
            }
            try {
                val drawable = context.packageManager.getApplicationIcon(pkg)
                val size = 96
                val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                drawable.setBounds(0, 0, size, size)
                drawable.draw(Canvas(bitmap))
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                bitmap.recycle()
                result.success(out.toByteArray())
            } catch (_: PackageManager.NameNotFoundException) {
                result.success(null)
            }
        }
}
