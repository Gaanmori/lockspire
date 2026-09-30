// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';

// El service worker (ADR 0034) con `chrome.*` simulado: la app responde por
// native messaging y `storage.session` es un mapa en memoria.

type Listener = (message: unknown, sender: unknown, reply: (value: unknown) => void) => unknown;

const listeners: Listener[] = [];
const session = new Map<string, unknown>();
const toApp: Record<string, unknown>[] = [];
let loginStatus = 'new';

function appAnswer(request: Record<string, unknown>): Record<string, unknown> {
  const base = { v: 1, id: request['id'] };
  switch (request['type']) {
    case 'PING':
      return { ...base, type: 'PONG', locked: false, lang: 'es' };
    case 'CHECK_LOGIN':
      return { ...base, type: 'LOGIN_STATUS', status: loginStatus };
    default:
      return { ...base, type: 'OK' };
  }
}

(globalThis as Record<string, unknown>)['chrome'] = {
  runtime: {
    id: 'lockspire',
    onMessage: { addListener: (listener: Listener) => listeners.push(listener) },
    sendNativeMessage: async (_host: string, request: Record<string, unknown>) => {
      toApp.push(request);
      return appAnswer(request);
    },
  },
  storage: {
    session: {
      get: async (key: string) => ({ [key]: session.get(key) }),
      set: async (items: Record<string, unknown>) => {
        for (const [key, value] of Object.entries(items)) session.set(key, value);
      },
      remove: async (key: string) => void session.delete(key),
    },
  },
  tabs: { onRemoved: { addListener: () => {} } },
  i18n: { getUILanguage: () => 'es' },
};

await import('../src/background.ts');

const page = { id: 'lockspire', tab: { id: 7 }, frameId: 0, url: 'https://www.banco.example/login' };

/** Manda un mensaje como el content script y espera la respuesta. */
function fromPage(message: unknown, sender: unknown = page): Promise<unknown> {
  return new Promise((resolve) => {
    const async = listeners[0]!(message, sender, resolve);
    if (async !== true) resolve('ignorado');
  });
}

beforeEach(() => {
  session.clear();
  toApp.length = 0;
  loginStatus = 'new';
});

test('el origen sale de la pestaña, nunca del mensaje', async () => {
  const prompt = await fromPage({
    kind: 'submitted',
    username: 'ana',
    password: 'Secreta-1',
    origin: 'https://otro.example',
  });

  const check = toApp.find((r) => r['type'] === 'CHECK_LOGIN')!;
  assert.equal(check['origin'], 'https://www.banco.example');
  assert.deepEqual(prompt, { site: 'banco.example', action: 'save', locked: false, lang: 'es' });
});

test('ignora mensajes de iframes, de otras extensiones o de páginas que no '
  + 'son web', async () => {
  for (const sender of [
    { ...page, frameId: 3 },
    { ...page, id: 'otra-extension' },
    { ...page, url: 'chrome://settings' },
    { ...page, tab: undefined },
  ]) {
    assert.equal(
      await fromPage({ kind: 'submitted', username: 'a', password: 'p' }, sender),
      'ignorado',
    );
  }
  assert.equal(toApp.length, 0);
});

test('lo ya guardado no pregunta ni queda pendiente', async () => {
  loginStatus = 'saved';

  assert.equal(await fromPage({ kind: 'submitted', username: 'ana', password: 'p' }), null);
  assert.equal(session.size, 0);
});

test('guardar manda lo que quedó pendiente de esa pestaña y lo olvida', async () => {
  await fromPage({ kind: 'submitted', username: 'ana', password: 'Secreta-1' });

  // Tras navegar, la página nueva vuelve a mostrar el aviso.
  assert.equal(((await fromPage({ kind: 'pending' })) as { site: string }).site, 'banco.example');
  assert.equal(await fromPage({ kind: 'answer', answer: 'save' }), 'saved');

  const save = toApp.find((r) => r['type'] === 'SAVE_LOGIN')!;
  assert.equal(save['origin'], 'https://www.banco.example');
  assert.equal(save['username'], 'ana');
  assert.equal(save['password'], 'Secreta-1');
  assert.equal(await fromPage({ kind: 'pending' }), null);
  assert.equal(session.size, 0);
});

test('"Nunca en este sitio" avisa a la app; "Ahora no" solo olvida', async () => {
  await fromPage({ kind: 'submitted', username: 'ana', password: 'p' });
  assert.equal(await fromPage({ kind: 'answer', answer: 'never' }), 'never');
  assert.equal(toApp.at(-1)!['type'], 'NEVER_SAVE_FOR_ORIGIN');

  await fromPage({ kind: 'submitted', username: 'ana', password: 'p2' });
  const before = toApp.length;
  assert.equal(await fromPage({ kind: 'answer', answer: 'later' }), 'dismissed');
  assert.equal(toApp.length, before);
});

test('lo pendiente vence a los 3 minutos', async () => {
  await fromPage({ kind: 'submitted', username: 'ana', password: 'p' });
  const realNow = Date.now;
  Date.now = () => realNow() + 3 * 60 * 1000 + 1;
  try {
    assert.equal(await fromPage({ kind: 'pending' }), null);
  } finally {
    Date.now = realNow;
  }
});
