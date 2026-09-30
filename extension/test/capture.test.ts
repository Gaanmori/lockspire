// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseHTML } from 'linkedom';

// El content script (ADR 0034) en una página simulada con linkedom: qué
// manda al service worker al enviar un formulario y cuándo dibuja el aviso.

const { window, document } = parseHTML(`<!doctype html><html><body>
  <form id="login">
    <input type="email" name="email">
    <input type="password" name="pass">
    <button type="submit">Entrar</button>
  </form>
  <form id="search"><input type="text" name="q"></form>
</body></html>`);

const sent: Record<string, unknown>[] = [];
let answer: unknown = null;

Object.assign(globalThis, {
  window,
  document,
  Element: window.Element,
  HTMLInputElement: window.HTMLInputElement,
  chrome: {
    runtime: {
      sendMessage: async (message: Record<string, unknown>) => {
        sent.push(message);
        return message['kind'] === 'pending' ? null : answer;
      },
    },
  },
});

await import('../src/capture.ts');

const input = (name: string) => document.querySelector(`[name="${name}"]`) as HTMLInputElement;
const submit = async (form: string) => {
  document.getElementById(form)!.dispatchEvent(new window.Event('submit', { bubbles: true }));
  await new Promise((resolve) => setTimeout(resolve, 0));
};

test('al cargar pregunta si quedó un aviso pendiente (la página navegó)', () => {
  assert.deepEqual(sent[0], { kind: 'pending' });
});

test('un formulario sin contraseña no manda nada', async () => {
  input('q').value = 'algo';
  const before = sent.length;

  await submit('search');

  assert.equal(sent.length, before);
});

test('al enviar el inicio de sesión manda usuario y contraseña, una sola '
  + 'vez, y dibuja el aviso fuera de la página', async () => {
  input('email').value = 'ana@correo.example';
  input('pass').value = 'Secreta-1';
  answer = { site: 'correo.example', action: 'save', locked: false, lang: 'es' };
  const before = sent.length;
  const nodesBefore = document.documentElement.children.length;

  await submit('login');
  await submit('login');

  assert.deepEqual(sent.slice(before), [
    { kind: 'submitted', username: 'ana@correo.example', password: 'Secreta-1' },
  ]);
  // El aviso cuelga del <html>, no del <body> de la página.
  assert.equal(document.documentElement.children.length, nodesBefore + 1);
});

test('si la contraseña cambió, vuelve a preguntar', async () => {
  input('pass').value = 'Secreta-2';
  const before = sent.length;

  await submit('login');

  assert.equal(sent.slice(before).length, 1);
  assert.equal(sent.at(-1)!['password'], 'Secreta-2');
});
