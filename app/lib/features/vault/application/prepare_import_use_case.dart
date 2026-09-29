// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities/vault_entry.dart';
import '../domain/ports/vault_import_source.dart';
import '../domain/vault_import_merge.dart';
import 'vault_transfer_use_cases.dart';

/// El archivo no es de un formato que Lockspire sepa importar.
class UnknownImportFormatException implements Exception {
  final String extension;

  const UnknownImportFormatException(this.extension);

  @override
  String toString() =>
      'Formato no reconocido: .$extension. Use un XML de SafeInCloud, un '
      'CSV, un JSON de Bitwarden o un respaldo .lockspire.';
}

/// Lo que se va a importar y si el archivo de origen estaba sin cifrar
/// (para recordar borrarlo).
class PreparedImport {
  final ImportSelection selection;
  final bool sourceUnencrypted;

  const PreparedImport({
    required this.selection,
    required this.sourceUnencrypted,
  });
}

/// Del archivo elegido a las entradas nuevas que se ofrecerán importar
/// (ADR 0027): elige el formato por la extensión, abre el respaldo
/// `.lockspire` con su contraseña y descarta las que ya están en la
/// bóveda. No escribe nada: eso pasa cuando el usuario confirma.
class PrepareImportUseCase {
  /// El adaptador de texto para una extensión, o `null` si no hay.
  final VaultImportSource? Function(String extension) sourceFor;
  final ReadEncryptedBackupUseCase readBackup;

  const PrepareImportUseCase({
    required this.sourceFor,
    required this.readBackup,
  });

  /// `null` si el usuario canceló la contraseña del respaldo. Lanza
  /// [UnknownImportFormatException], `FormatException` si el contenido no
  /// se puede leer, o `IncorrectBackupPasswordException`.
  Future<PreparedImport?> call({
    required Uint8List bytes,
    required String fileName,
    required Iterable<VaultEntry> existing,
    required Future<String?> Function() askBackupPassword,
  }) async {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final List<VaultEntry> incoming;
    final bool unencrypted;
    if (extension == 'lockspire') {
      final password = await askBackupPassword();
      if (password == null) return null;
      incoming = await readBackup.call(bytes: bytes, password: password);
      unencrypted = false;
    } else {
      final source = sourceFor(extension);
      if (source == null) throw UnknownImportFormatException(extension);
      incoming = await source.parse(utf8.decode(bytes));
      unencrypted = true;
    }
    return PreparedImport(
      selection: selectEntriesToImport(existing: existing, incoming: incoming),
      sourceUnencrypted: unencrypted,
    );
  }
}
