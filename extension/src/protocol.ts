// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

// Protocolo v1 con la app (ADR 0013), lado extensión. La app y el native
// host validan las peticiones; aquí se validan las respuestas antes de
// usarlas — nada que venga del host se usa sin comprobar su forma.

export const NATIVE_HOST = 'com.lockspire.native_host';
export const PROTOCOL_VERSION = 1;

export type Request =
  | { type: 'PING' }
  | { type: 'GET_CREDENTIALS_FOR_ORIGIN'; origin: string }
  | { type: 'GET_CREDENTIAL_SECRET'; origin: string; entry_id: string }
  | { type: 'GENERATE_PASSWORD'; length: number }
  | { type: 'SHOW_APP' }
  | { type: 'LIST_CREDENTIALS' }
  | { type: 'REQUEST_LINK_ORIGIN'; origin: string; entry_id: string };

export interface CredentialSummary {
  entryId: string;
  title: string;
  username: string;
}

export const THEME_FAMILIES = ['lineage', 'calido', 'menta', 'lavanda', 'sistema'] as const;
export const THEME_MODES = ['system', 'light', 'dark'] as const;

export interface AppTheme {
  family: (typeof THEME_FAMILIES)[number];
  mode: (typeof THEME_MODES)[number];
}

export type Response =
  | { type: 'PONG'; locked: boolean; theme?: AppTheme }
  | { type: 'CREDENTIALS'; entries: CredentialSummary[] }
  | { type: 'CREDENTIAL_SECRET'; username: string; password: string }
  | { type: 'GENERATED_PASSWORD'; password: string }
  | { type: 'OK' }
  | { type: 'UNLOCK_REQUIRED' }
  | { type: 'ERROR'; code: string; detail?: string };

export class ProtocolError extends Error {}

const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v);

const str = (o: Record<string, unknown>, key: string): string => {
  const v = o[key];
  if (typeof v !== 'string') throw new ProtocolError(`"${key}" inválido`);
  return v;
};

/**
 * Valida una respuesta de la app y la convierte a un tipo conocido.
 * Lanza [ProtocolError] si no correlaciona con [requestId] o no tiene la
 * forma esperada.
 */
export function parseResponse(raw: unknown, requestId: string): Response {
  if (!isObject(raw)) throw new ProtocolError('respuesta no es un objeto');
  if (raw['v'] !== PROTOCOL_VERSION) throw new ProtocolError('versión');
  const type = str(raw, 'type');
  // ERROR puede venir sin id si la petición ni siquiera tenía uno válido.
  if (!(type === 'ERROR' && raw['id'] === undefined) && raw['id'] !== requestId) {
    throw new ProtocolError('id no correlaciona');
  }
  switch (type) {
    case 'PONG': {
      if (typeof raw['locked'] !== 'boolean') throw new ProtocolError('locked');
      const theme = parseTheme(raw['theme']);
      return { type, locked: raw['locked'], ...(theme ? { theme } : {}) };
    }
    case 'CREDENTIALS': {
      const list = raw['entries'];
      if (!Array.isArray(list)) throw new ProtocolError('entries');
      const entries = list.map((e): CredentialSummary => {
        if (!isObject(e)) throw new ProtocolError('entrada');
        return {
          entryId: str(e, 'entry_id'),
          title: str(e, 'title'),
          username: str(e, 'username'),
        };
      });
      return { type, entries };
    }
    case 'CREDENTIAL_SECRET':
      return { type, username: str(raw, 'username'), password: str(raw, 'password') };
    case 'GENERATED_PASSWORD':
      return { type, password: str(raw, 'password') };
    case 'OK':
    case 'UNLOCK_REQUIRED':
      return { type };
    case 'ERROR':
      return { type, code: str(raw, 'code') };
    default:
      throw new ProtocolError('type desconocido');
  }
}

/**
 * Tema opcional de `PONG`. Un valor desconocido (p. ej. una familia que
 * añada una versión futura de la app) se ignora en vez de fallar: el tema
 * es cosmético.
 */
function parseTheme(raw: unknown): AppTheme | undefined {
  if (!isObject(raw)) return undefined;
  const family = raw['family'];
  const mode = raw['mode'];
  if (
    typeof family !== 'string' ||
    typeof mode !== 'string' ||
    !(THEME_FAMILIES as readonly string[]).includes(family) ||
    !(THEME_MODES as readonly string[]).includes(mode)
  ) {
    return undefined;
  }
  return { family, mode } as AppTheme;
}

/** Origen de una URL de pestaña, solo para http/https. */
export function webOrigin(url: string | undefined): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return null;
    return parsed.origin;
  } catch {
    return null;
  }
}

/** Envía una petición al native host y valida la respuesta. */
export async function send(request: Request): Promise<Response> {
  const id = crypto.randomUUID();
  let raw: unknown;
  try {
    raw = await chrome.runtime.sendNativeMessage(NATIVE_HOST, {
      v: PROTOCOL_VERSION,
      id,
      ...request,
    });
  } catch (e) {
    // El navegador no encuentra el host registrado, no pudo lanzarlo o el
    // host terminó sin responder. El mensaje de Chrome distingue cuál.
    return {
      type: 'ERROR',
      code: 'HOST_NOT_INSTALLED',
      detail: e instanceof Error ? e.message : String(e),
    };
  }
  return parseResponse(raw, id);
}
