// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../domain/ports/cloud_sign_in_port.dart';
import 'google_drive_android_auth.dart';
import 'google_drive_desktop_auth.dart';
import 'microsoft_oauth_auth.dart';

/// Google Drive en Windows y Linux: navegador con loopback y refresh token
/// propio.
class GoogleDriveDesktopSignIn implements CloudSignInPort {
  final GoogleDriveDesktopAuth _auth;

  const GoogleDriveDesktopSignIn(this._auth);

  @override
  Future<CloudSignIn> connect() async {
    final connection = await _auth.connectInteractive();
    connection.httpClient.close();
    return CloudSignIn(
      email: connection.email,
      refreshToken: connection.refreshToken,
    );
  }

  @override
  Future<void> disconnect() async {}
}

/// Google Drive en Android: la sesión la guarda el sistema, así que
/// desconectar revoca el permiso de Drive.
class GoogleDriveAndroidSignIn implements CloudSignInPort {
  final GoogleDriveAndroidAuth _auth;

  const GoogleDriveAndroidSignIn(this._auth);

  @override
  Future<CloudSignIn> connect() async {
    final connection = await _auth.connectInteractive();
    return CloudSignIn(email: connection.email);
  }

  @override
  Future<void> disconnect() => _auth.disconnect();
}

/// OneDrive en todas las plataformas.
class OneDriveSignIn implements CloudSignInPort {
  final MicrosoftOAuthAuth _auth;

  const OneDriveSignIn(this._auth);

  @override
  Future<CloudSignIn> connect() async {
    final connection = await _auth.connectInteractive();
    return CloudSignIn(
      email: connection.email,
      refreshToken: connection.refreshToken,
    );
  }

  @override
  Future<void> disconnect() async {}
}
