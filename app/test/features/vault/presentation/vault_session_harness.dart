// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

// Arnés compartido de los tests de VaultSessionController, divididos por
// tema (revisión 2026-09-30, T4). No es un test: no termina en _test.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/clipboard/domain/ports/secure_clipboard_port.dart';
import 'package:lockspire/features/clipboard/presentation/providers/clipboard_guard_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/current_active_sync_provider_provider.dart';
import 'package:lockspire/features/sync/presentation/auto_sync_controller.dart';
import 'package:lockspire/features/sync/presentation/providers/active_sync_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/is_sync_configured_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_ancestor_storage_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_state_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_lock_timeout_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/auto_sync_debounce_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/biometric_auth_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/clock_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/master_password_reminder_settings_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/password_unlock_history_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/lock_on_background_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/auto_lock_controller.dart';

import '../../../support/fakes/sync_fakes.dart' as sync_fakes;
import '../../../support/fakes/vault_fakes.dart';
import '../../../support/fakes/fake_secure_clipboard.dart';

// Duración de los temporizadores en los tests: corren con el reloj simulado
// (`withFakeClock`), así que el valor solo importa en relación con los
// demás.
const shortTimeout = Duration(milliseconds: 60);

/// Corre [body] con el reloj simulado (revisión 2026-09-30, T3): el tiempo
/// avanza con [FakeAsync.elapse] al instante y sin depender de lo cargada
/// que esté la máquina. [settle] termina lo asíncrono en curso: los puertos
/// falsos solo usan microtareas.
void withFakeClock(
  void Function(FakeAsync clock, T Function<T>(Future<T> future) settle) body,
) => fakeAsync((clock) {
  T settle<T>(Future<T> future) {
    late T result;
    var done = false;
    future.then((value) {
      result = value;
      done = true;
    });
    clock.flushMicrotasks();
    expect(done, isTrue, reason: 'quedó esperando algo que no es del reloj');
    return result;
  }

  body(clock, settle);
});
const masterPassword = 'correcto-caballo-batería-grapa';

class SessionTestFakes {
  final FakeCryptoPort crypto;
  final FakeVaultStoragePort storage;
  final FakeBiometricAuthPort biometric;
  final FakePasswordUnlockHistoryPort history;

  SessionTestFakes({
    required this.crypto,
    required this.storage,
    required this.biometric,
    required this.history,
  });
}

/// Puertos de ADR 0017 en memoria: sin ellos, los tests usarían el
/// almacenamiento real (sin plugin en `flutter test`).
List<Override> reminderOverrides(
  FakePasswordUnlockHistoryPort history, {
  DateTime Function()? clock,
}) => [
  passwordUnlockHistoryPortProvider.overrideWithValue(history),
  masterPasswordReminderSettingsPortProvider.overrideWithValue(
    FakeMasterPasswordReminderSettingsPort(),
  ),
  if (clock != null) clockProvider.overrideWithValue(clock),
];

/// [lockOnBackground] en `true` por defecto (comportamiento de Android,
/// ADR 0008) — explícito porque los tests corren en un host de escritorio,
/// donde el valor real sería `false` (ADR 0012).
({ProviderContainer container, SessionTestFakes fakes}) buildSessionContainer({
  Duration timeout = shortTimeout,
  bool lockOnBackground = true,
  DateTime Function()? clock,
  SecureClipboardPort? clipboard,
}) {
  final crypto = FakeCryptoPort();
  final storage = FakeVaultStoragePort();
  final biometric = FakeBiometricAuthPort();
  final history = FakePasswordUnlockHistoryPort();
  final container = ProviderContainer(
    overrides: [
      cryptoPortProvider.overrideWith((ref) async => crypto),
      vaultStoragePortProvider.overrideWith((ref) async => storage),
      autoLockTimeoutProvider.overrideWith((ref) => timeout),
      lockOnBackgroundProvider.overrideWith((ref) => lockOnBackground),
      biometricAuthPortProvider.overrideWith((ref) => biometric),
      secureClipboardPortProvider.overrideWithValue(
        clipboard ?? FakeSecureClipboard(),
      ),
      ...reminderOverrides(history, clock: clock),
    ],
  );
  addTearDown(container.dispose);
  // Como en main.dart: el bloqueo automático escucha la sesión.
  container.read(autoLockControllerProvider);
  return (
    container: container,
    fakes: SessionTestFakes(
      crypto: crypto,
      storage: storage,
      biometric: biometric,
      history: history,
    ),
  );
}

class SyncSessionTestFakes {
  final FakeCryptoPort crypto;
  final FakeVaultStoragePort storage;
  final FakeVaultStoragePort ancestorStorage;
  final sync_fakes.FakeSyncPort syncPort;
  final sync_fakes.FakeSyncStatePort syncState;

  SyncSessionTestFakes({
    required this.crypto,
    required this.storage,
    required this.ancestorStorage,
    required this.syncPort,
    required this.syncState,
  });
}

/// Igual que [buildSessionContainer], pero con credenciales de sync configuradas
/// y todo el resto de las dependencias de `SyncVaultUseCase` fakeadas —
/// para los tests de sync automática de más abajo. [hasCredentials] en
/// `false` simula que el usuario nunca configuró sync.
({ProviderContainer container, SyncSessionTestFakes fakes})
buildSessionContainerWithSync({
  Duration timeout = const Duration(minutes: 5),
  Duration syncDebounce = shortTimeout,
  bool hasCredentials = true,
}) {
  final crypto = FakeCryptoPort();
  final storage = FakeVaultStoragePort();
  final ancestorStorage = FakeVaultStoragePort();
  final syncPort = sync_fakes.FakeSyncPort();
  final syncState = sync_fakes.FakeSyncStatePort();

  final container = ProviderContainer(
    overrides: [
      cryptoPortProvider.overrideWith((ref) async => crypto),
      vaultStoragePortProvider.overrideWith((ref) async => storage),
      autoLockTimeoutProvider.overrideWith((ref) => timeout),
      autoSyncDebounceProvider.overrideWith((ref) => syncDebounce),
      isSyncConfiguredProvider.overrideWith((ref) async => hasCredentials),
      activeSyncPortProvider.overrideWith((ref) async => syncPort),
      currentActiveSyncProviderProvider.overrideWith((ref) async => null),
      syncStatePortProvider.overrideWith((ref) => syncState),
      syncAncestorStoragePortProvider.overrideWith(
        (ref) async => ancestorStorage,
      ),
      ...reminderOverrides(FakePasswordUnlockHistoryPort()),
    ],
  );
  addTearDown(container.dispose);
  // Como en main.dart: el bloqueo y la sync automáticos escuchan la sesión.
  container.read(autoLockControllerProvider);
  container.read(autoSyncControllerProvider);
  return (
    container: container,
    fakes: SyncSessionTestFakes(
      crypto: crypto,
      storage: storage,
      ancestorStorage: ancestorStorage,
      syncPort: syncPort,
      syncState: syncState,
    ),
  );
}
