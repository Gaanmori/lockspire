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

    data class Site(val host: String, val httpsOnly: Boolean)

    data class Account(
        val title: String,
        val username: String,
        val password: String,
        val sites: List<Site>,
        val apps: List<String>,
    )

    @Volatile private var accounts: List<Account> = emptyList()
    @Volatile private var expiresAt: Long = 0L
    private var screenOffReceiver: BroadcastReceiver? = null

    @Synchronized
    fun start(context: Context, items: List<Map<String, Any?>>, ttlMillis: Long) {
        accounts = items.mapNotNull(::parseAccount)
        expiresAt = SystemClock.elapsedRealtime() + ttlMillis
        registerScreenOff(context.applicationContext)
    }

    @Synchronized
    fun clear(context: Context? = null) {
        accounts = emptyList()
        expiresAt = 0L
        val receiver = screenOffReceiver ?: return
        screenOffReceiver = null
        try {
            (context?.applicationContext)?.unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
            // Ya no estaba registrado.
        }
    }

    /**
     * Cuentas para una página web ([webDomain] no nulo, reglas de ADR
     * 0013/0020) o, si no hay página, para la app [packageName] exacta.
     */
    fun matching(
        context: Context,
        packageName: String,
        webDomain: String?,
        webScheme: String?,
    ): List<Account> {
        if (SystemClock.elapsedRealtime() >= expiresAt) {
            if (accounts.isNotEmpty()) clear(context)
            return emptyList()
        }
        val current = accounts
        if (!webDomain.isNullOrBlank()) {
            val host = webDomain.lowercase().trimEnd('.')
            val isHttps = webScheme == null || webScheme.equals("https", ignoreCase = true)
            return current.filter { account ->
                account.sites.any { site ->
                    (!site.httpsOnly || isHttps) &&
                        (host == site.host || host.endsWith(".${site.host}"))
                }
            }
        }
        if (packageName.isBlank()) return emptyList()
        return current.filter { packageName in it.apps }
    }

    private fun parseAccount(raw: Map<String, Any?>): Account? {
        val password = raw["password"] as? String ?: return null
        val hosts = (raw["hosts"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
        val httpsOnly = (raw["httpsOnly"] as? List<*>)?.filterIsInstance<Boolean>() ?: emptyList()
        if (hosts.size != httpsOnly.size) return null
        return Account(
            title = raw["title"] as? String ?: "",
            username = raw["username"] as? String ?: "",
            password = password,
            sites = hosts.zip(httpsOnly) { host, https -> Site(host, https) },
            apps = (raw["apps"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
        )
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
