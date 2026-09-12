package com.lockspire.lockspire

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, no FlutterActivity — local_auth (ver
// docs/adr/0010-desbloqueo-biometrico.md) necesita una FragmentActivity
// para poder mostrar el BiometricPrompt nativo de Android; con
// FlutterActivity el prompt de huella simplemente no aparece.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Autofill nativo (ADR 0011) — abre la pantalla de Config donde
        // el usuario activa Lockspire como gestor de credenciales; Android
        // no deja que una app se auto-registre.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lockspire.lockspire/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openCredentialProviderSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            startActivity(Intent(Settings.ACTION_CREDENTIAL_PROVIDER))
                            result.success(null)
                        } else {
                            result.error(
                                "UNSUPPORTED",
                                "Autofill nativo requiere Android 14 o superior",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
