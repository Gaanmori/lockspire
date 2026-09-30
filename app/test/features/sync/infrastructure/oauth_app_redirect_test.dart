// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/infrastructure/oauth_app_redirect.dart';

import '../../../support/fake_method_channel.dart';

/// La vuelta del inicio de sesión por la dirección propia de la app en
/// Android (ADR 0022), que entrega `OAuthRedirectActivity`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('llega como dirección; lo que no es una redirección se '
      'ignora', () async {
    final redirect = AndroidOAuthAppRedirect();
    final kotlin = FakeMethodChannel('com.lockspire.lockspire/oauth_redirect');
    final arrived = <Uri>[];
    final subscription = redirect.redirects.listen(arrived.add);
    addTearDown(subscription.cancel);

    await kotlin.emit('otro', 'com.lockspire.lockspire://nada');
    await kotlin.emit(
      'redirect',
      'com.lockspire.lockspire://oauth2redirect?code=c1&state=s1',
    );
    await pumpEventQueue();

    expect(redirect.redirectUri, 'com.lockspire.lockspire://oauth2redirect');
    expect(arrived.single.queryParameters, {'code': 'c1', 'state': 's1'});
  });
}
