// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:googleapis_auth/googleapis_auth.dart' show ClientId;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../infrastructure/google_drive_windows_auth.dart';
import '../../infrastructure/google_oauth_config.dart';

part 'google_drive_windows_auth_provider.g.dart';

@Riverpod(keepAlive: true)
GoogleDriveWindowsAuth googleDriveWindowsAuth(Ref ref) {
  return GoogleDriveWindowsAuth(
    ClientId(GoogleOAuthConfig.clientId, GoogleOAuthConfig.clientSecret),
  );
}
