// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/infrastructure/method_channel_app_icons.dart';

import '../../../support/fake_method_channel.dart';

/// El ícono de una app instalada, que Android entrega como PNG.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lo pide por el nombre del paquete', () async {
    final png = Uint8List.fromList([1, 2, 3]);
    final kotlin = FakeMethodChannel('com.lockspire.lockspire/app_icons')
      ..answer('getAppIcon', png);

    expect(await const MethodChannelAppIcons().iconFor('com.banco.app'), png);
    expect(kotlin.argumentsOf('getAppIcon'), {'package': 'com.banco.app'});
  });

  test('una app desinstalada es "sin ícono"', () async {
    FakeMethodChannel('com.lockspire.lockspire/app_icons').fail('getAppIcon');

    expect(await const MethodChannelAppIcons().iconFor('com.ya.no'), isNull);
  });
}
