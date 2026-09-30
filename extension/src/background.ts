// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import { languageFor, type Language } from './messages.ts';
import { send, webOrigin } from './protocol.ts';
import {
  answerResult,
  parseContentMessage,
  promptFor,
  PROMPT_TTL_MS,
  siteOf,
  type AnswerResult,
  type SavePrompt,
} from './save_prompt.ts';

/**
 * Service worker: recibe los inicios de sesión que detecta el content
 * script y habla con la app (ADR 0034). El origen sale siempre de la
 * pestaña que manda el mensaje (`sender`), nunca del mensaje: la página
 * podría influir en lo que manda el content script.
 *
 * El inicio de sesión espera la respuesta en `chrome.storage.session`, que
 * vive solo en memoria y no la leen los content scripts. Se borra al
 * responder, al cerrar la pestaña o a los 3 minutos.
 */
interface Pending {
  origin: string;
  username: string;
  password: string;
  prompt: SavePrompt;
  expires: number;
}

const keyFor = (tabId: number) => `pending-login:${tabId}`;

async function loadPending(tabId: number): Promise<Pending | null> {
  const key = keyFor(tabId);
  const pending = (await chrome.storage.session.get(key))[key] as Pending | undefined;
  if (!pending) return null;
  if (pending.expires < Date.now()) {
    await chrome.storage.session.remove(key);
    return null;
  }
  return pending;
}

async function appLanguage(): Promise<Language | null> {
  const ping = await send({ type: 'PING' });
  if (ping.type !== 'PONG') return null; // Sin la app no hay dónde guardar.
  return ping.lang ?? languageFor(chrome.i18n.getUILanguage());
}

async function onSubmitted(
  tabId: number,
  origin: string,
  username: string,
  password: string,
): Promise<SavePrompt | null> {
  const lang = await appLanguage();
  if (!lang) return null;
  const check = await send({ type: 'CHECK_LOGIN', origin, username, password });
  const prompt = promptFor(check, siteOf(origin), lang);
  if (!prompt) return null;
  const pending: Pending = {
    origin,
    username,
    password,
    prompt,
    expires: Date.now() + PROMPT_TTL_MS,
  };
  await chrome.storage.session.set({ [keyFor(tabId)]: pending });
  return prompt;
}

async function onAnswer(tabId: number, answer: 'save' | 'later' | 'never'): Promise<AnswerResult> {
  const pending = await loadPending(tabId);
  await chrome.storage.session.remove(keyFor(tabId));
  if (!pending || answer === 'later') return 'dismissed';
  const { origin, username, password } = pending;
  const response =
    answer === 'save'
      ? await send({ type: 'SAVE_LOGIN', origin, username, password })
      : await send({ type: 'NEVER_SAVE_FOR_ORIGIN', origin });
  return answerResult(answer, response);
}

chrome.runtime.onMessage.addListener((raw, sender, sendResponse) => {
  const tabId = sender.tab?.id;
  const origin = webOrigin(sender.url);
  // Solo el content script propio, en el frame principal de una página web.
  if (sender.id !== chrome.runtime.id || tabId === undefined || sender.frameId !== 0 || !origin) {
    return false;
  }
  const message = parseContentMessage(raw);
  if (!message) return false;

  const reply = (async () => {
    switch (message.kind) {
      case 'submitted':
        return onSubmitted(tabId, origin, message.username, message.password);
      case 'pending':
        return (await loadPending(tabId))?.prompt ?? null;
      case 'answer':
        return onAnswer(tabId, message.answer);
    }
  })();
  reply.then(sendResponse, () => sendResponse(null));
  return true; // Respuesta asíncrona.
});

chrome.tabs.onRemoved.addListener((tabId) => {
  void chrome.storage.session.remove(keyFor(tabId));
});
