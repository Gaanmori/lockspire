// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import { setToolbarIcon } from './icon.ts';
import type { AppTheme } from './protocol.ts';

const STORAGE_KEY = 'lockspire.theme';

/** Temas cuya paleta calcula la app a partir de un color. */
const GENERATED: ReadonlySet<string> = new Set(['sistema', 'personalizado']);

/**
 * Nombre del tema CSS (`data-theme` del `<html>`, ver popup.css) para un
 * tema de la app. En modo `system` decide [prefersDark].
 */
export function themeName(theme: AppTheme, prefersDark: boolean): string {
  const dark = theme.mode === 'dark' || (theme.mode === 'system' && prefersDark);
  // "Colores del sistema" y "Personalizado" se generan en la app con el
  // algoritmo tonal de Material 3; el popup no lo replica y usa Grafito, el
  // tema por defecto (ADR 0036).
  const family = GENERATED.has(theme.family) ? 'grafito' : theme.family;
  return `${family}-${dark ? 'dark' : 'light'}`;
}

const prefersDark = () => window.matchMedia('(prefers-color-scheme: dark)').matches;

function apply(theme: AppTheme): void {
  document.documentElement.dataset['theme'] = themeName(theme, prefersDark());
  // El ícono de la barra sigue al tema de la app, como en escritorio.
  void setToolbarIcon(theme.family).catch(() => {});
}

/**
 * Aplica el último tema conocido antes de hablar con la app, para que el
 * popup no parpadee con el tema por defecto. Solo guarda familia y modo:
 * nada sensible.
 */
export function applyCachedTheme(): void {
  try {
    const cached = localStorage.getItem(STORAGE_KEY);
    if (cached) apply(JSON.parse(cached) as AppTheme);
  } catch {
    // Almacenamiento no disponible o valor corrupto: tema por defecto.
  }
}

/** Aplica el tema que informó la app y lo recuerda para la próxima vez. */
export function applyAppTheme(theme: AppTheme | undefined): void {
  if (!theme) return;
  apply(theme);
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(theme));
  } catch {
    // Sin almacenamiento: solo no se recuerda.
  }
  window
    .matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', () => apply(theme));
}
