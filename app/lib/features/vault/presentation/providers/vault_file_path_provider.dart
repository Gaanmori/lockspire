// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/profile_paths.dart';
import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_file_path_provider.g.dart';

/// Carpeta de los datos de la app. Se usa `getApplicationSupportDirectory()`
/// (no "Documents", que en algunas plataformas se sincroniza sola con la
/// nube del sistema).
@Riverpod(keepAlive: true)
Future<String> appDataDirectory(Ref ref) async =>
    (await getApplicationSupportDirectory()).path;

/// Ruta del archivo de bóveda del perfil abierto (ADR 0039): el principal
/// conserva la de siempre; los demás, `profiles/<id>/`.
@Riverpod(keepAlive: true)
Future<String> vaultFilePath(Ref ref) async => vaultFilePathFor(
  await ref.watch(appDataDirectoryProvider.future),
  ref.watch(activeProfileIdProvider),
);
