// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/about/infrastructure/package_info_adapter.dart';
import 'package:lockspire/features/about/infrastructure/url_launcher_link_adapter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../support/fake_method_channel.dart';

/// "Acerca de": la versión instalada y los enlaces externos (código
/// fuente, política de privacidad).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la versión y el número de compilación son los de la app '
      'instalada', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Lockspire',
      packageName: 'com.lockspire.lockspire',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );

    final version = await const PackageInfoAdapter().version();

    expect(version.version, '1.2.3');
    expect(version.build, '45');
  });

  test('los enlaces abren en el navegador del sistema, no dentro de la '
      'app', () async {
    final launcher = FakeMethodChannel('plugins.flutter.io/url_launcher')
      ..answer('launch', true);

    final opened = await const UrlLauncherLinkAdapter().open(
      Uri.parse('https://gaanmori.github.io/lockspire/privacy-policy'),
    );

    expect(opened, isTrue);
    final arguments = launcher.argumentsOf('launch') as Map;
    expect(
      arguments['url'],
      'https://gaanmori.github.io/lockspire/privacy-policy',
    );
    expect(arguments['useWebView'], isFalse);
  });
}
