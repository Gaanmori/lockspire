// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/system_autofill_settings_port.dart';
import '../../infrastructure/method_channel_autofill_settings.dart';

part 'system_autofill_settings_port_provider.g.dart';

@Riverpod(keepAlive: true)
SystemAutofillSettingsPort systemAutofillSettingsPort(Ref ref) =>
    const MethodChannelAutofillSettings();
