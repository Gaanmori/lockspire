// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/active_profile_provider.dart';
import 'package:lockspire/shared/app_data_directory_provider.dart';
import 'package:lockspire/shared/profile_paths.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_file_path_provider.g.dart';

/// Ruta del archivo de bóveda del perfil abierto (ADR 0039): el principal
/// conserva la de siempre; los demás, `profiles/<id>/`.
@Riverpod(keepAlive: true)
Future<String> vaultFilePath(Ref ref) async => vaultFilePathFor(
  await ref.watch(appDataDirectoryProvider.future),
  ref.watch(activeProfileIdProvider),
);
