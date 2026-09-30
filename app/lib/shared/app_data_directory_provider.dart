// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_data_directory_provider.g.dart';

/// Carpeta de los datos de la app. Se usa `getApplicationSupportDirectory()`
/// (no "Documents", que en algunas plataformas se sincroniza sola con la
/// nube del sistema).
@Riverpod(keepAlive: true)
Future<String> appDataDirectory(Ref ref) async =>
    (await getApplicationSupportDirectory()).path;
