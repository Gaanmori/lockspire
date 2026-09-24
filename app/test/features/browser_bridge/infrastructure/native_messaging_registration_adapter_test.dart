// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

@TestOn('windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/infrastructure/native_messaging_registration_adapter.dart';

/// Pasa [script] por el parser real de PowerShell (sin ejecutarlo) y
/// devuelve los errores de sintaxis.
Future<String> _parseErrors(String script) async {
  final encoded =
      NativeMessagingRegistrationAdapter.encodePowerShellCommandForTest(script);
  final checker =
      "\$s = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$encoded')); "
      '\$e = \$null; '
      '[void][System.Management.Automation.Language.Parser]::ParseInput(\$s, [ref]\$null, [ref]\$e); '
      r'($e | ForEach-Object { $_.Message }) -join "`n"';
  final result = await Process.run('powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    checker,
  ]);
  return (result.stdout as String).trim();
}

void main() {
  final adapter = NativeMessagingRegistrationAdapter(
    appDirectory: r'C:\Program Files\Lockspire',
    environment: {'ProgramData': r'C:\ProgramData', 'LOCALAPPDATA': r'C:\x'},
  );

  test('-EncodedCommand: base64 de UTF-16LE, ida y vuelta con acentos', () {
    const script = "Write-Output 'bóveda ñ'";
    final encoded =
        NativeMessagingRegistrationAdapter.encodePowerShellCommandForTest(
          script,
        );
    final bytes = base64.decode(encoded);
    final units = [
      for (var i = 0; i < bytes.length; i += 2) bytes[i] | (bytes[i + 1] << 8),
    ];
    expect(String.fromCharCodes(units), script);
  });

  test(
    'los scripts elevados de registrar y quitar son PowerShell válido',
    () async {
      for (final install in [true, false]) {
        final script = adapter.systemWideScriptForTest(install: install);
        expect(await _parseErrors(script), isEmpty, reason: 'install=$install');
      }
    },
  );

  test('el script de registro embebe el manifest con la ruta del host y '
      'solo el ID permitido', () {
    final script = adapter.systemWideScriptForTest(install: true);
    expect(
      script,
      contains(
        r'"path": "C:\\Program Files\\Lockspire\\lockspire-native-host.exe"',
      ),
    );
    expect(
      script,
      contains('chrome-extension://gmlibgaohpjlblfapahkkjcoohpdeofk/'),
    );
    expect(script, contains(r'SOFTWARE\Google\Chrome\NativeMessagingHosts'));
    expect(script, contains(r'SOFTWARE\Microsoft\Edge\NativeMessagingHosts'));
  });
}
