// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseResponse } from '../src/protocol.ts';
import { themeName } from '../src/theme.ts';

test('themeName: modo fijo ignora el sistema; system lo sigue', () => {
  assert.equal(themeName({ family: 'menta', mode: 'light' }, true), 'menta-light');
  assert.equal(themeName({ family: 'menta', mode: 'dark' }, false), 'menta-dark');
  assert.equal(themeName({ family: 'lavanda', mode: 'system' }, true), 'lavanda-dark');
  assert.equal(themeName({ family: 'calido', mode: 'system' }, false), 'calido-light');
});

test('"Colores del sistema" se muestra como Cálido en el popup', () => {
  assert.equal(themeName({ family: 'sistema', mode: 'dark' }, false), 'lineage-dark');
  assert.equal(themeName({ family: 'lineage', mode: 'light' }, true), 'lineage-light');
});

test('PONG con tema válido lo expone; desconocido o ausente se ignora', () => {
  const pong = (theme: unknown) =>
    parseResponse({ v: 1, id: 'a', type: 'PONG', locked: false, theme }, 'a');

  assert.deepEqual(pong({ family: 'menta', mode: 'dark' }), {
    type: 'PONG',
    locked: false,
    theme: { family: 'menta', mode: 'dark' },
  });
  for (const bad of [undefined, null, 'menta', { family: 'neon', mode: 'dark' }, { family: 'menta' }]) {
    assert.deepEqual(pong(bad), { type: 'PONG', locked: false }, JSON.stringify(bad));
  }
});
