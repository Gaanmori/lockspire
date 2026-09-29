// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/widgets.dart';

/// Cierra la pantalla (o el diálogo) de [context] solo si su ruta sigue
/// siendo la de arriba.
///
/// Tras un `await` no alcanza con `mounted`: si mientras tanto la bóveda se
/// bloqueó (por inactividad o al pasar a segundo plano, ADR 0008), `MyApp`
/// ya cerró todas las pantallas, y la de [context] sigue montada un
/// instante. Un `Navigator.pop` ahí se llevaba la pantalla de abajo, hasta
/// la raíz, y la app quedaba en blanco (encontrado por un test de flujo,
/// 2026-09-29: importar, ir a borrar el archivo como pide el aviso, volver).
void popIfCurrent(BuildContext context) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route != null && route.isCurrent) Navigator.of(context).pop();
}
