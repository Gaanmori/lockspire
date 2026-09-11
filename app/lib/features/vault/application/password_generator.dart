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

const _maxMemorableWords = 8;
const _maxAttemptsPerWord = 10;

/// Genera una contraseña "fácil de recordar" con el patrón
/// `Palabra1<dígito><símbolo>Palabra2<símbolo>Palabra3<símbolo>...` (ej.
/// `Passed5#Forest&Sir`), tomando palabras de [wordList] con
/// `Random.secure()` (mismo criterio de seguridad que [generatePassword]).
/// El dígito solo se agrega a la primera palabra, igual que el ejemplo
/// que dio el usuario originalmente.
///
/// **El separador entre palabras es un símbolo elegido al azar por cada
/// hueco** (de [_symbols], el mismo set que usa [generatePassword] —
/// no un guion fijo) — pedido explícito del usuario para subir la
/// seguridad real del modo memorable: un atacante ahora también tiene
/// que adivinar qué símbolo separa cada par de palabras, no solo qué
/// palabras son (ver `password_strength_estimator.dart`, que ya
/// contempla esto al estimar). Cada hueco se sortea de forma
/// independiente, así que pueden salir símbolos distintos entre sí
/// dentro de la misma contraseña.
///
/// **Apunta a [targetLength] caracteres, no a una cantidad fija de
/// palabras** — mismo control que [generatePassword] (longitud), para
/// tener precisión real cuando un sitio exige un máximo/mínimo de
/// caracteres, en vez de una cantidad de palabras que da un largo
/// impredecible. Agrega palabras completas mientras entren sin superar
/// [targetLength] (nunca corta una palabra a la mitad, perdería el
/// sentido de "fácil de recordar") — como las palabras (y ahora
/// también los símbolos separadores) tienen largo variable, el
/// resultado se acerca a [targetLength] pero normalmente no lo toca
/// exacto. **Siempre incluye al menos una palabra**, aunque esa sola ya
/// supere [targetLength] (ej. `targetLength` muy chico) — nunca
/// devuelve una contraseña vacía.
String generateMemorablePassword({
  required List<String> wordList,
  int targetLength = 20,
}) {
  final random = Random.secure();

  String capitalize(String word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
  String pickWord() => capitalize(wordList[random.nextInt(wordList.length)]);
  String pickSeparator() => _symbols[random.nextInt(_symbols.length)];

  final digit = random.nextInt(10);
  final words = ['${pickWord()}$digit'];
  var length = words[0].length;

  while (words.length < _maxMemorableWords) {
    String? fittingWord;
    for (var attempt = 0; attempt < _maxAttemptsPerWord; attempt++) {
      final candidate = pickWord();
      if (length + 1 + candidate.length <= targetLength) {
        fittingWord = candidate;
        break;
      }
    }
    if (fittingWord == null) break;
    words.add(fittingWord);
    length += 1 + fittingWord.length;
  }

  final buffer = StringBuffer(words.first);
  for (final word in words.skip(1)) {
    buffer.write(pickSeparator());
    buffer.write(word);
  }
  return buffer.toString();
}
