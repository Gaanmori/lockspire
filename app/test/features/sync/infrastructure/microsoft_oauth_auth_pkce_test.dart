// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/infrastructure/microsoft_oauth_auth.dart';

void main() {
  group('codeChallengeFromVerifier (PKCE, RFC 7636)', () {
    test('reproduce el vector conocido de la RFC 7636 §B', () {
      // https://www.rfc-editor.org/rfc/rfc7636#appendix-B
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      const expectedChallenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';

      expect(codeChallengeFromVerifier(verifier), expectedChallenge);
    });

    test('nunca incluye padding "="', () {
      expect(
        codeChallengeFromVerifier('cualquier-verifier'),
        isNot(contains('=')),
      );
    });
  });
}
