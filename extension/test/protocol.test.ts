// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseResponse, ProtocolError, webOrigin } from '../src/protocol.ts';

test('parsea respuestas válidas correlacionadas', () => {
  assert.deepEqual(parseResponse({ v: 1, id: 'a', type: 'PONG', locked: true }, 'a'), {
    type: 'PONG',
    locked: true,
  });
  assert.deepEqual(
    parseResponse(
      {
        v: 1,
        id: 'a',
        type: 'CREDENTIALS',
        entries: [{ entry_id: 'e1', title: 'GitHub', username: 'ana' }],
      },
      'a',
    ),
    { type: 'CREDENTIALS', entries: [{ entryId: 'e1', title: 'GitHub', username: 'ana' }] },
  );
  assert.deepEqual(parseResponse({ v: 1, type: 'ERROR', code: 'BAD_REQUEST' }, 'a'), {
    type: 'ERROR',
    code: 'BAD_REQUEST',
  });
});

test('rechaza respuestas de otra petición, otra versión o con forma rara', () => {
  const bad: unknown[] = [
    null,
    [],
    { v: 1, id: 'otro', type: 'PONG', locked: true },
    { v: 2, id: 'a', type: 'PONG', locked: true },
    { v: 1, id: 'a', type: 'PONG', locked: 'no' },
    { v: 1, id: 'a', type: 'CREDENTIALS', entries: {} },
    { v: 1, id: 'a', type: 'CREDENTIALS', entries: [{ entry_id: 1, title: 't', username: 'u' }] },
    { v: 1, id: 'a', type: 'CREDENTIAL_SECRET', username: 'u' },
    { v: 1, id: 'a', type: 'NUEVO' },
  ];
  for (const raw of bad) {
    assert.throws(() => parseResponse(raw, 'a'), ProtocolError, JSON.stringify(raw));
  }
});

test('webOrigin solo acepta http/https y devuelve el origen', () => {
  assert.equal(webOrigin('https://login.example.com/path?q=1#x'), 'https://login.example.com');
  assert.equal(webOrigin('http://localhost:3000/'), 'http://localhost:3000');
  assert.equal(webOrigin('chrome://extensions'), null);
  assert.equal(webOrigin('file:///etc/passwd'), null);
  assert.equal(webOrigin('no es una url'), null);
  assert.equal(webOrigin(undefined), null);
});
