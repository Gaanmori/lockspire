// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lockspire/app_composition.dart';
import 'package:lockspire/features/clipboard/presentation/providers/clipboard_guard_provider.dart';
import 'package:lockspire/features/desktop/presentation/providers/is_desktop_shell_provider.dart';
import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';
import 'package:lockspire/features/vault/presentation/providers/biometric_auth_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_file_path_provider.dart';
import 'package:lockspire/main.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../test/support/app_robot.dart';
import '../test/support/fakes/fake_secure_clipboard.dart';
import '../test/support/fakes/vault_fakes.dart';

/// De punta a punta con lo real: libsodium (Argon2id con los parámetros por
/// defecto y XChaCha20-Poly1305) y el archivo de bóveda en disco con
/// escritura atómica. Solo se cambian la biometría (no hay huella en CI),
/// el portapapeles y el almacenamiento seguro del sistema.
///
/// Corre en un dispositivo o en el escritorio, no con `flutter test` a secas:
///
///     flutter test integration_test/app_real_crypto_flow_test.dart -d windows
///     xvfb-run flutter test integration_test/app_real_crypto_flow_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lockspire_e2e_');
    // Idioma de la app fijado en español (preferencia de Apariencia, ADR
    // 0032): el robot usa los textos en español y el sistema de la CI está
    // en inglés.
    FlutterSecureStorage.setMockInitialValues({'appearance.language': 'es'});
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpApp(WidgetTester tester, String vaultPath) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          ...appOverrides(),
          vaultFilePathProvider.overrideWith((ref) async => vaultPath),
          isDesktopShellProvider.overrideWith((ref) => false),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              isDesktop: false,
              isAndroid: false,
              biometricMethod: BiometricMethod.fingerprint,
            ),
          ),
          biometricAuthPortProvider.overrideWith(
            (ref) =>
                FakeBiometricAuthPort()
                  ..available = BiometricAvailability.unavailable,
          ),
          secureClipboardPortProvider.overrideWithValue(FakeSecureClipboard()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('crear la bóveda, guardar una entrada, cerrar la app y volver '
      'a abrirla con la contraseña maestra', (tester) async {
    const master = 'correcto caballo batería grapa';
    final vaultPath = '${dir.path}${Platform.pathSeparator}vault.lockspire';
    final robot = AppRobot(tester);

    await pumpApp(tester, vaultPath);
    await robot.createVault(master);
    await robot.waitFor(find.byTooltip('Agregar'));
    await robot.addPassword(title: 'Banco', username: 'ana');
    await robot.waitFor(find.text('Banco'));

    // El archivo está cifrado: ni el título ni el usuario en claro.
    final bytes = File(vaultPath).readAsBytesSync();
    final asText = String.fromCharCodes(bytes);
    expect(asText, isNot(contains('Banco')));
    expect(asText, isNot(contains('ana')));

    // "Volver a abrir la app" sobre el mismo archivo.
    await pumpApp(tester, vaultPath);
    await robot.waitFor(find.text('¡Hola de nuevo!'));
    await robot.unlock('no es esta');
    await robot.waitFor(find.text('Contraseña incorrecta'));
    await robot.unlock(master);
    await robot.waitFor(find.text('Banco'));
  });
}
