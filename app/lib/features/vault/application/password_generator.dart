// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:math';

const _lowercase = 'abcdefghijklmnopqrstuvwxyz';
const _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _digits = '0123456789';
const _symbols = r'!@#$%^&*()-_=+[]{}';
const _allChars = _lowercase + _uppercase + _digits + _symbols;

/// Genera una contraseña aleatoria de [length] caracteres, con al menos un
/// caracter de cada clase (minúscula, mayúscula, dígito, símbolo).
///
/// Usa deliberadamente `Random.secure()` (fuente de aleatoriedad
/// criptográfica del sistema operativo) y **nunca** `Random()` a secas —
/// esto es una decisión de seguridad, no de estilo: Argon2id protege la
/// contraseña maestra, pero una contraseña generada con una fuente de
/// aleatoriedad predecible sería un agujero de seguridad propio, sin
/// relación con eso. No "simplificar" quitando `.secure()` en un futuro
/// refactor.
String generatePassword({int length = 20}) {
  assert(length >= 4, 'length debe alcanzar para cubrir las 4 clases');
  final random = Random.secure();

  final chars = <String>[
    _lowercase[random.nextInt(_lowercase.length)],
    _uppercase[random.nextInt(_uppercase.length)],
    _digits[random.nextInt(_digits.length)],
    _symbols[random.nextInt(_symbols.length)],
  ];
  for (var i = chars.length; i < length; i++) {
    chars.add(_allChars[random.nextInt(_allChars.length)]);
  }
  chars.shuffle(random);

  return chars.join();
}

/// Genera una contraseña "fácil de recordar" con el patrón
/// `Palabra1<dígito>-Palabra2-Palabra3` (ej. `Passed5-Forest-Sir`),
/// tomando [wordCount] palabras de [wordList] con `Random.secure()`
/// (mismo criterio de seguridad que [generatePassword]). El dígito solo
/// se agrega a la primera palabra, igual que el ejemplo que dio el
/// usuario — sin controlar [wordCount] desde la UI todavía (alcance
/// chico a propósito, ver docs/STATE.md).
String generateMemorablePassword({
  required List<String> wordList,
  int wordCount = 3,
}) {
  assert(wordCount >= 2, 'wordCount debe alcanzar para separar con guiones');
  final random = Random.secure();

  String capitalize(String word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

  final words = List.generate(
    wordCount,
    (_) => capitalize(wordList[random.nextInt(wordList.length)]),
  );
  final digit = random.nextInt(10);
  words[0] = '${words[0]}$digit';

  return words.join('-');
}
