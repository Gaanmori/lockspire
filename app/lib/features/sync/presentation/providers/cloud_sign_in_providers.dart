// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/cloud_sign_in_port.dart';
import '../../infrastructure/cloud_sign_in_adapters.dart';
import '../../infrastructure/google_drive_desktop_auth.dart';
import 'google_drive_android_auth_provider.dart';
import 'google_drive_desktop_auth_provider.dart';
import 'microsoft_oauth_auth_provider.dart';

part 'cloud_sign_in_providers.g.dart';

/// Iniciar sesión en Google Drive: navegador en escritorio, el selector
/// del sistema en Android (A12).
@Riverpod(keepAlive: true)
CloudSignInPort googleDriveSignInPort(Ref ref) => usesDesktopGoogleAuth
    ? GoogleDriveDesktopSignIn(ref.watch(googleDriveDesktopAuthProvider))
    : GoogleDriveAndroidSignIn(ref.watch(googleDriveAndroidAuthProvider));

@Riverpod(keepAlive: true)
CloudSignInPort oneDriveSignInPort(Ref ref) =>
    OneDriveSignIn(ref.watch(microsoftOauthAuthProvider));
