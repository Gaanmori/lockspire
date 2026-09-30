// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/**
 * Qué usuario y contraseña se enviaron en un formulario (ADR 0034). Es la
 * parte pura de la detección: recibe los campos del formulario en el orden
 * del documento, sin tocar el DOM, para poder probarla.
 */
export interface FieldInfo {
  type: string;
  value: string;
  autocomplete: string;
  name: string;
}

export interface SubmittedLogin {
  username: string;
  password: string;
}

const USERNAME_TYPES = new Set(['text', 'email', 'tel', '']);
const USERNAME_HINT = /user|login|email|mail|correo|usuario|account|cuenta|name/i;

/**
 * El inicio de sesión de [fields], o `null` si no hay una contraseña
 * escrita. Con varias contraseñas (registro o cambio de contraseña) se toma
 * la nueva: la marcada `new-password`, o la que se repite (nueva y
 * confirmación).
 */
export function pickLoginFields(fields: FieldInfo[]): SubmittedLogin | null {
  const passwords = fields
    .map((field, index) => ({ field, index }))
    .filter(({ field }) => field.type === 'password' && field.value !== '');
  if (passwords.length === 0) return null;

  const chosen =
    passwords.find(({ field }) => field.autocomplete.includes('new-password')) ??
    passwords.find(({ field }, i) =>
      passwords.some((other, j) => j !== i && other.field.value === field.value),
    ) ??
    passwords[0]!;

  return {
    username: usernameBefore(fields, chosen.index),
    password: chosen.field.value,
  };
}

/** El usuario: el marcado como tal, o el último campo de texto antes. */
function usernameBefore(fields: FieldInfo[], passwordIndex: number): string {
  const candidates = fields
    .slice(0, passwordIndex)
    .filter((f) => USERNAME_TYPES.has(f.type) && f.value.trim() !== '');
  const marked = candidates.find(
    (f) => /\b(username|email)\b/.test(f.autocomplete) || USERNAME_HINT.test(f.name),
  );
  return (marked ?? candidates.at(-1))?.value.trim() ?? '';
}
