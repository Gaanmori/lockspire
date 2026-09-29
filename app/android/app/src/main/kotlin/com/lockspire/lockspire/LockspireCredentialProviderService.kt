// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

package com.lockspire.lockspire

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.os.OutcomeReceiver
import androidx.annotation.RequiresApi
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.provider.AuthenticationAction
import androidx.credentials.provider.BeginCreateCredentialRequest
import androidx.credentials.provider.BeginCreateCredentialResponse
import androidx.credentials.provider.BeginCreatePasswordCredentialRequest
import androidx.credentials.provider.BeginGetCredentialRequest
import androidx.credentials.provider.BeginGetCredentialResponse
import androidx.credentials.provider.BeginGetPasswordOption
import androidx.credentials.provider.CreateEntry
import androidx.credentials.provider.CredentialProviderService
import androidx.credentials.provider.ProviderClearCredentialStateRequest
import kotlin.random.Random

/**
 * Servicio de Credential Manager (ADR 0011) — deliberadamente delgado,
 * nunca lee ni desencripta la bóveda (mismo principio que
 * `native-host` en ADR 0005: no duplicar el motor criptográfico). Solo
 * arma `PendingIntent`s hacia [AutofillActivity], respaldada por
 * Flutter, donde ocurre todo lo sensible (desbloqueo, matching,
 * guardado) reusando la infraestructura ya existente.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class LockspireCredentialProviderService : CredentialProviderService() {

    override fun onBeginGetCredentialRequest(
        request: BeginGetCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginGetCredentialResponse, GetCredentialException>,
    ) {
        // Si el pedido no incluye ninguna opción de tipo contraseña (ej.
        // Sign in with Google, u otro tipo de credencial que no
        // manejamos), no hay nada que Lockspire pueda ofrecer acá —
        // devolver una respuesta vacía evita aparecer como opción
        // confusa en flujos que no tienen nada que ver con la bóveda.
        // Bug real encontrado en verificación manual: sin este chequeo,
        // Lockspire aparecía incluso en el selector de "Iniciar sesión
        // con Google" de apps de terceros.
        val hasPasswordOption = request.beginGetCredentialOptions.any {
            it is BeginGetPasswordOption
        }
        if (!hasPasswordOption) {
            callback.onResult(BeginGetCredentialResponse(authenticationActions = emptyList()))
            return
        }

        val packageName = request.callingAppInfo?.packageName ?: ""
        val authenticationAction = AuthenticationAction(
            title = "Desbloquear Lockspire",
            pendingIntent = createAutofillPendingIntent(
                action = ACTION_GET,
                packageName = packageName,
            ),
        )
        callback.onResult(
            BeginGetCredentialResponse(
                authenticationActions = listOf(authenticationAction),
            ),
        )
    }

    override fun onBeginCreateCredentialRequest(
        request: BeginCreateCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginCreateCredentialResponse, CreateCredentialException>,
    ) {
        if (request !is BeginCreatePasswordCredentialRequest) {
            callback.onResult(BeginCreateCredentialResponse.Builder().build())
            return
        }
        val packageName = request.callingAppInfo?.packageName ?: ""
        val createEntry = CreateEntry
            .Builder(
                accountName = "Lockspire",
                pendingIntent = createAutofillPendingIntent(
                    action = ACTION_CREATE,
                    packageName = packageName,
                ),
            )
            .build()
        callback.onResult(
            BeginCreateCredentialResponse.Builder()
                .setCreateEntries(listOf(createEntry))
                .build(),
        )
    }

    // Lockspire no mantiene ningún estado de "sesión" a nivel de Credential
    // Manager fuera de la bóveda misma — no hay nada que limpiar acá.
    override fun onClearCredentialStateRequest(
        request: ProviderClearCredentialStateRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<Void?, ClearCredentialException>,
    ) {
        callback.onResult(null)
    }

    private fun createAutofillPendingIntent(
        action: String,
        packageName: String,
    ): PendingIntent {
        val intent = Intent(action)
            .setPackage(this.packageName)
            .setClass(this, AutofillActivity::class.java)
            .putExtra(EXTRA_REQUESTING_PACKAGE, packageName)
        return PendingIntent.getActivity(
            this,
            Random.nextInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    companion object {
        const val ACTION_GET = "com.lockspire.lockspire.credentials.ACTION_GET"
        const val ACTION_CREATE = "com.lockspire.lockspire.credentials.ACTION_CREATE"
        const val EXTRA_REQUESTING_PACKAGE = "requesting_package"
    }
}
