// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseResponse } from '../src/protocol.ts';
import { themeName } from '../src/theme.ts';

test('themeName: modo fijo ignora el sistema; system lo sigue', () => {
  assert.equal(themeName({ family: 'mint', mode: 'light' }, true), 'mint-light');
  assert.equal(themeName({ family: 'mint', mode: 'dark' }, false), 'mint-dark');
  assert.equal(themeName({ family: 'windows', mode: 'system' }, true), 'windows-dark');
  assert.equal(themeName({ family: 'ubuntu', mode: 'system' }, false), 'ubuntu-light');
});

test('"Colores del sistema" se muestra como Cálido en el popup', () => {
  assert.equal(themeName({ family: 'sistema', mode: 'dark' }, false), 'lineage-dark');
  assert.equal(themeName({ family: 'lineage', mode: 'light' }, true), 'lineage-light');
  assert.equal(themeName({ family: 'pixel', mode: 'system' }, true), 'pixel-dark');
});

test('PONG con tema válido lo expone; desconocido o ausente se ignora', () => {
  const pong = (theme: unknown) =>
    parseResponse({ v: 1, id: 'a', type: 'PONG', locked: false, theme }, 'a');

  assert.deepEqual(pong({ family: 'mint', mode: 'dark' }), {
    type: 'PONG',
    locked: false,
    theme: { family: 'mint', mode: 'dark' },
  });
  for (const bad of [undefined, null, 'mint', { family: 'neon', mode: 'dark' }, { family: 'mint' }]) {
    assert.deepEqual(pong(bad), { type: 'PONG', locked: false }, JSON.stringify(bad));
  }
});

test('iconColorsFor: cada tema con su acento; sistema y desconocidos, Lineage', async () => {
  const { iconColorsFor } = await import('../src/icon.ts');
  assert.deepEqual(iconColorsFor('ubuntu'), ['#e95420', '#fafafa', '#c7461a']);
  assert.deepEqual(iconColorsFor('sistema'), iconColorsFor('lineage'));
  assert.deepEqual(iconColorsFor('neon'), iconColorsFor('lineage'));
});
