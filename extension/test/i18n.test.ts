// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { format, languageFor, MESSAGES, parseLanguage } from '../src/i18n.ts';
import { parseResponse } from '../src/protocol.ts';

const params = (text: string) => [...text.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();

test('cada idioma tiene las claves y los parámetros del español', () => {
  const keys = Object.keys(MESSAGES.es).sort();
  for (const [lang, messages] of Object.entries(MESSAGES)) {
    assert.deepEqual(Object.keys(messages).sort(), keys, lang);
    for (const key of keys) {
      const text = (messages as Record<string, string>)[key]!;
      assert.ok(text.trim().length > 0, `${lang}:${key}`);
      assert.deepEqual(params(text), params((MESSAGES.es as Record<string, string>)[key]!), key);
    }
  }
});

test('el español usa "usted": sin voseo ni tuteo', () => {
  const secondPerson = /(?<!\p{L})(confirmá|volvé|elegí|abrí|confirmes|puedes|tienes|tu|tus|te)(?!\p{L})/iu;
  for (const [key, text] of Object.entries(MESSAGES.es)) {
    assert.doesNotMatch(text, secondPerson, key);
  }
});

test('languageFor: español para cualquier variante, inglés para lo demás', () => {
  assert.equal(languageFor('es-CO'), 'es');
  assert.equal(languageFor('ES'), 'es');
  assert.equal(languageFor('en-US'), 'en');
  assert.equal(languageFor('pt-BR'), 'en');
  assert.equal(languageFor(undefined), 'en');
});

test('format reemplaza los parámetros conocidos y deja los demás', () => {
  assert.equal(format('Vincular {host}: {x}', { host: 'a.com' }), 'Vincular a.com: {x}');
});

test('PONG con idioma conocido lo expone; desconocido o ausente se ignora', () => {
  const pong = (lang: unknown) =>
    parseResponse({ v: 1, id: 'a', type: 'PONG', locked: false, lang }, 'a');
  assert.deepEqual(pong('en'), { type: 'PONG', locked: false, lang: 'en' });
  assert.deepEqual(pong('fr'), { type: 'PONG', locked: false });
  assert.deepEqual(pong(undefined), { type: 'PONG', locked: false });
  assert.equal(parseLanguage(3), undefined);
});

test('el manifiesto toma nombre y descripción de _locales en cada idioma', () => {
  const manifest = JSON.parse(readFileSync('public/manifest.json', 'utf8'));
  assert.equal(manifest.name, '__MSG_extName__');
  assert.equal(manifest.description, '__MSG_extDescription__');
  for (const lang of Object.keys(MESSAGES)) {
    const messages = JSON.parse(readFileSync(`public/_locales/${lang}/messages.json`, 'utf8'));
    assert.ok(messages.extName.message);
    assert.ok(messages.extDescription.message);
  }
});
