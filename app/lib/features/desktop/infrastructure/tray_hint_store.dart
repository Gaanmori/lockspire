// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _key = 'desktop.tray_hint_shown';

/// Recuerda si ya se le explicó al usuario que cerrar la ventana deja
/// Lockspire en la bandeja (ADR 0012). No es un secreto; se guarda en el
/// mismo almacenamiento que el resto de flags de la app para no añadir
/// otra dependencia.
class TrayHintStore {
  final FlutterSecureStorage _storage;

  const TrayHintStore(this._storage);

  Future<bool> wasShown() async => (await _storage.read(key: _key)) == 'true';

  Future<void> markShown() => _storage.write(key: _key, value: 'true');
}
