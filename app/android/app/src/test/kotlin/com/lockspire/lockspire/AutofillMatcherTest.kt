// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

package com.lockspire.lockspire

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Reglas de la sesión de autofill (ADR 0026, revisión 2026-09-28 S14). */
class AutofillMatcherTest {

    private val chrome = "com.android.chrome"
    private val browsers = setOf(chrome)

    private val bank = AutofillAccount(
        title = "Banco",
        username = "u",
        password = "p",
        sites = listOf(AutofillSite("banco.test", httpsOnly = true)),
        apps = listOf("com.banco.app"),
    )
    private val oldHttp = AutofillAccount(
        title = "Viejo",
        username = "u",
        password = "p",
        sites = listOf(AutofillSite("viejo.test", httpsOnly = false)),
        apps = emptyList(),
    )
    private val accounts = listOf(bank, oldHttp)

    private fun titles(
        packageName: String,
        webDomain: String? = null,
        webScheme: String? = "https",
    ) = AutofillMatcher.match(accounts, browsers, packageName, webDomain, webScheme)
        .map { it.title }

    @Test
    fun `navegador de confianza en el sitio y en un subdominio`() {
        assertEquals(listOf("Banco"), titles(chrome, "banco.test"))
        assertEquals(listOf("Banco"), titles(chrome, "login.BANCO.test."))
    }

    @Test
    fun `nunca un dominio parecido`() {
        assertTrue(titles(chrome, "banco.test.evil.test").isEmpty())
        assertTrue(titles(chrome, "falsobanco.test").isEmpty())
    }

    @Test
    fun `una app cualquiera que declara el dominio del banco no recibe nada`() {
        assertTrue(titles("com.malicioso.app", "banco.test").isEmpty())
    }

    @Test
    fun `la app guardada en la entrada si recibe la cuenta en su WebView`() {
        assertEquals(listOf("Banco"), titles("com.banco.app", "banco.test"))
    }

    @Test
    fun `una entrada https nunca en una pagina http`() {
        assertTrue(titles(chrome, "banco.test", webScheme = "http").isEmpty())
        assertEquals(listOf("Viejo"), titles(chrome, "viejo.test", webScheme = "http"))
    }

    @Test
    fun `app nativa sin pagina web por paquete exacto`() {
        assertEquals(listOf("Banco"), titles("com.banco.app"))
        assertTrue(titles("com.banco.app.falsa").isEmpty())
        assertTrue(titles("").isEmpty())
    }

    @Test
    fun `parseAccount acepta lo que envia Dart y rechaza listas desparejas`() {
        val ok = AutofillMatcher.parseAccount(
            mapOf(
                "title" to "T",
                "username" to "u",
                "password" to "p",
                "hosts" to listOf("a.test"),
                "httpsOnly" to listOf(true),
                "apps" to listOf("com.a"),
            ),
        )
        assertEquals(listOf(AutofillSite("a.test", true)), ok?.sites)
        assertNull(
            AutofillMatcher.parseAccount(
                mapOf("password" to "p", "hosts" to listOf("a.test"), "httpsOnly" to emptyList<Boolean>()),
            ),
        )
        assertNull(AutofillMatcher.parseAccount(mapOf("title" to "sin contraseña")))
    }
}
