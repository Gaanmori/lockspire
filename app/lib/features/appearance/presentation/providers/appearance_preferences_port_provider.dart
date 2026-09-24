// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/appearance_preferences_port.dart';
import '../../infrastructure/secure_storage_appearance_adapter.dart';

part 'appearance_preferences_port_provider.g.dart';

/// Composition root del almacenamiento de la preferencia de tema.
@Riverpod(keepAlive: true)
AppearancePreferencesPort appearancePreferencesPort(Ref ref) =>
    const SecureStorageAppearanceAdapter();
