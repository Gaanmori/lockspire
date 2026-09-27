// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/services.dart';

import '../domain/ports/secure_clipboard_port.dart';

/// Android: `SecureClipboard.kt` copia con `EXTRA_IS_SENSITIVE` (Android
/// 13+ no lo muestra en la vista previa), programa el borrado con
/// WorkManager —Android congela la app en segundo plano y el temporizador
/// de Dart no correría— y reconoce su propia copia por la etiqueta.
class AndroidSecureClipboardAdapter implements SecureClipboardPort {
  final MethodChannel _channel;

  AndroidSecureClipboardAdapter({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.lockspire.lockspire/clipboard');

  @override
  Future<void> copySensitive(String text, {required Duration clearAfter}) =>
      _channel.invokeMethod<void>('copySensitive', {
        'text': text,
        'clearAfterMs': clearAfter.inMilliseconds,
      });

  @override
  Future<void> clearIfStillOurs() => _channel.invokeMethod<bool>('clearIfOurs');
}
