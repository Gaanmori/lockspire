// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

export function storeManifest<T extends { key?: string }>(
  manifest: T,
): Omit<T, 'key'>;
