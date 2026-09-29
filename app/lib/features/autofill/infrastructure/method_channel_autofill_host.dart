// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';

import '../domain/autofill_session.dart';
import '../domain/autofill_web_origin.dart';
import '../domain/ports/autofill_host_port.dart';

/// [AutofillHostPort] sobre el canal `com.lockspire.lockspire/autofill` de
/// `AutofillActivity` (Kotlin).
class MethodChannelAutofillHost implements AutofillHostPort {
  static const _channel = MethodChannel('com.lockspire.lockspire/autofill');

  const MethodChannelAutofillHost();

  @override
  Future<AutofillRequest> request() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getRequest',
    );
    final map = (raw ?? const {}).map((k, v) => MapEntry('$k', v));
    final packageName = map['packageName'] as String? ?? '';
    final origin = webOriginFor(
      webDomain: map['webDomain'] as String?,
      webScheme: map['webScheme'] as String?,
    );
    return switch (map['mode']) {
      'get' => AutofillFillRequest(packageName: packageName, origin: origin),
      'create' => AutofillSaveRequest(
        packageName: packageName,
        origin: origin,
        username: map['username'] as String? ?? '',
        password: map['password'] as String? ?? '',
      ),
      _ => const AutofillUnknownRequest(),
    };
  }

  @override
  Future<void> startSession({
    required Duration ttl,
    required Set<String> trustedBrowsers,
    required List<AutofillSessionItem> items,
  }) => _channel.invokeMethod('startSession', {
    'ttlMillis': ttl.inMilliseconds,
    'trustedBrowsers': trustedBrowsers.toList(),
    'items': [for (final item in items) _itemToChannel(item)],
  });

  static Map<String, Object> _itemToChannel(AutofillSessionItem item) => {
    'title': item.title,
    'username': item.username,
    'password': item.password,
    'hosts': [for (final s in item.sites) s.host],
    'httpsOnly': [for (final s in item.sites) s.httpsOnly],
    'apps': item.apps,
  };

  @override
  Future<void> fill({required String username, required String password}) =>
      _channel.invokeMethod('submitGet', {
        'username': username,
        'password': password,
      });

  @override
  Future<void> confirmSaved() => _channel.invokeMethod('submitCreate');

  @override
  Future<void> cancel() => _channel.invokeMethod('cancel');
}
