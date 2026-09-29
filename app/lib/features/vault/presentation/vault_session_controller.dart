// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:lockspire/features/clipboard/presentation/providers/clipboard_guard_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/change_master_password_use_case.dart';
import '../application/save_vault_use_case.dart';
import '../application/unlocked_vault_result.dart';
import '../domain/entities/vault.dart';
import '../domain/vault_event.dart';
import '../domain/vault_file_codec.dart';
import 'providers/biometric_auth_port_provider.dart';
import 'providers/clock_provider.dart';
import 'providers/vault_events_provider.dart';
import 'providers/change_master_password_use_case_provider.dart';
import 'providers/create_vault_use_case_provider.dart';
import 'providers/replace_biometric_key_use_case_provider.dart';
import 'providers/save_vault_use_case_provider.dart';
import 'providers/unlock_vault_use_case_provider.dart';
import 'providers/check_master_password_required_provider.dart';
import 'providers/password_changed_elsewhere_port_provider.dart';
import 'providers/password_unlock_history_port_provider.dart';
import 'providers/vault_auth_attempt_provider.dart';
import 'providers/vault_storage_port_provider.dart';
import 'vault_session_state.dart';

part 'vault_session_controller.g.dart';

/// Único lugar que conecta los casos de uso de `application/` con los
/// adaptadores reales de `infrastructure/` (vía los providers de
/// composition root) — el resto de la UI solo habla con este controller.
///
/// El bloqueo automático está en `AutoLockController`, las entradas en
/// `VaultEntriesController` y la configuración biométrica en
/// `BiometricUnlockController` (revisión 2026-09-25, hallazgo A1).
///
/// `keepAlive: true` es deliberado, no solo conveniencia: si este
/// controller se auto-dispusiera al quedar momentáneamente sin listeners
/// (ej. durante una transición de pantalla), perdería el estado de
/// sesión — incluida la bóveda desbloqueada en memoria — de forma
/// impredecible. Es el mismo singleton-por-sesión-de-app que ya usan los
/// providers de composition root (`crypto_port_provider.dart`, etc.).
@Riverpod(keepAlive: true)
class VaultSessionController extends _$VaultSessionController {
  @override
  Future<VaultSessionState> build() async {
    final storage = await ref.watch(vaultStoragePortProvider.future);
    final exists = await storage.exists();
    return exists ? const VaultSessionLocked() : const VaultSessionNoVault();
  }

  /// Crea la bóveda. El progreso/error de este intento se refleja en
  /// [vaultAuthAttemptProvider], **no** en el estado de este controller —
  /// ver el comentario de ese provider para el porqué: si este `state`
  /// pasara por `AsyncLoading`/`AsyncError` mientras corre, `VaultGateScreen`
  /// reemplazaría `CreateVaultScreen` por una pantalla genérica sin
  /// contexto durante los ~3.5s de Argon2id.
  Future<void> createVault(String masterPassword) async {
    final attempt = ref.read(vaultAuthAttemptProvider.notifier);
    attempt.state = const AsyncLoading();
    try {
      final created = await (await ref.read(createVaultUseCaseProvider.future))(
        masterPassword: masterPassword,
      );
      state = AsyncData(
        VaultSessionUnlocked(
          vault: created.vault,
          key: created.key,
          header: created.header,
          fileHash: created.fileHash,
        ),
      );
      attempt.state = const AsyncData(null);
      await _recordPasswordUnlock();
      _emit(VaultEvent.unlocked);
    } catch (error, stackTrace) {
      attempt.state = AsyncError(error, stackTrace);
    }
  }

  /// Desbloquea la bóveda existente. Ver el comentario de [createVault]:
  /// mismo motivo para no tocar `state` mientras corre.
  Future<void> unlock(String masterPassword) async {
    final attempt = ref.read(vaultAuthAttemptProvider.notifier);
    attempt.state = const AsyncLoading();
    try {
      final unlocked = await (await ref.read(
        unlockVaultUseCaseProvider.future,
      ))(masterPassword: masterPassword);
      state = AsyncData(
        VaultSessionUnlocked(
          vault: unlocked.vault,
          key: unlocked.key,
          header: unlocked.header,
          fileHash: unlocked.fileHash,
        ),
      );
      attempt.state = const AsyncData(null);
      await _recordPasswordUnlock();
      _emit(VaultEvent.unlocked);
    } catch (error, stackTrace) {
      attempt.state = AsyncError(error, stackTrace);
    }
  }

  /// Desbloquea con la clave cacheada tras la biometría/PIN del sistema
  /// (huella en Android, Windows Hello en escritorio — ver
  /// `BiometricAuthPort`, docs/adr/0010-desbloqueo-biometrico.md). Nunca
  /// deriva nada ni pide la contraseña maestra — reusa
  /// `UnlockVaultUseCase.reloadWithKey()`, el mismo primitivo que ya usa
  /// [reloadFromDisk] para recargar con una clave ya conocida.
  ///
  /// Si el usuario cancela o falla la verificación,
  /// [BiometricAuthPort.readKey] devuelve `null` y acá no se toca nada
  /// (ni `state` ni [vaultAuthAttemptProvider]) — sigue viendo la
  /// pantalla de desbloqueo normal, sin un error que no pidió ver.
  ///
  /// Si ya venció el plazo para exigir la contraseña maestra (ADR 0017),
  /// no hace nada aunque la pantalla lo haya llamado: la regla se aplica
  /// aquí, no solo ocultando el botón.
  Future<void> unlockWithBiometrics() async {
    if (await _passwordRequired()) return;
    final port = ref.read(biometricAuthPortProvider);
    final key = await port.readKey();
    if (key == null) return;
    // La nube pudo revelar el cambio mientras el prompt estaba abierto.
    if (await _passwordChangedElsewhere()) return;

    final attempt = ref.read(vaultAuthAttemptProvider.notifier);
    attempt.state = const AsyncLoading();
    try {
      final unlocked = await (await ref.read(
        unlockVaultUseCaseProvider.future,
      )).reloadWithKey(key: key);
      state = AsyncData(
        VaultSessionUnlocked(
          vault: unlocked.vault,
          key: unlocked.key,
          header: unlocked.header,
          fileHash: unlocked.fileHash,
        ),
      );
      attempt.state = const AsyncData(null);
      _emit(VaultEvent.unlocked);
    } catch (error, stackTrace) {
      attempt.state = AsyncError(error, stackTrace);
    }
  }

  /// Sin biometría si venció el plazo de ADR 0017 o si la contraseña se
  /// cambió en otro dispositivo (ADR 0024).
  Future<bool> _passwordRequired() async =>
      await ref.read(checkMasterPasswordRequiredProvider)() ||
      await _passwordChangedElsewhere();

  Future<bool> _passwordChangedElsewhere() async {
    try {
      return await (await ref.read(
        passwordChangedElsewherePortProvider.future,
      )).isPending();
    } catch (_) {
      return false;
    }
  }

  /// Desbloquea con la contraseña maestra que se cambió en otro
  /// dispositivo (ADR 0024) y deja este con ella. Mismo manejo de
  /// progreso/error que [unlock]: [PreviousPasswordRequiredException] pide
  /// también la anterior, porque hay cambios locales sin sincronizar.
  Future<void> unlockWithNewPassword({
    required String newPassword,
    String? previousPassword,
  }) async {
    final attempt = ref.read(vaultAuthAttemptProvider.notifier);
    attempt.state = const AsyncLoading();
    try {
      final port = await ref.read(passwordChangedElsewherePortProvider.future);
      final result = await port.unlockWithNewPassword(
        newPassword: newPassword,
        previousPassword: previousPassword,
      );
      await adoptRekeyedSession(result);
      attempt.state = const AsyncData(null);
      _emit(VaultEvent.unlocked);
    } catch (error, stackTrace) {
      attempt.state = AsyncError(error, stackTrace);
    }
  }

  /// Cambia la contraseña maestra (ADR 0018). Lanza
  /// [IncorrectMasterPasswordException], [WeakMasterPasswordException] o el
  /// error de sync/escritura que impidió el cambio; en todos esos casos la
  /// sesión sigue con la contraseña anterior.
  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.value is! VaultSessionUnlocked) return;
    _emit(VaultEvent.rekeying);
    final result = await (await ref.read(
      changeMasterPasswordUseCaseProvider.future,
    )).call(currentPassword: currentPassword, newPassword: newPassword);
    await adoptRekeyedSession(result);
  }

  /// Pasa la sesión a una clave nueva — tras cambiar la contraseña aquí o
  /// adoptar la que se cambió en otro dispositivo (ADR 0018). Cuenta como
  /// ingreso de la contraseña maestra (ADR 0017) y renueva la clave
  /// cacheada para biometría, que ya no abre la bóveda.
  ///
  /// La clave de la biometría se reemplaza **antes** de mostrar la bóveda:
  /// al abrirse, la pantalla revisa si hay biometría configurada para
  /// ofrecerla, y hacerlo después preguntaba de nuevo a quien ya la tenía
  /// activa (visto en el Redmi al adoptar una contraseña cambiada en
  /// Windows).
  Future<void> adoptRekeyedSession(UnlockedVaultResult result) async {
    await ref.read(replaceBiometricKeyUseCaseProvider).call(result.key);
    state = AsyncData(
      VaultSessionUnlocked(
        vault: result.vault,
        key: result.key,
        header: result.header,
        fileHash: result.fileHash,
      ),
    );
    await _recordPasswordUnlock();
  }

  /// Abre la sesión con una bóveda restaurada desde la nube y ya descifrada
  /// (`RestoreVaultController`, en `sync`, hallazgo A3). Cuenta como ingreso
  /// de la contraseña maestra (ADR 0017).
  Future<void> openRestoredSession(UnlockedVaultResult restored) async {
    state = AsyncData(
      VaultSessionUnlocked(
        vault: restored.vault,
        key: restored.key,
        header: restored.header,
        fileHash: restored.fileHash,
      ),
    );
    await _recordPasswordUnlock();
    _emit(VaultEvent.unlocked);
  }

  /// Registra un desbloqueo con la contraseña maestra (ADR 0017) y reinicia
  /// el plazo para volver a pedirla. Un fallo al guardar no deshace el
  /// desbloqueo: en el peor caso, la próxima vez se vuelve a pedir la
  /// contraseña, que es el lado seguro.
  Future<void> _recordPasswordUnlock() async {
    try {
      await ref
          .read(passwordUnlockHistoryPortProvider)
          .recordPasswordUnlock(ref.read(clockProvider)());
    } catch (_) {}
  }

  /// Bloquea la sesión y, salvo [keepClipboard], borra ya cualquier
  /// secreto copiado (hallazgo S4).
  ///
  /// [keepClipboard] solo lo usa el bloqueo al pasar a segundo plano en
  /// Android: ahí el usuario sale de Lockspire justamente para pegar en
  /// otra app, y borrar en ese momento haría imposible copiar y pegar. Lo
  /// copiado se borra igual cuando vence el plazo de `ClipboardGuard`, que
  /// sigue corriendo con la app en segundo plano.
  void lock({bool keepClipboard = false}) {
    _emit(VaultEvent.locked);
    if (!keepClipboard) {
      unawaited(ref.read(clipboardGuardProvider).clearNow());
    }
    state = const AsyncData(VaultSessionLocked());
    // Limpia cualquier error/loading de un intento anterior — la próxima
    // vez que se muestre UnlockVaultScreen debe arrancar en blanco, no con
    // el "Contraseña incorrecta" de la sesión previa.
    ref.read(vaultAuthAttemptProvider.notifier).state = const AsyncData(null);
  }

  /// Vuelve a leer y descifrar el archivo actual con la key ya retenida —
  /// usado después de que sync escribe contenido nuevo localmente
  /// (descarga o merge, ver `SyncController`), para que la sesión en
  /// memoria no quede desactualizada respecto al archivo en disco.
  /// Deliberadamente **nunca** dispara sync — evita el loop obvio (sync
  /// escribe local → dispara sync → ...).
  Future<void> reloadFromDisk() async {
    final current = state.value;
    if (current is! VaultSessionUnlocked) return;
    final reloaded = await (await ref.read(
      unlockVaultUseCaseProvider.future,
    )).reloadWithKey(key: current.key);
    state = AsyncData(
      VaultSessionUnlocked(
        vault: reloaded.vault,
        key: reloaded.key,
        header: reloaded.header,
        fileHash: reloaded.fileHash,
      ),
    );
  }

  /// Único punto de escritura de la bóveda desbloqueada: cifra, guarda y
  /// actualiza la sesión. Lo usan las operaciones sobre entradas
  /// (`VaultEntriesController`, revisión 2026-09-25, hallazgo A1).
  ///
  /// Lanza [VaultWriteConflictException] si la bóveda cambió en disco desde
  /// la última lectura de esta sesión (ver `SaveVaultUseCase`); en ese caso
  /// el estado ya queda actualizado con la versión fresca antes de
  /// relanzar, para que un reintento inmediato parta de datos vigentes.
  Future<void> saveVault(Vault newVault) async {
    final current = state.value;
    if (current is! VaultSessionUnlocked) return;

    final save = await ref.read(saveVaultUseCaseProvider.future);
    final unlock = await ref.read(unlockVaultUseCaseProvider.future);

    try {
      final file = await save.call(
        vault: newVault,
        key: current.key,
        header: current.header,
        expectedFileHash: current.fileHash,
      );
      state = AsyncData(
        current.copyWith(
          vault: newVault,
          fileHash: VaultFileCodec.sha256Hex(file),
        ),
      );
      _emit(VaultEvent.saved);
    } on VaultWriteConflictException {
      // La contraseña maestra no cambió — solo el contenido en disco
      // (típicamente otro dispositivo sincronizó). Se recarga con la
      // misma key ya retenida, sin pedir la contraseña de nuevo.
      final reloaded = await unlock.reloadWithKey(key: current.key);
      state = AsyncData(
        VaultSessionUnlocked(
          vault: reloaded.vault,
          key: reloaded.key,
          header: reloaded.header,
          fileHash: reloaded.fileHash,
        ),
      );
      rethrow;
    }
  }

  void _emit(VaultEvent event) => ref.read(vaultEventsProvider).emit(event);
}
