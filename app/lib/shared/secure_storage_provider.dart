// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage_provider.g.dart';

/// Único punto donde se crea el almacenamiento seguro del sistema (Keystore
/// en Android, DPAPI en Windows, libsecret en Linux). Todos los adaptadores
/// lo reciben inyectado, así sus opciones no pueden divergir (revisión
/// 2026-09-25, hallazgo A7).
@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage();
