// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import type { CredentialSummary } from './protocol.ts';

/** Quita acentos y pasa a minúsculas: "Bóveda" y "boveda" coinciden. */
function normalize(text: string): string {
  return text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase();
}

/**
 * Filtra por título o usuario. Todas las palabras de [query] tienen que
 * aparecer (en cualquier orden). Consulta vacía → todas las entradas.
 */
export function filterEntries(
  entries: CredentialSummary[],
  query: string,
): CredentialSummary[] {
  const words = normalize(query).split(/\s+/).filter(Boolean);
  if (words.length === 0) return entries;
  return entries.filter((entry) => {
    const haystack = normalize(`${entry.title} ${entry.username}`);
    return words.every((word) => haystack.includes(word));
  });
}
