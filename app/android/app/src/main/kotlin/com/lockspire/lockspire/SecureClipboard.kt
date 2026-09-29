// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

package com.lockspire.lockspire

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

// Etiqueta con la que se reconoce una copia propia al borrarla.
private const val CLIP_LABEL = "Lockspire"

// Valor literal de ClipDescription.EXTRA_IS_SENSITIVE (API 33). Android
// recomienda ponerlo también en versiones anteriores, donde lo leen
// algunos teclados y fabricantes.
private const val EXTRA_IS_SENSITIVE_COMPAT = "android.content.extra.IS_SENSITIVE"

// Un solo borrado pendiente: cada copia nueva reemplaza al anterior.
private const val CLEAR_WORK_NAME = "lockspire-clipboard-clear"

/**
 * Portapapeles para secretos (revisión 2026-09-25, hallazgo S4). Ver
 * lib/features/clipboard/infrastructure/android_secure_clipboard_adapter.dart.
 *
 * - `copySensitive({text, clearAfterMs})`: copia marcado como sensible, así
 *   Android 13+ no lo muestra en la vista previa, y programa el borrado con
 *   WorkManager. Android congela las apps en segundo plano (Android 14+ a
 *   los pocos segundos), así que un temporizador dentro de la app no corre
 *   justo cuando el usuario salió a pegar; WorkManager lo ejecuta el
 *   sistema aunque la app esté congelada o cerrada.
 * - `clearIfOurs()`: borra ya y cancela el borrado programado.
 */
fun registerSecureClipboardChannel(context: Context, messenger: BinaryMessenger) {
    val appContext = context.applicationContext
    val clipboard = appContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    MethodChannel(messenger, "com.lockspire.lockspire/clipboard")
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "copySensitive" -> {
                    val text = call.argument<String>("text")
                    val clearAfterMs = call.argument<Number>("clearAfterMs")?.toLong()
                    if (text == null || clearAfterMs == null) {
                        result.error("BAD_ARGS", "Faltan el texto o el plazo", null)
                        return@setMethodCallHandler
                    }
                    val clip = ClipData.newPlainText(CLIP_LABEL, text)
                    clip.description.extras = PersistableBundle().apply {
                        putBoolean(EXTRA_IS_SENSITIVE_COMPAT, true)
                    }
                    clipboard.setPrimaryClip(clip)
                    scheduleClear(appContext, clearAfterMs)
                    result.success(null)
                }
                "clearIfOurs" -> {
                    WorkManager.getInstance(appContext).cancelUniqueWork(CLEAR_WORK_NAME)
                    result.success(clearIfOurs(clipboard))
                }
                else -> result.notImplemented()
            }
        }
}

private fun scheduleClear(context: Context, delayMs: Long) {
    val request = OneTimeWorkRequestBuilder<ClearClipboardWorker>()
        .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
        .build()
    WorkManager.getInstance(context)
        .enqueueUniqueWork(CLEAR_WORK_NAME, ExistingWorkPolicy.REPLACE, request)
}

/** Lo ejecuta WorkManager al vencer el plazo, con o sin la app viva. */
class ClearClipboardWorker(context: Context, params: WorkerParameters) :
    Worker(context, params) {
    override fun doWork(): Result {
        val clipboard =
            applicationContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clearIfOurs(clipboard)
        return Result.success()
    }
}

private fun clearIfOurs(clipboard: ClipboardManager): Boolean {
    // Sin foco (app en segundo plano), Android 10+ no deja leer la
    // descripción y devuelve null. Ante la duda se borra: es preferible
    // perder una copia ajena que dejar una contraseña.
    val description: ClipDescription? = clipboard.primaryClipDescription
    if (description != null && description.label != CLIP_LABEL) return false
    // Android estándar permite borrar sin foco. HyperOS (Xiaomi) descarta en
    // silencio cualquier escritura desde segundo plano, incluso reemplazar
    // por vacío (verificado en un Redmi con Android 16): ahí el borrado
    // efectivo es el reintento al volver a la app (ClipboardGuard.onResumed).
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        clipboard.clearPrimaryClip()
    } else {
        clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
    }
    return true
}
