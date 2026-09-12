// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

package com.lockspire.lockspire

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.credentials.CreatePasswordRequest
import androidx.credentials.CreatePasswordResponse
import androidx.credentials.GetCredentialResponse
import androidx.credentials.PasswordCredential
import androidx.credentials.provider.PendingIntentHandler
import androidx.credentials.provider.ProviderCreateCredentialRequest
import androidx.credentials.provider.ProviderGetCredentialRequest
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity respaldada por Flutter, destino del `PendingIntent` que arma
 * [LockspireCredentialProviderService] (ADR 0011). No exportada (ver
 * `AndroidManifest.xml`) — solo la puede lanzar ese servicio, nunca un
 * intent externo directo. Todo lo sensible (desbloqueo, matching de
 * entradas, guardado) ocurre del lado Dart, reusando la infraestructura
 * ya existente — esta clase solo traduce entre las APIs de Android
 * Credential Manager y un `MethodChannel` simple.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class AutofillActivity : FlutterFragmentActivity() {

    private var getRequest: ProviderGetCredentialRequest? = null
    private var createRequest: ProviderCreateCredentialRequest? = null

    override fun getInitialRoute(): String = "/autofill"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        getRequest = PendingIntentHandler.retrieveProviderGetCredentialRequest(intent)
        createRequest = PendingIntentHandler.retrieveProviderCreateCredentialRequest(intent)
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
        val resultIntent = Intent()
        PendingIntentHandler.setGetCredentialResponse(
            resultIntent,
            GetCredentialResponse(listOf(PasswordCredential(username, password))),
        )
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }

    private fun submitCreate() {
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
    }
}
