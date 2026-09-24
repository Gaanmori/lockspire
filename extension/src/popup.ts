// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import { fillCredentials, type FillResult } from './fill.ts';
import { send, webOrigin, type CredentialSummary, type Response } from './protocol.ts';

const GENERATED_LENGTH = 20;

const $ = <T extends HTMLElement>(id: string): T => {
  const el = document.getElementById(id);
  if (!el) throw new Error(`falta #${id}`);
  return el as T;
};

const statusEl = $('status');
const siteEl = $('site');
const primaryAction = $<HTMLButtonElement>('primary-action');
const entriesEl = $<HTMLUListElement>('entries');
const generatorEl = $('generator');

function setStatus(text: string, isError = false): void {
  statusEl.textContent = text;
  statusEl.classList.toggle('error', isError);
}

function showAction(label: string, onClick: () => void): void {
  primaryAction.textContent = label;
  primaryAction.onclick = onClick;
  primaryAction.hidden = false;
}

/** Mensaje para respuestas que no son el caso feliz. `null` si no aplica. */
function problemMessage(response: Response): string | null {
  if (response.type !== 'ERROR') return null;
  switch (response.code) {
    case 'HOST_NOT_INSTALLED':
      return 'La extensión no está conectada con la app. En Lockspire: Navegador → "Conectar con Chrome/Edge".';
    case 'APP_NOT_RUNNING':
      return 'Abrí Lockspire en este equipo para usar la extensión.';
    default:
      return 'Algo salió mal al hablar con Lockspire.';
  }
}

async function showApp(): Promise<void> {
  await send({ type: 'SHOW_APP' });
  window.close();
}

async function main(): Promise<void> {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const origin = webOrigin(tab?.url);
  if (origin) siteEl.textContent = new URL(origin).host;

  const ping = await send({ type: 'PING' });
  const problem = problemMessage(ping);
  if (problem) {
    setStatus(problem, true);
    return;
  }
  generatorEl.hidden = false;

  if (ping.type === 'PONG' && ping.locked) {
    setStatus('Tu bóveda está bloqueada.');
    showAction('Desbloquear en Lockspire', () => void showApp());
    return;
  }

  if (!tab?.id || !origin) {
    setStatus('Esta página no admite autocompletado.');
    return;
  }
  await listCredentials(tab.id, origin);
}

async function listCredentials(tabId: number, origin: string): Promise<void> {
  const response = await send({ type: 'GET_CREDENTIALS_FOR_ORIGIN', origin });
  if (response.type === 'UNLOCK_REQUIRED') {
    setStatus('Tu bóveda está bloqueada.');
    showAction('Desbloquear en Lockspire', () => void showApp());
    return;
  }
  if (response.type !== 'CREDENTIALS') {
    setStatus(problemMessage(response) ?? 'Respuesta inesperada de Lockspire.', true);
    return;
  }
  if (response.entries.length === 0) {
    setStatus('No hay credenciales guardadas para este sitio.');
    return;
  }

  setStatus('Elegí una credencial para rellenar:');
  entriesEl.replaceChildren(
    ...response.entries.map((entry) => entryItem(entry, tabId, origin)),
  );
  entriesEl.hidden = false;
}

function entryItem(entry: CredentialSummary, tabId: number, origin: string): HTMLLIElement {
  const button = document.createElement('button');
  button.className = 'entry';
  const title = document.createElement('span');
  title.className = 'title';
  title.textContent = entry.title || 'Sin título';
  const user = document.createElement('span');
  user.className = 'user';
  user.textContent = entry.username || '(sin usuario)';
  button.append(title, user);
  button.addEventListener('click', () => void fill(entry, tabId, origin));

  const li = document.createElement('li');
  li.append(button);
  return li;
}

async function fill(entry: CredentialSummary, tabId: number, origin: string): Promise<void> {
  const secret = await send({
    type: 'GET_CREDENTIAL_SECRET',
    origin,
    entry_id: entry.entryId,
  });
  if (secret.type !== 'CREDENTIAL_SECRET') {
    setStatus(
      secret.type === 'UNLOCK_REQUIRED'
        ? 'La bóveda se bloqueó. Desbloqueala e intentá de nuevo.'
        : 'No se pudo obtener la credencial.',
      true,
    );
    return;
  }

  const [injection] = await chrome.scripting.executeScript({
    target: { tabId },
    func: fillCredentials,
    args: [origin, secret.username, secret.password],
  });
  const result = injection?.result as FillResult | undefined;
  if (result?.ok) {
    window.close();
    return;
  }
  setStatus(
    result?.reason === 'origin-changed'
      ? 'La página cambió de sitio; no se rellenó nada.'
      : 'No encontré un campo de contraseña en esta página.',
    true,
  );
}

$('generate').addEventListener('click', async () => {
  const response = await send({ type: 'GENERATE_PASSWORD', length: GENERATED_LENGTH });
  if (response.type !== 'GENERATED_PASSWORD') {
    setStatus('No se pudo generar la contraseña.', true);
    return;
  }
  $('generated').textContent = response.password;
  $('generated-row').hidden = false;
  $('generated-note').hidden = false;
});

$('copy').addEventListener('click', async () => {
  await navigator.clipboard.writeText($('generated').textContent ?? '');
  $('copy').textContent = 'Copiada';
});

void main().catch(() => setStatus('Algo salió mal al hablar con Lockspire.', true));
