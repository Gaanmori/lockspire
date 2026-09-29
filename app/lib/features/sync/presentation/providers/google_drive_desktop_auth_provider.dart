// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:googleapis_auth/googleapis_auth.dart' show ClientId;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../infrastructure/google_drive_desktop_auth.dart';
import '../../infrastructure/google_oauth_config.dart';

part 'google_drive_desktop_auth_provider.g.dart';

@Riverpod(keepAlive: true)
GoogleDriveDesktopAuth googleDriveDesktopAuth(Ref ref) {
  return GoogleDriveDesktopAuth(
    ClientId(GoogleOAuthConfig.clientId, GoogleOAuthConfig.clientSecret),
  );
}
