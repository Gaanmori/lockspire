// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'password_strength_estimator.dart';

/// Por qué una contraseña maestra nueva no se acepta (ADR 0018).
enum MasterPasswordProblem { tooShort, tooRepetitive, tooWeak }

const masterPasswordMinLength = 12;
const _minDistinctCharacters = 6;
const _minEstimatedBits = 50.0;

/// Política para una contraseña maestra **nueva** (al crear la bóveda o al
/// cambiarla). Nunca se aplica al desbloquear. Devuelve `null` si se
/// acepta.
MasterPasswordProblem? checkNewMasterPassword(String password) {
  if (password.runes.length < masterPasswordMinLength) {
    return MasterPasswordProblem.tooShort;
  }
  if (password.runes.toSet().length < _minDistinctCharacters) {
    return MasterPasswordProblem.tooRepetitive;
  }
  if (estimatePasswordStrength(password).bits < _minEstimatedBits) {
    return MasterPasswordProblem.tooWeak;
  }
  return null;
}

/// Mensaje para mostrar en un formulario.
String describeMasterPasswordProblem(MasterPasswordProblem problem) =>
    switch (problem) {
      MasterPasswordProblem.tooShort =>
        'Usá al menos $masterPasswordMinLength caracteres',
      MasterPasswordProblem.tooRepetitive =>
        'Tiene demasiados caracteres repetidos',
      MasterPasswordProblem.tooWeak =>
        'Es demasiado fácil de adivinar: sumá palabras, mayúsculas, '
            'números o símbolos',
    };
