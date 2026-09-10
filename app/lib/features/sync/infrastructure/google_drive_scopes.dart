// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Scope no sensible — acceso solo a la carpeta oculta de datos de la app
/// (`appDataFolder`), invisible en el Drive normal del usuario. Ver
/// docs/STATE.md (Fase 8) para la decisión de producto.
const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

/// Scope adicional, solo usado en el flujo de Windows (ver
/// `google_drive_windows_auth.dart`) para poder mostrar qué cuenta está
/// conectada — en Android ese dato viene directo de `GoogleSignInAccount`,
/// no hace falta pedirlo aparte.
const driveUserInfoEmailScope =
    'https://www.googleapis.com/auth/userinfo.email';
