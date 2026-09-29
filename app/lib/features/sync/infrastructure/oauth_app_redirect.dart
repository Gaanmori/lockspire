// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/services.dart';

/// Vuelta del login OAuth a la app por una dirección propia (ADR 0022), en
/// vez de un servidor loopback. En Android la entrega `OAuthRedirectActivity`
/// por el canal `com.lockspire.lockspire/oauth_redirect`.
abstract class OAuthAppRedirect {
  /// La URI registrada en el proveedor OAuth.
  String get redirectUri;

  /// Redirecciones que van llegando, sin validar: quien escucha comprueba el
  /// `state` (`evaluateOAuthCallback`).
  Stream<Uri> get redirects;
}

class AndroidOAuthAppRedirect implements OAuthAppRedirect {
  static const _channel = MethodChannel(
    'com.lockspire.lockspire/oauth_redirect',
  );

  final _controller = StreamController<Uri>.broadcast();

  AndroidOAuthAppRedirect() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'redirect') return;
      final uri = Uri.tryParse(call.arguments as String? ?? '');
      if (uri != null) _controller.add(uri);
    });
  }

  @override
  String get redirectUri => 'com.lockspire.lockspire://oauth2redirect';

  @override
  Stream<Uri> get redirects => _controller.stream;
}
