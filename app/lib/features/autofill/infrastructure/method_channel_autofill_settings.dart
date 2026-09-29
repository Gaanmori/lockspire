// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';

import '../domain/ports/system_autofill_settings_port.dart';

/// [SystemAutofillSettingsPort] sobre el canal `settings` de `MainActivity`.
class MethodChannelAutofillSettings implements SystemAutofillSettingsPort {
  static const _channel = MethodChannel('com.lockspire.lockspire/settings');

  const MethodChannelAutofillSettings();

  @override
  Future<bool> open() async {
    try {
      await _channel.invokeMethod('openAutofillServiceSettings');
      return true;
    } on PlatformException {
      return false;
    }
  }
}
