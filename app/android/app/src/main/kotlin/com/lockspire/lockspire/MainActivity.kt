package com.lockspire.lockspire

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, no FlutterActivity — local_auth (ver
// docs/adr/0010-desbloqueo-biometrico.md) necesita una FragmentActivity
// para poder mostrar el BiometricPrompt nativo de Android; con
// FlutterActivity el prompt de huella simplemente no aparece.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        protectFromScreenCapture()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Autofill nativo (ADR 0011) — abre la pantalla de Config donde
        // el usuario activa Lockspire como servicio de autocompletado;
        // Android no deja que una app se auto-registre.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lockspire.lockspire/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAutofillServiceSettings" -> {
                        // Autofill legado (ADR 0011) — este intent le
                        // pide confirmación directa al usuario ("¿Usar
                        // Lockspire como servicio de autocompletado?"),
                        // sin pasar por ninguna pantalla de navegación —
                        // existe desde Android 8, mucho más consistente
                        // entre fabricantes que el de Credential Manager
                        // (descartado, ver docs/STATE.md: no lo
                        // resolvía este mismo teléfono). Mismo patrón
                        // que usa SafeInCloud.
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(null)
                        } catch (e: ActivityNotFoundException) {
                            result.error(
                                "NOT_FOUND",
                                "Este teléfono no tiene una pantalla de sistema para esto. " +
                                    "Buscá \"Servicio de autocompletado\" en los Ajustes.",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
