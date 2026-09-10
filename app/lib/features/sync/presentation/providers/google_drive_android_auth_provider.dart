// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../infrastructure/google_drive_android_auth.dart';

part 'google_drive_android_auth_provider.g.dart';

@Riverpod(keepAlive: true)
GoogleDriveAndroidAuth googleDriveAndroidAuth(Ref ref) {
  return GoogleDriveAndroidAuth();
}
