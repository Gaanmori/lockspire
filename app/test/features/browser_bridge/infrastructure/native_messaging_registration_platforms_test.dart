// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/domain/ports/native_messaging_registration_port.dart';
import 'package:lockspire/features/browser_bridge/infrastructure/native_messaging_registration_adapter.dart';
import 'package:lockspire/shared/domain/app_problem.dart';
import 'package:path/path.dart' as p;

/// El registro de Windows en memoria, a través de `reg.exe`, y
/// `powershell.exe` para la elevación (ADR 0014).
class _FakeWindows {
  final registry = <String, String>{};
  final commands = <List<String>>[];

  /// Código de salida del PowerShell elevado: 1 = el usuario canceló.
  int elevationExitCode = 0;

  Future<ProcessResult> run(String executable, List<String> args) async {
    commands.add([executable, ...args]);
    if (executable == 'powershell.exe') {
      return ProcessResult(0, elevationExitCode, '', '');
    }
    expect(executable, 'reg');
    final key = args[1];
    switch (args.first) {
      case 'add':
        registry[key] = args[args.indexOf('/d') + 1];
        return ProcessResult(0, 0, '', '');
      case 'query':
        final value = registry[key];
        return value == null
            ? ProcessResult(0, 1, '', 'no existe')
            : ProcessResult(
                0,
                0,
                '\r\n$key\r\n    (Predeterminado)    REG_SZ    $value\r\n',
                '',
              );
      case 'delete':
        registry.remove(key);
        return ProcessResult(0, 0, '', '');
    }
    return ProcessResult(0, 1, '', '');
  }
}

String _chromeKey(String root) =>
    '$root\\SOFTWARE\\Google\\Chrome\\NativeMessagingHosts\\com.lockspire.native_host';

void main() {
  late Directory tmp;
  late String appDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('lockspire_nm_');
    appDir = p.join(tmp.path, 'app');
    Directory(appDir).createSync();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  void installHost(String name) =>
      File(p.join(appDir, name)).writeAsStringSync('binario');

  group('Windows (registro, ADR 0013)', () {
    late _FakeWindows windows;
    late NativeMessagingRegistrationAdapter adapter;

    setUp(() {
      windows = _FakeWindows();
      adapter = NativeMessagingRegistrationAdapter(
        appDirectory: appDir,
        environment: {
          'LOCALAPPDATA': p.join(tmp.path, 'local'),
          'ProgramData': p.join(tmp.path, 'programdata'),
        },
        platform: HostPlatform.windows,
        runProcess: windows.run,
      );
    });

    test('sin el host junto a la app no registra nada', () async {
      final status = await adapter.status();

      expect(status.hostBinaryFound, isFalse);
      await expectLater(
        adapter.register(),
        throwsA(
          isA<AppProblem>().having(
            (e) => e.code,
            'code',
            AppProblemCode.nativeHostMissing,
          ),
        ),
      );
    });

    test('registrar escribe el manifest y lo apunta en el registro de cada '
        'navegador; desregistrar lo quita', () async {
      installHost('lockspire-native-host.exe');

      final registered = await adapter.register();

      expect(registered, SupportedBrowser.values.toSet());
      final manifestPath = windows.registry[_chromeKey('HKCU')]!;
      final manifest = jsonDecode(File(manifestPath).readAsStringSync()) as Map;
      expect(manifest['path'], p.join(appDir, 'lockspire-native-host.exe'));
      expect(manifest['type'], 'stdio');
      expect(
        (manifest['allowed_origins'] as List).single,
        startsWith('chrome-extension://'),
      );
      final status = await adapter.status();
      expect(status.registeredIn, SupportedBrowser.values.toSet());
      expect(status.systemWideSupported, isTrue);

      await adapter.unregister();
      expect(windows.registry, isEmpty);
      expect(File(manifestPath).existsSync(), isFalse);
      expect((await adapter.status()).registeredIn, isEmpty);
    });

    test('un registro que apunta a otra instalación no cuenta como '
        'conectado', () async {
      installHost('lockspire-native-host.exe');
      windows.registry[_chromeKey('HKCU')] = r'C:\otra\instalacion.json';

      final status = await adapter.status();
      expect(status.registeredIn, isEmpty);
      expect(status.otherCopyIn, {SupportedBrowser.chrome});
    });

    test('si otra copia reescribió el manifest, el navegador usa esa: se '
        'avisa aunque la clave apunte al manifest de siempre', () async {
      installHost('lockspire-native-host.exe');
      await adapter.register();
      final manifest = File(windows.registry[_chromeKey('HKCU')]!);
      manifest.writeAsStringSync(
        jsonEncode({'path': r'C:\build\Debug\lockspire-native-host.exe'}),
      );

      final status = await adapter.status();

      expect(status.registeredIn, isEmpty);
      expect(status.otherCopyIn, SupportedBrowser.values.toSet());
    });

    test('un registro para todo el equipo de otra copia (p. ej. Debug) se '
        'avisa (encontrado por el usuario, 2026-09-30)', () async {
      installHost('lockspire-native-host.exe');
      final systemManifest = File(
        p.join(
          tmp.path,
          'programdata',
          'Lockspire',
          'native-messaging',
          'com.lockspire.native_host.json',
        ),
      )..createSync(recursive: true);
      systemManifest.writeAsStringSync(
        jsonEncode({'path': r'C:\build\Debug\lockspire-native-host.exe'}),
      );
      windows.registry[_chromeKey('HKLM')] = systemManifest.path;

      final status = await adapter.status();

      expect(status.registeredSystemWideIn, isEmpty);
      expect(status.otherCopySystemWideIn, {SupportedBrowser.chrome});
    });

    test('para todo el equipo pide permisos de administrador; si se cancelan, '
        'lo dice', () async {
      installHost('lockspire-native-host.exe');

      await adapter.registerSystemWide();
      final elevated = windows.commands.last;
      expect(elevated.first, 'powershell.exe');
      expect(elevated.join(' '), contains('-Verb RunAs'));

      windows.elevationExitCode = 1;
      await expectLater(
        adapter.unregisterSystemWide(),
        throwsA(
          isA<AppProblem>().having(
            (e) => e.code,
            'code',
            AppProblemCode.nativeHostElevationCancelled,
          ),
        ),
      );
    });

    test('el estado para todo el equipo mira el manifest de ProgramData y el '
        'registro de la máquina', () async {
      installHost('lockspire-native-host.exe');
      final systemManifest = File(
        p.join(
          tmp.path,
          'programdata',
          'Lockspire',
          'native-messaging',
          'com.lockspire.native_host.json',
        ),
      )..createSync(recursive: true);
      systemManifest.writeAsStringSync(
        jsonEncode({'path': p.join(appDir, 'lockspire-native-host.exe')}),
      );
      windows.registry[_chromeKey('HKLM')] = systemManifest.path;

      final status = await adapter.status();

      expect(status.registeredSystemWideIn, {SupportedBrowser.chrome});
    });
  });

  group('Linux (archivos en la configuración del navegador)', () {
    late NativeMessagingRegistrationAdapter adapter;
    late String config;

    setUp(() {
      config = p.join(tmp.path, 'config');
      adapter = NativeMessagingRegistrationAdapter(
        appDirectory: appDir,
        environment: {'XDG_CONFIG_HOME': config},
        platform: HostPlatform.linux,
        runProcess: (_, _) async => fail('en Linux no se ejecuta nada'),
      );
      installHost('lockspire-native-host');
    });

    test('registra solo en los navegadores instalados, y desregistrar borra '
        'solo sus propios manifests', () async {
      Directory(p.join(config, 'google-chrome')).createSync(recursive: true);
      Directory(p.join(config, 'chromium')).createSync(recursive: true);

      final registered = await adapter.register();

      expect(registered, {SupportedBrowser.chrome, SupportedBrowser.chromium});
      expect((await adapter.status()).registeredIn, registered);
      expect((await adapter.status()).systemWideSupported, isFalse);

      // Un manifest ajeno (otra app u otra instalación) no se toca.
      final foreign = File(
        p.join(
          config,
          'chromium',
          'NativeMessagingHosts',
          'com.lockspire.native_host.json',
        ),
      )..writeAsStringSync(jsonEncode({'path': '/opt/otra/host'}));
      expect((await adapter.status()).otherCopyIn, {SupportedBrowser.chromium});
      await adapter.unregister();

      expect(foreign.existsSync(), isTrue);
      expect((await adapter.status()).registeredIn, isEmpty);
    });

    test('para todo el equipo solo existe en Windows', () async {
      await expectLater(
        adapter.registerSystemWide(),
        throwsA(
          isA<AppProblem>().having(
            (e) => e.code,
            'code',
            AppProblemCode.nativeHostWindowsOnly,
          ),
        ),
      );
    });
  });
}
