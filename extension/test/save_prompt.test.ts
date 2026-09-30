// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseResponse } from '../src/protocol.ts';
import { answerResult, parseContentMessage, promptFor, siteOf } from '../src/save_prompt.ts';

test('el sitio se muestra sin "www." ni puerto', () => {
  assert.equal(siteOf('https://www.banco.example'), 'banco.example');
  assert.equal(siteOf('https://www.com'), 'www.com');
  assert.equal(siteOf('http://localhost:8080'), 'localhost');
});

test('solo se pregunta si el inicio de sesión es nuevo, cambió o la bóveda '
  + 'está bloqueada', () => {
  const status = (status: string, title?: string) =>
    parseResponse({ v: 1, id: 'a', type: 'LOGIN_STATUS', status, title }, 'a');

  assert.deepEqual(promptFor(status('new'), 'banco.example', 'es'), {
    site: 'banco.example',
    action: 'save',
    locked: false,
    lang: 'es',
  });
  assert.deepEqual(promptFor(status('update', 'Banco'), 'banco.example', 'en'), {
    site: 'banco.example',
    action: 'update',
    title: 'Banco',
    locked: false,
    lang: 'en',
  });
  assert.equal(promptFor(status('saved'), 'banco.example', 'es'), null);
  assert.equal(promptFor(status('never'), 'banco.example', 'es'), null);
  assert.equal(promptFor({ type: 'UNLOCK_REQUIRED' }, 'banco.example', 'es')?.locked, true);
  assert.equal(
    promptFor({ type: 'ERROR', code: 'APP_NOT_RUNNING' }, 'banco.example', 'es'),
    null,
  );
});

test('LOGIN_STATUS con un estado desconocido se rechaza', () => {
  assert.throws(() =>
    parseResponse({ v: 1, id: 'a', type: 'LOGIN_STATUS', status: 'otro' }, 'a'),
  );
});

test('el resultado de responder el aviso', () => {
  assert.equal(answerResult('save', { type: 'OK' }), 'saved');
  assert.equal(answerResult('save', { type: 'UNLOCK_REQUIRED' }), 'after-unlock');
  assert.equal(answerResult('never', { type: 'OK' }), 'never');
  assert.equal(answerResult('save', { type: 'ERROR', code: 'INTERNAL' }), 'failed');
});

test('el service worker solo acepta mensajes bien formados del content '
  + 'script', () => {
  assert.deepEqual(
    parseContentMessage({ kind: 'submitted', username: 'ana', password: 'p' }),
    { kind: 'submitted', username: 'ana', password: 'p' },
  );
  for (const bad of [
    null,
    'submitted',
    { kind: 'submitted', username: 'ana', password: '' },
    { kind: 'submitted', username: 'ana', password: 'x'.repeat(1025) },
    { kind: 'submitted', username: 1, password: 'p' },
    { kind: 'answer', answer: 'borrar-todo' },
    { kind: 'otro' },
  ]) {
    assert.equal(parseContentMessage(bad), null, JSON.stringify(bad));
  }
  assert.deepEqual(parseContentMessage({ kind: 'answer', answer: 'never' }), {
    kind: 'answer',
    answer: 'never',
  });
});
