// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/ports/native_messaging_registration_port.dart';
import 'extension_ids.dart';

/// Registra el native host para Chrome/Edge/Chromium (ADR 0013):
///
/// - Windows: manifest en `%LOCALAPPDATA%\Lockspire\native-messaging\` y
///   una clave `HKCU\Software\<navegador>\NativeMessagingHosts\<nombre>`
///   que apunta a él (vía `reg.exe`).
/// - Linux: manifest copiado en
///   `~/.config/<navegador>/NativeMessagingHosts/` de cada navegador cuyo
///   directorio de configuración exista.
///
/// El binario del host se busca junto al ejecutable de la app.
class NativeMessagingRegistrationAdapter
    implements NativeMessagingRegistrationPort {
  final String _appDirectory;
  final Map<String, String> _environment;

  NativeMessagingRegistrationAdapter({
    String? appDirectory,
    Map<String, String>? environment,
  }) : _appDirectory = appDirectory ?? p.dirname(Platform.resolvedExecutable),
       _environment = environment ?? Platform.environment;

  String get _hostBinaryPath => p.join(
    _appDirectory,
    Platform.isWindows ? 'lockspire-native-host.exe' : 'lockspire-native-host',
  );

  String _manifestJson() => const JsonEncoder.withIndent('  ').convert({
    'name': nativeHostName,
    'description': 'Lockspire native messaging host',
    'path': _hostBinaryPath,
    'type': 'stdio',
    'allowed_origins': [
      for (final id in allowedExtensionIds) 'chrome-extension://$id/',
    ],
  });

  @override
  Future<NativeMessagingStatus> status() async {
    final registered = <SupportedBrowser>{};
    if (Platform.isWindows) {
      final manifestPath = _windowsManifestPath();
      for (final browser in SupportedBrowser.values) {
        final value = await _regQueryDefault(_windowsRegistryKey(browser));
        if (value != null && p.equals(value, manifestPath)) {
          registered.add(browser);
        }
      }
    } else if (Platform.isLinux) {
      for (final browser in SupportedBrowser.values) {
        final file = File(_linuxManifestPath(browser));
        if (file.existsSync() && _pointsToThisHost(file.readAsStringSync())) {
          registered.add(browser);
        }
      }
    }
    return NativeMessagingStatus(
      hostBinaryFound: File(_hostBinaryPath).existsSync(),
      registeredIn: registered,
    );
  }

  bool _pointsToThisHost(String manifest) {
    try {
      final json = jsonDecode(manifest) as Map<String, Object?>;
      return json['path'] == _hostBinaryPath;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Set<SupportedBrowser>> register() async {
    if (!File(_hostBinaryPath).existsSync()) {
      throw StateError(
        'No se encontró el native host en $_hostBinaryPath. '
        'Compílalo e instálalo junto a la app (ver native-host/README.md).',
      );
    }
    final registered = <SupportedBrowser>{};
    if (Platform.isWindows) {
      final manifestPath = _windowsManifestPath();
      final file = File(manifestPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(_manifestJson(), flush: true);
      for (final browser in SupportedBrowser.values) {
        final result = await Process.run('reg', [
          'add',
          _windowsRegistryKey(browser),
          '/ve',
          '/t',
          'REG_SZ',
          '/d',
          manifestPath,
          '/f',
        ]);
        if (result.exitCode == 0) registered.add(browser);
      }
    } else if (Platform.isLinux) {
      for (final browser in SupportedBrowser.values) {
        // Solo en navegadores instalados (su directorio de configuración
        // existe): no se crean carpetas de navegadores ajenos.
        final configDir = Directory(_linuxConfigDir(browser));
        if (!configDir.existsSync()) continue;
        final file = File(_linuxManifestPath(browser));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(_manifestJson(), flush: true);
        registered.add(browser);
      }
    }
    return registered;
  }

  @override
  Future<void> unregister() async {
    if (Platform.isWindows) {
      for (final browser in SupportedBrowser.values) {
        await Process.run('reg', [
          'delete',
          _windowsRegistryKey(browser),
          '/f',
        ]);
      }
      final file = File(_windowsManifestPath());
      if (file.existsSync()) file.deleteSync();
    } else if (Platform.isLinux) {
      for (final browser in SupportedBrowser.values) {
        final file = File(_linuxManifestPath(browser));
        if (file.existsSync() && _pointsToThisHost(file.readAsStringSync())) {
          file.deleteSync();
        }
      }
    }
  }

  // --- Windows ---------------------------------------------------------

  String _windowsManifestPath() => p.join(
    _environment['LOCALAPPDATA'] ?? '',
    'Lockspire',
    'native-messaging',
    '$nativeHostName.json',
  );

  static String _windowsRegistryKey(SupportedBrowser browser) {
    final vendor = switch (browser) {
      SupportedBrowser.chrome => r'Google\Chrome',
      SupportedBrowser.edge => r'Microsoft\Edge',
      SupportedBrowser.chromium => 'Chromium',
    };
    return 'HKCU\\Software\\$vendor\\NativeMessagingHosts\\$nativeHostName';
  }

  static Future<String?> _regQueryDefault(String key) async {
    final result = await Process.run('reg', ['query', key, '/ve']);
    if (result.exitCode != 0) return null;
    // Línea: "    (Default)    REG_SZ    C:\...\x.json" (el nombre del
    // valor por defecto depende del idioma del sistema).
    for (final line in (result.stdout as String).split('\n')) {
      final index = line.indexOf('REG_SZ');
      if (index >= 0) return line.substring(index + 'REG_SZ'.length).trim();
    }
    return null;
  }

  // --- Linux -----------------------------------------------------------

  String _linuxConfigDir(SupportedBrowser browser) {
    final configHome =
        _environment['XDG_CONFIG_HOME'] ??
        p.join(_environment['HOME'] ?? '', '.config');
    final name = switch (browser) {
      SupportedBrowser.chrome => 'google-chrome',
      SupportedBrowser.edge => 'microsoft-edge',
      SupportedBrowser.chromium => 'chromium',
    };
    return p.join(configHome, name);
  }

  String _linuxManifestPath(SupportedBrowser browser) => p.join(
    _linuxConfigDir(browser),
    'NativeMessagingHosts',
    '$nativeHostName.json',
  );
}
