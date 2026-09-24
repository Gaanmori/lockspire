// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

export interface FillResult {
  ok: boolean;
  reason?: 'origin-changed' | 'no-password-field';
}

/**
 * Se inyecta en la pestaña (frame principal, mundo aislado) con
 * `chrome.scripting.executeScript` cuando el usuario elige una credencial.
 * Debe ser autocontenida: Chrome la serializa, sin acceso a imports.
 *
 * Comprueba de nuevo el origen justo antes de escribir (la pestaña pudo
 * navegar mientras el popup estaba abierto — ADR 0013).
 */
export function fillCredentials(
  expectedOrigin: string,
  username: string,
  password: string,
): FillResult {
  if (location.origin !== expectedOrigin) {
    return { ok: false, reason: 'origin-changed' };
  }

  const isUsable = (el: HTMLInputElement): boolean => {
    if (el.disabled || el.readOnly) return false;
    const style = getComputedStyle(el);
    if (style.visibility === 'hidden' || style.display === 'none') return false;
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };

  const passwordFields = Array.from(
    document.querySelectorAll<HTMLInputElement>('input[type="password"]'),
  ).filter(isUsable);
  const passwordField =
    passwordFields.find((el) => el === document.activeElement) ?? passwordFields[0];
  if (!passwordField) return { ok: false, reason: 'no-password-field' };

  // Usuario: el último campo de texto/email visible antes de la
  // contraseña, dentro del mismo formulario si lo hay.
  const scope: ParentNode = passwordField.form ?? document;
  const candidates = Array.from(
    scope.querySelectorAll<HTMLInputElement>(
      'input[type="email"], input[type="text"], input[type="tel"], input:not([type])',
    ),
  ).filter(
    (el) =>
      isUsable(el) &&
      (el.compareDocumentPosition(passwordField) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0,
  );
  const usernameField = candidates[candidates.length - 1];

  // Setter nativo + eventos: los frameworks (React, etc.) no ven un
  // `el.value = x` directo.
  const setValue = (el: HTMLInputElement, value: string) => {
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
    el.focus();
    if (setter) setter.call(el, value);
    else el.value = value;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  };

  if (usernameField && username) setValue(usernameField, username);
  setValue(passwordField, password);
  return { ok: true };
}
