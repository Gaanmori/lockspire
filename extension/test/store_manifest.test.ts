// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { storeManifest } from '../store_manifest.mjs';

const manifest = JSON.parse(
  readFileSync(new URL('../public/manifest.json', import.meta.url), 'utf8'),
);

test('el paquete de las tiendas no lleva la clave del build de desarrollo', () => {
  assert.ok('key' in manifest, 'el build de desarrollo fija su ID con key');
  const store = storeManifest(manifest);
  assert.equal('key' in store, false);
});

test('el resto del manifest queda igual', () => {
  const { key: _key, ...expected } = manifest;
  assert.deepEqual(storeManifest(manifest), expected);
  assert.equal(manifest.manifest_version, 3);
});
