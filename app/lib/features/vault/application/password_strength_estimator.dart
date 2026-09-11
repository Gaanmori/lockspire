// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:math';

/// Nivel de fortaleza — 3 niveles (no 4) para poder mapear 1:1 a los 3
/// colores semánticos ya existentes en `LockspireColors`
/// (danger/accentDefault/accentSecondary) sin agregar tokens nuevos.
enum PasswordStrengthLevel { weak, fair, strong }

/// Resultado de [estimatePasswordStrength].
class PasswordStrengthEstimate {
  final double bits;
  final PasswordStrengthLevel level;

  /// Tiempo estimado de descifrado, ya formateado en español (ej.
  /// "3 años", "instantáneo").
  final String crackTimeLabel;

  const PasswordStrengthEstimate({
    required this.bits,
    required this.level,
    required this.crackTimeLabel,
  });
}

// Mismas 4 clases que usa `password_generator.dart` — se repiten acá
// (en vez de importar los `const` privados de ese archivo) para no
// acoplar el estimador a la implementación interna del generador; solo
// se necesita el tamaño de cada clase, no los caracteres exactos.
const _lowercaseSize = 26;
const _uppercaseSize = 26;
const _digitsSize = 10;
const _symbolsSize = 18;
// Cualquier caracter fuera de las 4 clases de arriba (tildes, espacios,
// unicode, etc.) — tamaño genérico conservador, no exacto.
const _otherSize = 100;

const _weakThresholdBits = 35;
const _strongThresholdBits = 70;

// Cantidad de palabras asumida en cada wordlist de
// `memorable_wordlists.dart` (~230 cada una) — usada solo para estimar
// la entropía real de un patrón `Palabra1<dígito>-Palabra2-...` (ver
// `_memorablePatternRegex` abajo), no importada directamente desde ahí
// para no acoplar este archivo puro a esa lista concreta. Si el tamaño
// de las wordlists cambia sustancialmente, actualizar acá también.
const _assumedMemorableWordListSize = 230;

// Coincide con la forma exacta que produce `generateMemorablePassword`
// (`password_generator.dart`): una palabra capitalizada + un dígito,
// seguida de cero o más palabras capitalizadas separadas por guion, sin
// más dígitos. Si una contraseña calza con esta forma (generada así o
// tecleada a mano con la misma pinta), se estima por cantidad de
// palabras en vez de por clase de caracteres — ver el comentario en
// [estimatePasswordStrength] sobre por qué importa la diferencia.
final _memorablePatternRegex = RegExp(r'^[A-Z][a-z]*[0-9](?:-[A-Z][a-z]*)*$');

/// Intentos por segundo asumidos para el tiempo estimado de descifrado
/// — **supuesto documentado, no medido**: representa un ataque offline
/// rápido (hardware dedicado contra un hash débil/sin salt), referencia
/// habitual en la industria. No es el caso de Lockspire en sí (Argon2id
/// agresivo, ver ADR 0007) — es una estimación general de "qué tan
/// grande es el espacio de búsqueda", no del tiempo real de atacar esta
/// app puntual.
const _guessesPerSecond = 1e10;

/// Estima la fortaleza de [password].
///
/// Si [password] tiene la forma exacta que produce
/// `generateMemorablePassword` (`Palabra1<dígito>-Palabra2-...`, ver
/// [_memorablePatternRegex]), se estima por **cantidad de palabras**
/// asumiendo el tamaño real de las wordlists del proyecto
/// ([_assumedMemorableWordListSize]) — es la cuenta que importa de
/// verdad contra un atacante que prueba palabras de diccionario en vez
/// de todo el alfabeto letra por letra, y suele dar bits bastante más
/// bajos que la cuenta por clase de caracteres (una contraseña de 3
/// palabras comunes "se ve" larga y variada, pero el espacio real de
/// búsqueda es mucho más chico que su longitud en caracteres sugiere).
///
/// Para cualquier otro caso (contraseña aleatoria, tecleada a mano, o
/// cualquier forma que no calce con el patrón de arriba), se estima
/// **solo por las clases de caracteres presentes**
/// (minúscula/mayúscula/dígito/símbolo/otro) — funciona igual para algo
/// tecleado a mano que para algo generado.
///
/// **Limitación documentada a propósito, en ambos casos:** no es un
/// modelo tipo zxcvbn completo (sin diccionario general de contraseñas
/// filtradas/patrones de teclado/sustituciones l33t, etc.) — la rama
/// "por palabras" cubre específicamente la forma que genera esta app,
/// no cualquier contraseña basada en diccionario del mundo real. Se
/// acepta como simplificación para esta pasada, mismo criterio de
/// "estimación transparente con supuestos explícitos" usado en el
/// resto del proyecto (ver ADR 0007, `fieldConflictsResolved`, etc.).
PasswordStrengthEstimate estimatePasswordStrength(String password) {
  if (password.isEmpty) {
    return const PasswordStrengthEstimate(
      bits: 0,
      level: PasswordStrengthLevel.weak,
      crackTimeLabel: 'instantáneo',
    );
  }

  if (_memorablePatternRegex.hasMatch(password)) {
    final wordCount = password.split('-').length;
    final bitsPerWord = log(_assumedMemorableWordListSize) / log(2);
    final digitBits = log(10) / log(2);
    final bits = wordCount * bitsPerWord + digitBits;
    return PasswordStrengthEstimate(
      bits: bits,
      level: _levelFor(bits),
      crackTimeLabel: _formatCrackTime(bits),
    );
  }

  var poolSize = 0;
  if (password.contains(RegExp('[a-z]'))) poolSize += _lowercaseSize;
  if (password.contains(RegExp('[A-Z]'))) poolSize += _uppercaseSize;
  if (password.contains(RegExp('[0-9]'))) poolSize += _digitsSize;
  if (password.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{}]'))) {
    poolSize += _symbolsSize;
  }
  if (password.contains(RegExp(r'[^a-zA-Z0-9!@#$%^&*()\-_=+\[\]{}]'))) {
    poolSize += _otherSize;
  }
  if (poolSize == 0) poolSize = 1;

  final bits = password.length * (log(poolSize) / log(2));

  return PasswordStrengthEstimate(
    bits: bits,
    level: _levelFor(bits),
    crackTimeLabel: _formatCrackTime(bits),
  );
}

PasswordStrengthLevel _levelFor(double bits) => bits < _weakThresholdBits
    ? PasswordStrengthLevel.weak
    : bits < _strongThresholdBits
    ? PasswordStrengthLevel.fair
    : PasswordStrengthLevel.strong;

/// Formatea el tiempo estimado de descifrado a partir de [bits] de
/// entropía — `double` en toda la cuenta (nunca `Duration`, que
/// desborda con contraseñas largas: 64 caracteres aleatorios ya superan
/// los 400 bits, muy por fuera de lo que `Duration` puede representar).
String _formatCrackTime(double bits) {
  // Caso promedio: un atacante encuentra la contraseña a mitad de
  // recorrer todo el espacio de búsqueda, no al final.
  final guesses = pow(2, bits - 1);
  final seconds = guesses / _guessesPerSecond;

  if (seconds < 1) return 'instantáneo';
  if (seconds < 60) return '${seconds.round()} segundos';

  final minutes = seconds / 60;
  if (minutes < 60) return '${minutes.round()} minutos';

  final hours = minutes / 60;
  if (hours < 24) return '${hours.round()} horas';

  final days = hours / 24;
  if (days < 30) return '${days.round()} días';

  final months = days / 30;
  if (months < 12) return '${months.round()} meses';

  final years = days / 365;
  if (years < 100) return '${years.round()} años';
  if (years < 1e6) return '${(years / 100).round()} siglos';

  return 'millones de años';
}
