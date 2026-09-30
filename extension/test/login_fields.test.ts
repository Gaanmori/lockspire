// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { pickLoginFields, type FieldInfo } from '../src/login_fields.ts';

const field = (type: string, value: string, extra: Partial<FieldInfo> = {}): FieldInfo => ({
  type,
  value,
  autocomplete: '',
  name: '',
  ...extra,
});

test('inicio de sesión común: el correo y la contraseña', () => {
  assert.deepEqual(
    pickLoginFields([
      field('search', 'algo'),
      field('email', ' ana@correo.test '),
      field('password', 'Secreta-1'),
      field('checkbox', 'on'),
    ]),
    { username: 'ana@correo.test', password: 'Secreta-1' },
  );
});

test('sin contraseña escrita no hay nada que guardar', () => {
  assert.equal(pickLoginFields([field('text', 'ana'), field('password', '')]), null);
  assert.equal(pickLoginFields([field('text', 'búsqueda')]), null);
});

test('prefiere el campo marcado como usuario al último de texto', () => {
  assert.deepEqual(
    pickLoginFields([
      field('text', 'ana', { autocomplete: 'username' }),
      field('text', '123456', { name: 'captcha' }),
      field('password', 'Secreta-1'),
    ]),
    { username: 'ana', password: 'Secreta-1' },
  );
});

test('cambio de contraseña: toma la nueva, no la actual', () => {
  assert.equal(
    pickLoginFields([
      field('password', 'vieja'),
      field('password', 'Nueva-2'),
      field('password', 'Nueva-2'),
    ])?.password,
    'Nueva-2',
  );
  assert.equal(
    pickLoginFields([
      field('password', 'vieja', { autocomplete: 'current-password' }),
      field('password', 'Nueva-3', { autocomplete: 'new-password' }),
    ])?.password,
    'Nueva-3',
  );
});

test('solo contraseña (el usuario se pidió en un paso anterior)', () => {
  assert.deepEqual(pickLoginFields([field('password', 'Secreta-1')]), {
    username: '',
    password: 'Secreta-1',
  });
});
