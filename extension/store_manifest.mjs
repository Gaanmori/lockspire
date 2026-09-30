// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

// El manifest para subir a Chrome Web Store y Edge Add-ons. Sin `key`: esa
// clave pública solo fija el ID del build de desarrollo (ADR 0013); cada
// tienda asigna el suyo, que luego va en `allowedExtensionIds` de la app.
export function storeManifest(manifest) {
  const { key: _devKey, ...rest } = manifest;
  return rest;
}
