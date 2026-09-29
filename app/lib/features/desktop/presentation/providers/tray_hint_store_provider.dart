// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../infrastructure/tray_hint_store.dart';

part 'tray_hint_store_provider.g.dart';

@Riverpod(keepAlive: true)
TrayHintStore trayHintStore(Ref ref) =>
    TrayHintStore(ref.watch(secureStorageProvider));
