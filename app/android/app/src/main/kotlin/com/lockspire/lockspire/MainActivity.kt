package com.lockspire.lockspire

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, no FlutterActivity — local_auth (ver
// docs/adr/0010-desbloqueo-biometrico.md) necesita una FragmentActivity
// para poder mostrar el BiometricPrompt nativo de Android; con
// FlutterActivity el prompt de huella simplemente no aparece.
class MainActivity : FlutterFragmentActivity()
