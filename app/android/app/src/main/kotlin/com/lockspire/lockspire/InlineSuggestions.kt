// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

package com.lockspire.lockspire

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.autofill.FillRequest
import android.service.autofill.InlinePresentation
import android.view.inputmethod.InlineSuggestionsRequest
import androidx.autofill.inline.UiVersions
import androidx.autofill.inline.v1.InlineSuggestionUi

/**
 * Sugerencias en la barra del teclado (Android 11+), si el teclado las
 * pide. Sin eso, [presentation] devuelve `null` y queda solo el
 * desplegable de siempre (ADR 0026).
 */
class InlineSuggestions(private val context: Context, fillRequest: FillRequest) {

    private val request: InlineSuggestionsRequest? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            fillRequest.inlineSuggestionsRequest
        } else {
            null
        }

    fun presentation(index: Int, title: String, subtitle: String?): InlinePresentation? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val request = request ?: return null
        if (index >= request.maxSuggestionCount) return null
        val specs = request.inlinePresentationSpecs
        if (specs.isEmpty()) return null
        val spec = specs[minOf(index, specs.size - 1)]
        if (!UiVersions.getVersions(spec.style).contains(UiVersions.INLINE_UI_VERSION_1)) {
            return null
        }
        // El sistema exige un PendingIntent de "atribución" (pulsación larga
        // sobre la sugerencia): abre Lockspire.
        val attribution = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val content = InlineSuggestionUi.newContentBuilder(attribution)
            .setTitle(title)
            .setContentDescription(title)
            .setStartIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
            .apply { if (!subtitle.isNullOrEmpty()) setSubtitle(subtitle) }
            .build()
        return InlinePresentation(content.slice, spec, false)
    }
}
