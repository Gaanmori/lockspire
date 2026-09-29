// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/appearance/domain/ports/system_accent_color_port.dart';

/// Color de acento del sistema; `null`: el sistema no da uno (se usa
/// Lineage en "Colores del sistema").
class FakeSystemAccent implements SystemAccentColorPort {
  final int? argb;

  const FakeSystemAccent([this.argb]);

  @override
  Future<int?> accentColorArgb() async => argb;
}
