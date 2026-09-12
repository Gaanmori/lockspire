// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../infrastructure/microsoft_oauth_auth.dart';
import '../../infrastructure/microsoft_oauth_config.dart';

part 'microsoft_oauth_auth_provider.g.dart';

/// Un solo provider, sin split de plataforma — ver
/// `microsoft_oauth_auth.dart` para el porqué (a diferencia de
/// `google_drive_android_auth_provider.dart`/
/// `google_drive_windows_auth_provider.dart`).
@Riverpod(keepAlive: true)
MicrosoftOAuthAuth microsoftOauthAuth(Ref ref) {
  return MicrosoftOAuthAuth(MicrosoftOAuthConfig.clientId);
}
