// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/secure_storage_provider.dart';
import '../../../vault/domain/entities/entry_fields.dart';
import '../../../vault/presentation/vault_entries_controller.dart';
import '../../domain/browser_login.dart';
import '../../domain/ports/login_save_exclusions_port.dart';
import '../../infrastructure/secure_storage_login_save_exclusions_adapter.dart';

part 'browser_login_providers.g.dart';

@Riverpod(keepAlive: true)
LoginSaveExclusionsPort loginSaveExclusionsPort(Ref ref) =>
    SecureStorageLoginSaveExclusionsAdapter(ref.watch(secureStorageProvider));

/// Los sitios con "Nunca en este sitio", ordenados, para quitarlos desde la
/// pantalla Navegador.
@riverpod
Future<List<String>> loginSaveExclusions(Ref ref) async =>
    (await ref.watch(loginSaveExclusionsPortProvider).all()).toList()..sort();

/// Guarda un inicio de sesión del navegador (ADR 0034): entrada nueva con
/// el sitio como título, o la contraseña nueva de una entrada existente,
/// que conserva la anterior en su historial.
@Riverpod(keepAlive: true)
Future<void> Function(BrowserLogin, LoginMatch) browserLoginSaver(Ref ref) =>
    (login, match) async {
      final entries = ref.read(vaultEntriesControllerProvider);
      switch (match) {
        case NewLogin():
          await entries.addEntry(
            title: login.site,
            fields: login.newEntryFields,
          );
        case ChangedPassword(:final entry):
          await entries.replaceField(
            id: entry.id,
            field: EntryFields.password,
            value: login.password,
          );
        case AlreadySaved():
          break;
      }
    };

/// Inicios de sesión que el usuario aceptó guardar con la bóveda bloqueada:
/// se guardan al desbloquear (ADR 0034). Solo en memoria.
@Riverpod(keepAlive: true)
class PendingBrowserLogins extends _$PendingBrowserLogins {
  @override
  List<BrowserLogin> build() => const [];

  void add(BrowserLogin login) => state = [...state, login];

  /// Los devuelve y vacía la lista.
  List<BrowserLogin> take() {
    final taken = state;
    state = const [];
    return taken;
  }
}
