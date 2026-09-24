// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { filterEntries } from '../src/filter.ts';

const entries = [
  { entryId: '1', title: 'Facebook', username: 'ana@correo.com' },
  { entryId: '2', title: 'Banco Nación', username: 'ana' },
  { entryId: '3', title: 'Correo trabajo', username: 'ana@empresa.com' },
];

const ids = (list: { entryId: string }[]) => list.map((e) => e.entryId);

test('consulta vacía devuelve todas', () => {
  assert.deepEqual(ids(filterEntries(entries, '   ')), ['1', '2', '3']);
});

test('filtra por título o usuario, sin mayúsculas ni acentos', () => {
  assert.deepEqual(ids(filterEntries(entries, 'FACE')), ['1']);
  assert.deepEqual(ids(filterEntries(entries, 'nacion')), ['2']);
  assert.deepEqual(ids(filterEntries(entries, 'empresa')), ['3']);
  assert.deepEqual(ids(filterEntries(entries, 'correo')), ['1', '3']);
});

test('todas las palabras tienen que aparecer', () => {
  assert.deepEqual(ids(filterEntries(entries, 'correo trabajo')), ['3']);
  assert.deepEqual(ids(filterEntries(entries, 'banco facebook')), []);
});
