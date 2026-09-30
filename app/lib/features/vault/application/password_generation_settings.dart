// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'password_generator.dart';
import '../domain/entities/entry_fields.dart';

/// Cómo se genera la contraseña de una entrada (revisión 2026-09-25,
/// hallazgo C1: la regla sale de `EntryFormScreen`).
enum PasswordGenerationMode { random, memorable }

/// Modo y longitud del generador. Se guardan como campos más de la entrada
/// (mismo criterio que `username`/`password`/`url`/`notes`, sin jerarquía
/// de subclases, ver `vault_entry.dart`): al editar, el panel arranca con
/// el modo y la longitud que se usaron, y "generar otra" reproduce el mismo
/// estilo. No son datos sensibles: dicen *cómo* se generó, no la contraseña.
class PasswordGenerationSettings {
  static const modeFieldKey = 'password_gen_mode';
  static const lengthFieldKey = 'password_gen_param';

  /// Un solo rango para los dos modos: el usuario pidió que "fácil de
  /// recordar" también se controle por cantidad de caracteres, para tener
  /// precisión real cuando un sitio exige un mínimo o un máximo.
  static const minLength = 8;
  static const maxLength = 48;
  static const defaultLength = 20;

  final PasswordGenerationMode mode;
  final int length;

  const PasswordGenerationSettings({required this.mode, required this.length});

  /// Para una entrada nueva: "fácil de recordar" por defecto (pedido del
  /// usuario).
  static const forNewEntry = PasswordGenerationSettings(
    mode: PasswordGenerationMode.memorable,
    length: defaultLength,
  );

  /// Para editar una entrada con [fields]. Si no tiene metadata de
  /// generación (creada antes de esta función o importada), no hay forma de
  /// saber cómo se hizo: se infiere aleatoria con la longitud de la
  /// contraseña actual, para que "generar otra" dé algo de tamaño parecido.
  factory PasswordGenerationSettings.fromFields(Map<String, String> fields) {
    final storedLength = int.tryParse(fields[lengthFieldKey] ?? '');
    return switch (fields[modeFieldKey]) {
      'random' => PasswordGenerationSettings(
        mode: PasswordGenerationMode.random,
        length: storedLength ?? defaultLength,
      ),
      'memorable' => PasswordGenerationSettings(
        mode: PasswordGenerationMode.memorable,
        length: storedLength ?? defaultLength,
      ),
      _ => PasswordGenerationSettings(
        mode: PasswordGenerationMode.random,
        length: (fields[EntryFields.password]?.length ?? defaultLength).clamp(
          minLength,
          maxLength,
        ),
      ),
    };
  }

  PasswordGenerationSettings copyWith({
    PasswordGenerationMode? mode,
    int? length,
  }) => PasswordGenerationSettings(
    mode: mode ?? this.mode,
    length: (length ?? this.length).clamp(minLength, maxLength),
  );

  Map<String, String> toFields() => {
    modeFieldKey: mode.name,
    lengthFieldKey: '$length',
  };

  /// Genera una contraseña. En modo "fácil de recordar" usa [wordList]
  /// (la lista en inglés, ver `WordListPort`).
  String generate({required List<String> wordList}) => switch (mode) {
    PasswordGenerationMode.random => generatePassword(length: length),
    PasswordGenerationMode.memorable => generateMemorablePassword(
      wordList: wordList,
      targetLength: length,
    ),
  };
}
