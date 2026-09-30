// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import type { Language } from './messages.ts';
import type { Response } from './protocol.ts';

/**
 * El aviso "¿Guardar la contraseña?" en la página (ADR 0034): qué se
 * muestra y qué pasó al responder. Parte pura, sin `chrome.*`.
 */
export interface SavePrompt {
  /** El sitio donde se inició sesión, sin "www.". */
  site: string;
  action: 'save' | 'update';
  /** La entrada que se actualizaría. */
  title?: string;
  /** La bóveda está bloqueada: se guardará al desbloquearla. */
  locked: boolean;
  lang: Language;
}

export type PromptAnswer = 'save' | 'later' | 'never';
export type AnswerResult = 'saved' | 'after-unlock' | 'never' | 'dismissed' | 'failed';

/** Cuánto espera el aviso a que el usuario responda, también si navega. */
export const PROMPT_TTL_MS = 3 * 60 * 1000;

export function siteOf(origin: string): string {
  const host = new URL(origin).hostname;
  return host.startsWith('www.') && host.split('.').length > 2 ? host.slice(4) : host;
}

/**
 * El aviso que corresponde a la respuesta de `CHECK_LOGIN`, o `null` si no
 * hay que preguntar: ya está guardado, el usuario dijo "nunca" en este
 * sitio, o la app no respondió.
 */
export function promptFor(check: Response, site: string, lang: Language): SavePrompt | null {
  switch (check.type) {
    case 'LOGIN_STATUS':
      switch (check.status) {
        case 'new':
          return { site, action: 'save', locked: false, lang };
        case 'update':
          return {
            site,
            action: 'update',
            locked: false,
            lang,
            ...(check.title !== undefined ? { title: check.title } : {}),
          };
        case 'saved':
        case 'never':
          return null;
      }
      return null;
    case 'UNLOCK_REQUIRED':
      return { site, action: 'save', locked: true, lang };
    default:
      return null;
  }
}

/** El resultado de `SAVE_LOGIN` o `NEVER_SAVE_FOR_ORIGIN`. */
export function answerResult(answer: PromptAnswer, response: Response): AnswerResult {
  if (response.type === 'ERROR') return 'failed';
  if (answer === 'never') return response.type === 'OK' ? 'never' : 'failed';
  switch (response.type) {
    case 'OK':
      return 'saved';
    case 'UNLOCK_REQUIRED':
      return 'after-unlock';
    default:
      return 'failed';
  }
}

/** Solo estos mensajes acepta el service worker de un content script. */
export type ContentMessage =
  | { kind: 'submitted'; username: string; password: string }
  | { kind: 'pending' }
  | { kind: 'answer'; answer: PromptAnswer };

const ANSWERS: readonly string[] = ['save', 'later', 'never'];

/** Valida un mensaje de un content script: la página podría influir en él. */
export function parseContentMessage(raw: unknown): ContentMessage | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const m = raw as Record<string, unknown>;
  switch (m['kind']) {
    case 'submitted': {
      const { username, password } = m;
      if (
        typeof username !== 'string' ||
        typeof password !== 'string' ||
        password === '' ||
        username.length > 1024 ||
        password.length > 1024
      ) {
        return null;
      }
      return { kind: 'submitted', username, password };
    }
    case 'pending':
      return { kind: 'pending' };
    case 'answer':
      return typeof m['answer'] === 'string' && ANSWERS.includes(m['answer'])
        ? { kind: 'answer', answer: m['answer'] as PromptAnswer }
        : null;
    default:
      return null;
  }
}
