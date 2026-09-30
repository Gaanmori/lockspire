// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/**
 * Textos del popup en los idiomas de la app (ADR 0032). El popup usa el
 * idioma que informa la app en `PONG`; hasta entonces, el último conocido o,
 * la primera vez, el del navegador. `es` es la referencia: el tipo obliga a
 * que cada idioma tenga exactamente sus claves.
 */

import { format, languageFor, parseLanguage, type Language, type MessageKey, MESSAGES } from './messages.ts';

export * from './messages.ts';

const STORAGE_KEY = 'lockspire.lang';



let current: Language = initialLanguage();

function initialLanguage(): Language {
  try {
    const cached = parseLanguage(localStorage.getItem(STORAGE_KEY));
    if (cached) return cached;
  } catch {
    // Sin almacenamiento: se usa el del navegador.
  }
  return languageFor(globalThis.navigator?.language);
}

/** Texto de [key] en el idioma actual, con `{nombre}` reemplazado. */
export function t(key: MessageKey, params: Record<string, string> = {}): string {
  return format(MESSAGES[current][key], params);
}


/**
 * Pone los textos fijos del popup (`data-i18n` y `data-i18n-placeholder`)
 * en el idioma actual.
 */
export function translatePage(): void {
  document.documentElement.lang = current;
  document.querySelectorAll<HTMLElement>('[data-i18n]').forEach((el) => {
    el.textContent = t(el.dataset['i18n'] as MessageKey);
  });
  document.querySelectorAll<HTMLInputElement>('[data-i18n-placeholder]').forEach((el) => {
    el.placeholder = t(el.dataset['i18nPlaceholder'] as MessageKey);
  });
}

/** Usa el idioma que informó la app y lo recuerda para la próxima vez. */
export function useAppLanguage(language: Language | undefined): void {
  if (!language || language === current) return;
  current = language;
  try {
    localStorage.setItem(STORAGE_KEY, language);
  } catch {
    // Sin almacenamiento: solo no se recuerda.
  }
  translatePage();
}
