// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../design/lockspire_icon.dart';

/// Escribe el ícono de Lockspire con los colores del tema elegido y
/// devuelve su ruta: `.ico` en Windows (ventana, barra de tareas y bandeja
/// lo exigen) y `.png` en Linux. Queda en la carpeta de soporte de la app,
/// con el color en el nombre: cambiar de tema y volver no lo regenera.
Future<String> writeThemedAppIcon(LockspireIconColors colors) async {
  final dir = Directory(
    '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}icons',
  );
  await dir.create(recursive: true);
  final id = [
    colors.background,
    colors.glyph,
    colors.keyhole,
  ].map((c) => c.toARGB32().toRadixString(16)).join('-');

  if (Platform.isWindows) {
    final file = File('${dir.path}${Platform.pathSeparator}lockspire-$id.ico');
    if (!await file.exists()) {
      final pngs = {
        for (final size in const [16, 24, 32, 48, 64, 256])
          size: await renderLockspireIconPng(colors, size),
      };
      await file.writeAsBytes(buildIco(pngs), flush: true);
    }
    return file.path;
  }
  final file = File('${dir.path}${Platform.pathSeparator}lockspire-$id.png');
  if (!await file.exists()) {
    await file.writeAsBytes(
      await renderLockspireIconPng(colors, 256),
      flush: true,
    );
  }
  return file.path;
}
