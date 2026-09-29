// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_file_path_provider.g.dart';

const _vaultFileName = 'vault.lockspire';

/// Ruta del archivo de bóveda en un directorio privado de la app.
///
/// Se usa `getApplicationSupportDirectory()` (no "Documents", que en
/// algunas plataformas se sincroniza automáticamente con la nube del SO)
/// — esto es un placeholder hasta que exista la feature de sync propia
/// (`SyncPort`, ver docs/THREAT_MODEL.md), que definirá dónde vive
/// realmente el archivo que se sincroniza.
@Riverpod(keepAlive: true)
Future<String> vaultFilePath(Ref ref) async {
  final dir = await getApplicationSupportDirectory();
  return '${dir.path}${Platform.pathSeparator}$_vaultFileName';
}
