// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

package com.lockspire.lockspire

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Lleva a Dart la redirección OAuth `com.lockspire.lockspire://oauth2redirect`
 * (ADR 0022). Si la redirección llega antes de que Dart escuche, la guarda.
 */
private object OAuthRedirectRelay {
    private var listener: ((String) -> Unit)? = null
    private var pending: String? = null

    fun deliver(uri: String) {
        val current = listener
        if (current != null) current(uri) else pending = uri
    }

    fun attach(onRedirect: (String) -> Unit) {
        listener = onRedirect
        pending?.let {
            pending = null
            onRedirect(it)
        }
    }
}

/**
 * Recibe la redirección del navegador al terminar el login de OneDrive en
 * Android (ADR 0022). No muestra nada: pasa la URI a Dart y trae Lockspire
 * al frente.
 *
 * Existe porque el login por loopback (`http://localhost`) no funciona en
 * HyperOS: el sistema congela la app mientras el usuario está en el
 * navegador y nadie atiende la redirección. Lanzar esta actividad descongela
 * el proceso.
 *
 * Es exportada (la abre el navegador), así que cualquier app podría llamarla
 * con una URI inventada: Dart la descarta si el `state` no coincide con el
 * del login en curso, y el código no sirve sin el verificador PKCE.
 */
class OAuthRedirectActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.data?.let { OAuthRedirectRelay.deliver(it.toString()) }
        // Trae al frente la tarea existente de Lockspire, igual que tocar el
        // ícono (no crea otra instancia de MainActivity).
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(it)
        }
        finish()
    }
}

fun registerOAuthRedirectChannel(messenger: BinaryMessenger) {
    val channel = MethodChannel(messenger, "com.lockspire.lockspire/oauth_redirect")
    OAuthRedirectRelay.attach { uri -> channel.invokeMethod("redirect", uri) }
}
