// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

package com.lockspire.lockspire

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import androidx.annotation.RequiresApi
import androidx.credentials.CreatePasswordRequest
import androidx.credentials.CreatePasswordResponse
import androidx.credentials.Credential
import androidx.credentials.GetCredentialResponse
import androidx.credentials.PasswordCredential
import androidx.credentials.provider.PendingIntentHandler
import androidx.credentials.provider.ProviderCreateCredentialRequest
import androidx.credentials.provider.ProviderGetCredentialRequest
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity respaldada por Flutter, destino del `PendingIntent`/`Intent`
 * que arman [LockspireCredentialProviderService] (Credential Manager) y
 * [LockspireAutofillService] (Autofill legado, necesario para WebViews —
 * ver ADR 0011). No exportada (ver `AndroidManifest.xml`) — solo la
 * pueden lanzar esos dos servicios, nunca un intent externo directo.
 * Todo lo sensible (desbloqueo, matching de entradas, guardado) ocurre
 * del lado Dart, reusando la infraestructura ya existente — esta clase
 * solo traduce entre las dos APIs nativas de Android y un `MethodChannel`
 * simple, agnóstico de cuál de las dos la lanzó.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class AutofillActivity : FlutterFragmentActivity() {

    private var getRequest: ProviderGetCredentialRequest? = null
    private var createRequest: ProviderCreateCredentialRequest? = null

    // Origen "Autofill legado" — ver LockspireAutofillService. Si
    // legacyUsernameId/legacyPasswordId no son null, vinimos de ahí en
    // modo "get"; si legacySaveUsername/legacySavePassword no son null,
    // vinimos de ahí en modo "guardar" (onSaveRequest).
    private var legacyUsernameId: AutofillId? = null
    private var legacyPasswordId: AutofillId? = null
    private var legacySaveUsername: String? = null
    private var legacySavePassword: String? = null
    private var legacyRequestingPackage: String? = null

    // Página web que pide (ADR 0020), solo desde el AutofillService legado.
    private var webDomain: String? = null
    private var webScheme: String? = null

    override fun getInitialRoute(): String = "/autofill"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        protectFromScreenCapture()
        getRequest = PendingIntentHandler.retrieveProviderGetCredentialRequest(intent)
        createRequest = PendingIntentHandler.retrieveProviderCreateCredentialRequest(intent)
        legacyUsernameId = intent.getParcelableExtra(EXTRA_LEGACY_USERNAME_ID)
        legacyPasswordId = intent.getParcelableExtra(EXTRA_LEGACY_PASSWORD_ID)
        legacySaveUsername = intent.getStringExtra(EXTRA_LEGACY_SAVE_USERNAME)
        legacySavePassword = intent.getStringExtra(EXTRA_LEGACY_SAVE_PASSWORD)
        legacyRequestingPackage = intent.getStringExtra(EXTRA_REQUESTING_PACKAGE)
        webDomain = intent.getStringExtra(EXTRA_WEB_DOMAIN)
        webScheme = intent.getStringExtra(EXTRA_WEB_SCHEME)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRequest" -> result.success(buildRequestMap())
                    "submitGet" -> {
                        submitGet(
                            username = call.argument<String>("username") ?: "",
                            password = call.argument<String>("password") ?: "",
                        )
                        result.success(null)
                    }
                    "startSession" -> {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                        val ttl = (call.argument<Number>("ttlMillis") ?: 0).toLong()
                        AutofillSession.start(this, items, ttl)
                        result.success(null)
                    }
                    "submitCreate" -> {
                        submitCreate()
                        result.success(null)
                    }
                    "cancel" -> {
                        setResult(Activity.RESULT_CANCELED)
                        finish()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun buildRequestMap(): Map<String, Any?> {
        if (legacySaveUsername != null && legacySavePassword != null) {
            return mapOf(
                "mode" to "create",
                "packageName" to (legacyRequestingPackage ?: ""),
                "webDomain" to webDomain,
                "webScheme" to webScheme,
                "username" to legacySaveUsername,
                "password" to legacySavePassword,
            )
        }
        if (legacyUsernameId != null || legacyPasswordId != null) {
            return mapOf(
                "mode" to "get",
                "packageName" to (legacyRequestingPackage ?: ""),
                "webDomain" to webDomain,
                "webScheme" to webScheme,
            )
        }
        getRequest?.let {
            return mapOf(
                "mode" to "get",
                "packageName" to it.callingAppInfo.packageName,
            )
        }
        createRequest?.let {
            val callingRequest = it.callingRequest
            if (callingRequest is CreatePasswordRequest) {
                return mapOf(
                    "mode" to "create",
                    "packageName" to it.callingAppInfo.packageName,
                    "username" to callingRequest.id,
                    "password" to callingRequest.password,
                )
            }
        }
        return mapOf("mode" to "unknown")
    }

    private fun submitGet(username: String, password: String) {
        if (legacyUsernameId != null || legacyPasswordId != null) {
            submitLegacyGet(username, password)
            return
        }
        val resultIntent = Intent()
        // La versión de androidx.credentials fijada en build.gradle.kts
        // (1.6.0) todavía solo tiene el constructor de un único
        // Credential — el de List<Credential> se agregó después, ver el
        // comentario en build.gradle.kts.
        val credential: Credential = PasswordCredential(username, password)
        PendingIntentHandler.setGetCredentialResponse(
            resultIntent,
            GetCredentialResponse(credential),
        )
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }

    // Autofill legado (LockspireAutofillService) — a diferencia de
    // Credential Manager, acá se arma un Dataset real con los
    // AutofillId recibidos y se devuelve por la extra key que el propio
    // framework de Android lee automáticamente
    // (AutofillManager.EXTRA_AUTHENTICATION_RESULT), no por
    // PendingIntentHandler.
    private fun submitLegacyGet(username: String, password: String) {
        val datasetBuilder = android.service.autofill.Dataset.Builder()
        legacyUsernameId?.let {
            datasetBuilder.setValue(it, AutofillValue.forText(username))
        }
        legacyPasswordId?.let {
            datasetBuilder.setValue(it, AutofillValue.forText(password))
        }
        val resultIntent = Intent().putExtra(
            AutofillManager.EXTRA_AUTHENTICATION_RESULT,
            datasetBuilder.build(),
        )
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }

    private fun submitCreate() {
        // Guardado vía Autofill legado (LockspireAutofillService.
        // onSaveRequest) — el SaveCallback.onSuccess() del framework ya
        // se llamó del lado del servicio al abrir esta Activity (así lo
        // exige esa API), acá solo queda cerrar una vez que addEntry()
        // ya guardó la entrada en la bóveda (ver AutofillScreen).
        if (legacySaveUsername != null && legacySavePassword != null) {
            finish()
            return
        }
        val resultIntent = Intent()
        PendingIntentHandler.setCreateCredentialResponse(
            resultIntent,
            CreatePasswordResponse(),
        )
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }

    companion object {
        private const val CHANNEL = "com.lockspire.lockspire/autofill"
        const val EXTRA_LEGACY_USERNAME_ID = "legacy_username_autofill_id"
        const val EXTRA_LEGACY_PASSWORD_ID = "legacy_password_autofill_id"
        const val EXTRA_LEGACY_SAVE_USERNAME = "legacy_save_username"
        const val EXTRA_LEGACY_SAVE_PASSWORD = "legacy_save_password"
        const val EXTRA_REQUESTING_PACKAGE = "requesting_package"
        const val EXTRA_WEB_DOMAIN = "web_domain"
        const val EXTRA_WEB_SCHEME = "web_scheme"
    }
}
