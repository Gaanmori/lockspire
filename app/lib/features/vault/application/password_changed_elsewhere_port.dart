// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'unlocked_vault_result.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

/// La contraseña maestra se cambió en otro dispositivo y este todavía no la
/// adoptó (ADR 0024). `vault` no conoce la sync: define el puerto y `sync`
/// lo implementa (conexión en `lib/app_composition.dart`, hallazgo A3).
///
/// Vive en `application/` y no en `domain/` porque devuelve
/// [UnlockedVaultResult], que es de esta capa.
abstract class PasswordChangedElsewherePort {
  /// Lo que ya se sabe, sin red: una sync anterior lo detectó.
  Future<bool> isPending();

  /// Mira la nube (sin descifrar nada, solo el header) y lo anota si la
  /// contraseña cambió. Nunca lanza: sin red devuelve lo ya sabido.
  Future<bool> checkRemote();

  /// Abre la bóveda con la contraseña nueva, verificada con AEAD contra la
  /// copia de la nube, y deja este dispositivo con ella.
  ///
  /// Si hay cambios locales sin sincronizar, hacen falta también la
  /// contraseña anterior para descifrarlos y conservarlos: sin
  /// [previousPassword] lanza [PreviousPasswordRequiredException].
  Future<UnlockedVaultResult> unlockWithNewPassword({
    required String newPassword,
    String? previousPassword,
  });
}

/// Hay cambios en este dispositivo que no se sincronizaron y están cifrados
/// con la contraseña anterior.
class PreviousPasswordRequiredException implements Exception {
  const PreviousPasswordRequiredException();

  @override
  String toString() =>
      'Este dispositivo tiene cambios sin sincronizar. Ingrese también la '
      'contraseña anterior para conservarlos.';
}

/// La contraseña anterior no abre la bóveda de este dispositivo.
class IncorrectPreviousPasswordException implements Exception {
  const IncorrectPreviousPasswordException();

  @override
  String toString() => 'La contraseña anterior no es correcta.';
}

/// Sin sync no hay otros dispositivos: nunca hay un cambio pendiente. Es el
/// valor por defecto de `vault`.
class NoPasswordChangedElsewhere implements PasswordChangedElsewherePort {
  const NoPasswordChangedElsewhere();

  @override
  Future<bool> isPending() async => false;

  @override
  Future<bool> checkRemote() async => false;

  @override
  Future<UnlockedVaultResult> unlockWithNewPassword({
    required String newPassword,
    String? previousPassword,
  }) => throw const AppProblem(AppProblemCode.syncNotConfigured);
}
