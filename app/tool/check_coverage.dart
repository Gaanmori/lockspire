// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

// Piso de cobertura para dominio, aplicación, infraestructura y
// presentación. Lee coverage/lcov.info (de `flutter test --coverage`),
// imprime la cobertura por capa y termina con error si alguna de esas cuatro
// baja de [minimum]. Los adaptadores de plataforma se prueban con el lado
// nativo simulado (canales, servidores HTTP y D-Bus en memoria).
//
//     dart run tool/check_coverage.dart [mínimo, por defecto 90]

import 'dart:io';

void main(List<String> args) {
  final minimum = args.isEmpty ? 90.0 : double.parse(args.first);
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln(
      'Falta coverage/lcov.info: correr `flutter test --coverage`.',
    );
    exit(2);
  }

  final hit = <String, int>{};
  final total = <String, int>{};
  String? layer;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).replaceAll(r'\', '/');
      layer = path.endsWith('.g.dart') || path.contains('/generated/')
          ? null
          : _layerOf(path);
    } else if (line.startsWith('DA:') && layer != null) {
      final count = int.parse(line.split(',')[1]);
      total[layer] = (total[layer] ?? 0) + 1;
      if (count > 0) hit[layer] = (hit[layer] ?? 0) + 1;
    }
  }

  var failed = false;
  for (final layer in (total.keys.toList()..sort())) {
    final percent = 100 * (hit[layer] ?? 0) / total[layer]!;
    final gated = const {
      'domain',
      'application',
      'infrastructure',
      'presentation',
    }.contains(layer);
    final ok = !gated || percent >= minimum;
    failed |= !ok;
    stdout.writeln(
      '${layer.padRight(15)} ${percent.toStringAsFixed(1).padLeft(5)} %'
      '${gated ? '  (mínimo ${minimum.toStringAsFixed(0)} %)' : ''}'
      '${ok ? '' : '  <- por debajo'}',
    );
  }
  if (failed) exit(1);
}

/// `lib/features/<feature>/<capa>/...` → la capa; lo demás, "otros".
String _layerOf(String path) {
  final match = RegExp(r'lib/features/[^/]+/([^/]+)/').firstMatch(path);
  return match?.group(1) ?? 'otros';
}
