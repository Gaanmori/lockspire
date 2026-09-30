// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/appearance/infrastructure/method_channel_launcher_icon.dart';

import '../../../support/fake_method_channel.dart';

/// El ícono del lanzador de Android según el tema (alias de actividad).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pide el alias del tema elegido', () async {
    final kotlin = FakeMethodChannel('com.lockspire.lockspire/launcher_icon');

    await const MethodChannelLauncherIcon().useThemeIcon(ThemeFamilyId.mint);

    expect(kotlin.argumentsOf('setTheme'), {'theme': 'mint'});
  });

  test('si el sistema no lo cambia, la app sigue igual', () async {
    FakeMethodChannel('com.lockspire.lockspire/launcher_icon').fail('setTheme');

    await expectLater(
      const MethodChannelLauncherIcon().useThemeIcon(ThemeFamilyId.pixel),
      completes,
    );
  });
}
