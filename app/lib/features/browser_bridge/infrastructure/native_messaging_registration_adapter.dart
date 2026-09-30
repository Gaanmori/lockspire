// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import '../domain/ports/native_messaging_registration_port.dart';
import 'extension_ids.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

/// Registra el native host para Chrome/Edge/Chromium (ADR 0013):
///
/// - Windows: manifest en `%LOCALAPPDATA%\Lockspire\native-messaging\` y
///   una clave `HKCU\Software\<navegador>\NativeMessagingHosts\<nombre>`
///   que apunta a él (vía `reg.exe`).
/// - Linux: manifest copiado en
///   `~/.config/<navegador>/NativeMessagingHosts/` de cada navegador cuyo
///   directorio de configuración exista.
///
/// El binario del host se busca junto al ejecutable de la app; en MSIX,
/// el manifest apunta a su alias de ejecución.
/// El sistema donde se registra el host: la rama de Windows (registro) o la
/// de Linux (archivos en la configuración del navegador).
enum HostPlatform { windows, linux, other }

/// Ejecuta un programa del sistema (`reg`, `powershell.exe`).
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class NativeMessagingRegistrationAdapter
    implements NativeMessagingRegistrationPort {
  final String _appDirectory;
  final Map<String, String> _environment;
  final HostPlatform _platform;
  final ProcessRunner _run;

  /// [platform] y [runProcess] son los del sistema por defecto; los tests
  /// los cambian para probar las dos ramas sin tocar el registro real.
  NativeMessagingRegistrationAdapter({
    String? appDirectory,
    Map<String, String>? environment,
    HostPlatform? platform,
    ProcessRunner? runProcess,
  }) : _appDirectory = appDirectory ?? p.dirname(Platform.resolvedExecutable),
       _environment = environment ?? Platform.environment,
       _platform = platform ?? _currentPlatform(),
       _run = runProcess ?? Process.run;

  static HostPlatform _currentPlatform() => Platform.isWindows
      ? HostPlatform.windows
      : Platform.isLinux
      ? HostPlatform.linux
      : HostPlatform.other;

  bool get _isWindows => _platform == HostPlatform.windows;
  bool get _isLinux => _platform == HostPlatform.linux;

  static const _windowsHostName = 'lockspire-native-host.exe';

  /// El binario del host tal como viene con la app.
  String get _bundledHostPath => p.join(
    _appDirectory,
    _isWindows ? _windowsHostName : 'lockspire-native-host',
  );

  /// Instalada como paquete MSIX (Microsoft Store, ADR 0035), la app vive en
  /// `C:\Program Files\WindowsApps`, donde Chrome y Edge no pueden ejecutar
  /// nada (acceso denegado).
  bool get _isMsixPackage =>
      _isWindows &&
      p.split(_appDirectory).any((part) => part.toLowerCase() == 'windowsapps');

  /// La ruta que lanza el navegador. En MSIX es el alias de ejecución que
  /// declara el paquete (AppxManifest.xml), que no cambia entre versiones.
  String get _hostBinaryPath => _isMsixPackage
      ? p.join(
          _environment['LOCALAPPDATA'] ?? '',
          'Microsoft',
          'WindowsApps',
          _windowsHostName,
        )
      : _bundledHostPath;

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
    final otherCopy = <SupportedBrowser>{};
    if (_isWindows) {
      // La clave de cada navegador apunta a un manifest, y el manifest al
      // host: cuenta como de esta app solo si las dos cosas coinciden.
      final manifestPath = _windowsManifestPath();
      final oursHere = _manifestPointsHere(manifestPath);
      for (final browser in SupportedBrowser.values) {
        final value = await _regQueryDefault(_windowsRegistryKey(browser));
        if (value == null) continue;
        if (p.equals(value, manifestPath) && oursHere) {
          registered.add(browser);
        } else {
          otherCopy.add(browser);
        }
      }
    } else if (_isLinux) {
      for (final browser in SupportedBrowser.values) {
        final file = File(_linuxManifestPath(browser));
        if (!file.existsSync()) continue;
        if (_pointsToThisHost(file.readAsStringSync())) {
          registered.add(browser);
        } else {
          otherCopy.add(browser);
        }
      }
    }
    final registeredSystemWide = <SupportedBrowser>{};
    final otherCopySystemWide = <SupportedBrowser>{};
    if (_isWindows) {
      final manifestPath = _windowsSystemManifestPath();
      final oursHere = _manifestPointsHere(manifestPath);
      for (final browser in SupportedBrowser.values) {
        final value = await _regQueryDefault(
          _windowsRegistryKey(browser, root: 'HKLM'),
          extraArgs: const ['/reg:64'],
        );
        if (value == null) continue;
        if (p.equals(value, manifestPath) && oursHere) {
          registeredSystemWide.add(browser);
        } else {
          otherCopySystemWide.add(browser);
        }
      }
    }
    return NativeMessagingStatus(
      hostBinaryFound: File(_bundledHostPath).existsSync(),
      registeredIn: registered,
      registeredSystemWideIn: registeredSystemWide,
      systemWideSupported: _isWindows,
      otherCopyIn: otherCopy,
      otherCopySystemWideIn: otherCopySystemWide,
    );
  }

  bool _manifestPointsHere(String manifestPath) {
    final manifest = File(manifestPath);
    return manifest.existsSync() &&
        _pointsToThisHost(manifest.readAsStringSync());
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
    if (!File(_bundledHostPath).existsSync()) {
      throw AppProblem(
        AppProblemCode.nativeHostMissing,
        detail: _bundledHostPath,
      );
    }
    final registered = <SupportedBrowser>{};
    if (_isWindows) {
      final manifestPath = _windowsManifestPath();
      final file = File(manifestPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(_manifestJson(), flush: true);
      for (final browser in SupportedBrowser.values) {
        final result = await _run('reg', [
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
    } else if (_isLinux) {
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
    if (_isWindows) {
      for (final browser in SupportedBrowser.values) {
        await _run('reg', ['delete', _windowsRegistryKey(browser), '/f']);
      }
      final file = File(_windowsManifestPath());
      if (file.existsSync()) file.deleteSync();
    } else if (_isLinux) {
      for (final browser in SupportedBrowser.values) {
        final file = File(_linuxManifestPath(browser));
        if (file.existsSync() && _pointsToThisHost(file.readAsStringSync())) {
          file.deleteSync();
        }
      }
    }
  }

  @override
  Future<void> registerSystemWide() async {
    if (!_isWindows) {
      throw const AppProblem(AppProblemCode.nativeHostWindowsOnly);
    }
    if (!File(_bundledHostPath).existsSync()) {
      throw AppProblem(
        AppProblemCode.nativeHostMissing,
        detail: _bundledHostPath,
      );
    }
    await _runElevated(_systemWideScript(install: true));
  }

  @override
  Future<void> unregisterSystemWide() async {
    if (!_isWindows) {
      throw const AppProblem(AppProblemCode.nativeHostWindowsOnly);
    }
    await _runElevated(_systemWideScript(install: false));
  }

  /// Script de PowerShell que se ejecuta elevado (ADR 0014). Escribe el
  /// manifest en `%ProgramData%\Lockspire\native-messaging\` con una ACL
  /// explícita (Administradores y SYSTEM control total, Usuarios solo
  /// lectura, sin herencia) y registra la clave `HKLM` de cada navegador
  /// en las vistas de 64 y 32 bits del registro.
  String _systemWideScript({required bool install}) {
    final keys = [
      for (final browser in SupportedBrowser.values)
        "'${_windowsRegistrySubkey(browser)}'",
    ].join(', ');
    final manifestJson = _manifestJson();
    return '''
\$ErrorActionPreference = 'Stop'
\$dir = Join-Path \$env:ProgramData 'Lockspire\\native-messaging'
\$path = Join-Path \$dir '$nativeHostName.json'
\$keys = @($keys)
\$views = @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)
if (${install ? r'$true' : r'$false'}) {
  New-Item -ItemType Directory -Force -Path \$dir | Out-Null
  & icacls.exe \$dir /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
  if (\$LASTEXITCODE -ne 0) { throw 'icacls falló' }
  [System.IO.File]::WriteAllText(\$path, @'
$manifestJson
'@, (New-Object System.Text.UTF8Encoding \$false))
  foreach (\$view in \$views) {
    \$base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, \$view)
    foreach (\$k in \$keys) {
      \$key = \$base.CreateSubKey(\$k)
      \$key.SetValue('', \$path)
      \$key.Close()
    }
    \$base.Close()
  }
} else {
  foreach (\$view in \$views) {
    \$base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, \$view)
    foreach (\$k in \$keys) { \$base.DeleteSubKeyTree(\$k, \$false) }
    \$base.Close()
  }
  if (Test-Path \$path) { Remove-Item -Force \$path }
}
''';
  }

  /// Ejecuta [script] como administrador (diálogo de UAC). El script va
  /// en línea con `-EncodedCommand`, nunca en un archivo temporal: un
  /// archivo en `%TEMP%` podría modificarlo cualquier proceso del usuario
  /// entre que se escribe y Windows lo ejecuta elevado (escalada de
  /// privilegios).
  Future<void> _runElevated(String script) async {
    final encoded = _encodePowerShellCommand(script);
    final launcher =
        "\$p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait "
        "-PassThru -WindowStyle Hidden -ArgumentList '-NoProfile', "
        "'-NonInteractive', '-EncodedCommand', '$encoded'; "
        'exit \$p.ExitCode';
    final result = await _run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      launcher,
    ]);
    if (result.exitCode != 0) {
      throw const AppProblem(AppProblemCode.nativeHostElevationCancelled);
    }
  }

  @visibleForTesting
  String systemWideScriptForTest({required bool install}) =>
      _systemWideScript(install: install);

  @visibleForTesting
  static String encodePowerShellCommandForTest(String script) =>
      _encodePowerShellCommand(script);

  /// `-EncodedCommand` espera base64 de UTF-16LE.
  static String _encodePowerShellCommand(String script) {
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes
        ..add(unit & 0xff)
        ..add(unit >> 8);
    }
    return base64.encode(bytes);
  }

  // --- Windows ---------------------------------------------------------

  String _windowsSystemManifestPath() => p.join(
    _environment['ProgramData'] ?? r'C:\ProgramData',
    'Lockspire',
    'native-messaging',
    '$nativeHostName.json',
  );

  String _windowsManifestPath() => p.join(
    _environment['LOCALAPPDATA'] ?? '',
    'Lockspire',
    'native-messaging',
    '$nativeHostName.json',
  );

  static String _windowsRegistrySubkey(SupportedBrowser browser) {
    final vendor = switch (browser) {
      SupportedBrowser.chrome => r'Google\Chrome',
      SupportedBrowser.edge => r'Microsoft\Edge',
      SupportedBrowser.chromium => 'Chromium',
    };
    return 'SOFTWARE\\$vendor\\NativeMessagingHosts\\$nativeHostName';
  }

  static String _windowsRegistryKey(
    SupportedBrowser browser, {
    String root = 'HKCU',
  }) => '$root\\${_windowsRegistrySubkey(browser)}';

  Future<String?> _regQueryDefault(
    String key, {
    List<String> extraArgs = const [],
  }) async {
    final result = await _run('reg', ['query', key, '/ve', ...extraArgs]);
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
