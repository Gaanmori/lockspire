// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Nombre del native host (`name` del manifest; lo usa la extensión en
/// `chrome.runtime.sendNativeMessage`).
const nativeHostName = 'com.lockspire.native_host';

/// IDs de la extensión autorizados a lanzar el host (`allowed_origins`).
///
/// - `gmlibgaohpjlblfapahkkjcoohpdeofk`: build de desarrollo, fijado por
///   la clave pública (`key`) de `extension/public/manifest.json`. La clave
///   privada no existe en el repo (ADR 0013).
///
/// Cuando se publique en la Chrome Web Store, su ID (distinto) se añade
/// aquí.
const allowedExtensionIds = ['gmlibgaohpjlblfapahkkjcoohpdeofk'];
