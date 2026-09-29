// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/design/lockspire_icon.dart';

import '../domain/ports/themed_icon_file_port.dart';
import 'themed_app_icon.dart';

/// [ThemedIconFilePort] sobre [writeThemedAppIcon] (.ico en Windows, .png en
/// Linux, en la carpeta de datos de la app).
class ThemedIconFileAdapter implements ThemedIconFilePort {
  const ThemedIconFileAdapter();

  @override
  Future<String> write(LockspireIconColors colors) =>
      writeThemedAppIcon(colors);
}
