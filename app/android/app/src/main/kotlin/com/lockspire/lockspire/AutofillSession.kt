// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

package com.lockspire.lockspire

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.SystemClock

/**
 * Cuentas que [LockspireAutofillService] puede ofrecer directamente, sin
 * abrir Lockspire, durante el tiempo del auto-bloqueo tras desbloquear
 * para rellenar (ADR 0026). Solo en memoria: se borra al vencer, al
 * apagar la pantalla o al morir el proceso. Dart decide qué entra y ya
 * reduce cada sitio a host + "exige https"; aquí solo se compara.
 */
object AutofillSession {

    @Volatile private var accounts: List<AutofillAccount> = emptyList()
    @Volatile private var trustedBrowsers: Set<String> = emptySet()
    @Volatile private var expiresAt: Long = 0L
    private var screenOffReceiver: BroadcastReceiver? = null

    @Synchronized
    fun start(
        context: Context,
        items: List<Map<String, Any?>>,
        browsers: List<String>,
        ttlMillis: Long,
    ) {
        accounts = items.mapNotNull(AutofillMatcher::parseAccount)
        trustedBrowsers = browsers.toSet()
        expiresAt = SystemClock.elapsedRealtime() + ttlMillis
        registerScreenOff(context.applicationContext)
    }

    @Synchronized
    fun clear(context: Context? = null) {
        accounts = emptyList()
        trustedBrowsers = emptySet()
        expiresAt = 0L
        val receiver = screenOffReceiver ?: return
        screenOffReceiver = null
        try {
            (context?.applicationContext)?.unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
            // Ya no estaba registrado.
        }
    }

    /** Ver [AutofillMatcher.match]; vacío si la sesión venció. */
    fun matching(
        context: Context,
        packageName: String,
        webDomain: String?,
        webScheme: String?,
    ): List<AutofillAccount> {
        if (SystemClock.elapsedRealtime() >= expiresAt) {
            if (accounts.isNotEmpty()) clear(context)
            return emptyList()
        }
        return AutofillMatcher.match(accounts, trustedBrowsers, packageName, webDomain, webScheme)
    }

    private fun registerScreenOff(appContext: Context) {
        if (screenOffReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                clear(context)
            }
        }
        appContext.registerReceiver(receiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
        screenOffReceiver = receiver
    }
}
