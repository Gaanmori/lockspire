// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

package com.lockspire.lockspire

/** Un sitio de una cuenta, ya reducido por Dart a host + "exige https". */
data class AutofillSite(val host: String, val httpsOnly: Boolean)

/** Una cuenta que la sesión de autofill puede ofrecer directamente (ADR 0026). */
data class AutofillAccount(
    val title: String,
    val username: String,
    val password: String,
    val sites: List<AutofillSite>,
    val apps: List<String>,
)

/**
 * Qué cuentas de la sesión se ofrecen a quien pide rellenar (ADR 0026).
 * Sin nada de Android, para poder probarlo con JUnit.
 */
object AutofillMatcher {

    /**
     * Cuentas para una página web ([webDomain] no nulo, reglas de ADR
     * 0013/0020) o, si no hay página, para la app [packageName] exacta.
     *
     * El dominio lo declara la app que pide: un navegador lo informa con
     * honestidad, pero cualquier otra app puede declarar `banco.com` sobre
     * un formulario falso. Por eso una página web solo recibe cuentas
     * directas si quien pide es uno de los [trustedBrowsers] o una app que
     * el usuario guardó en esa misma entrada. En otra app (un WebView) se
     * sigue el flujo normal, que muestra "dentro de la app X" (ADR 0020).
     */
    fun match(
        accounts: List<AutofillAccount>,
        trustedBrowsers: Set<String>,
        packageName: String,
        webDomain: String?,
        webScheme: String?,
    ): List<AutofillAccount> {
        if (!webDomain.isNullOrBlank()) {
            val host = webDomain.lowercase().trimEnd('.')
            val isHttps = webScheme == null || webScheme.equals("https", ignoreCase = true)
            val fromBrowser = packageName in trustedBrowsers
            return accounts.filter { account ->
                (fromBrowser || packageName in account.apps) &&
                    account.sites.any { site ->
                        (!site.httpsOnly || isHttps) &&
                            (host == site.host || host.endsWith(".${site.host}"))
                    }
            }
        }
        if (packageName.isBlank()) return emptyList()
        return accounts.filter { packageName in it.apps }
    }

    /** Una cuenta tal como llega de Dart por el canal, o `null` si no es válida. */
    fun parseAccount(raw: Map<String, Any?>): AutofillAccount? {
        val password = raw["password"] as? String ?: return null
        val hosts = (raw["hosts"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
        val httpsOnly = (raw["httpsOnly"] as? List<*>)?.filterIsInstance<Boolean>() ?: emptyList()
        if (hosts.size != httpsOnly.size) return null
        return AutofillAccount(
            title = raw["title"] as? String ?: "",
            username = raw["username"] as? String ?: "",
            password = password,
            sites = hosts.zip(httpsOnly) { host, https -> AutofillSite(host, https) },
            apps = (raw["apps"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
        )
    }
}
