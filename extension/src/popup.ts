// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import { fillCredentials, type FillResult } from './fill.ts';
import { filterEntries } from './filter.ts';
import { t, translatePage, useAppLanguage } from './i18n.ts';
import { applyAppTheme, applyCachedTheme } from './theme.ts';

// Antes que nada: sin esto el popup se pinta un instante con el tema y el
// idioma por defecto hasta que responde la app.
applyCachedTheme();
translatePage();
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
const chooseOther = $<HTMLButtonElement>('choose-other');
const pickerEl = $('picker');
const filterInput = $<HTMLInputElement>('filter');
const allEntriesEl = $<HTMLUListElement>('all-entries');

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
      return (
        t('hostNotInstalled') +
        (response.detail ? `\n\n(Chrome: ${response.detail})` : '')
      );
    case 'APP_NOT_RUNNING':
      return t('appNotRunning');
    default:
      return t('somethingWrong');
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
  if (ping.type === 'PONG') {
    applyAppTheme(ping.theme);
    useAppLanguage(ping.lang);
  }
  const problem = problemMessage(ping);
  if (problem) {
    setStatus(problem, true);
    return;
  }
  generatorEl.hidden = false;

  if (ping.type === 'PONG' && ping.locked) {
    setStatus(t('locked'));
    showAction(t('unlockInApp'), () => void showApp());
    return;
  }

  if (!tab?.id || !origin) {
    setStatus(t('pageNotSupported'));
    return;
  }
  await listCredentials(tab.id, origin);
}

async function listCredentials(tabId: number, origin: string): Promise<void> {
  const response = await send({ type: 'GET_CREDENTIALS_FOR_ORIGIN', origin });
  if (response.type === 'UNLOCK_REQUIRED') {
    setStatus(t('locked'));
    showAction(t('unlockInApp'), () => void showApp());
    return;
  }
  if (response.type !== 'CREDENTIALS') {
    setStatus(problemMessage(response) ?? t('unexpectedResponse'), true);
    return;
  }
  // Siempre se puede elegir otra entrada: también sirve cuando la que
  // coincide no es la cuenta que se quiere usar (ADR 0015).
  chooseOther.hidden = false;
  chooseOther.onclick = () => void openPicker(origin);

  if (response.entries.length === 0) {
    setStatus(t('noCredentials'));
    return;
  }

  setStatus(t('chooseCredential'));
  entriesEl.replaceChildren(
    ...response.entries.map((entry) =>
      entryItem(entry, () => void fill(entry, tabId, origin)),
    ),
  );
  entriesEl.hidden = false;
}

async function openPicker(origin: string): Promise<void> {
  entriesEl.hidden = true;
  chooseOther.hidden = true;
  setStatus(t('loadingEntries'));

  const response = await send({ type: 'LIST_CREDENTIALS' });
  if (response.type === 'UNLOCK_REQUIRED') {
    setStatus(t('locked'));
    showAction(t('unlockInApp'), () => void showApp());
    return;
  }
  if (response.type !== 'CREDENTIALS') {
    setStatus(problemMessage(response) ?? t('unexpectedResponse'), true);
    return;
  }
  if (response.entries.length === 0) {
    setStatus(t('vaultEmpty'));
    return;
  }

  setStatus(t('linkSiteTo', { host: new URL(origin).host }));
  const all = response.entries;
  const render = () => {
    const visible = filterEntries(all, filterInput.value);
    allEntriesEl.replaceChildren(
      ...visible.map((entry) => entryItem(entry, () => void requestLink(entry, origin))),
    );
  };
  filterInput.oninput = render;
  render();
  pickerEl.hidden = false;
  filterInput.focus();
}

async function requestLink(entry: CredentialSummary, origin: string): Promise<void> {
  const response = await send({
    type: 'REQUEST_LINK_ORIGIN',
    origin,
    entry_id: entry.entryId,
  });
  pickerEl.hidden = true;
  if (response.type === 'OK') {
    // La app muestra la confirmación en su ventana; al ganar el foco, el
    // navegador suele cerrar este popup.
    setStatus(t('confirmLink', { title: entry.title }));
    return;
  }
  setStatus(
    response.type === 'UNLOCK_REQUIRED'
      ? t('lockedRetry')
      : t('linkFailed'),
    true,
  );
}

function entryItem(entry: CredentialSummary, onClick: () => void): HTMLLIElement {
  const button = document.createElement('button');
  button.className = 'entry';
  const title = document.createElement('span');
  title.className = 'title';
  title.textContent = entry.title || t('untitled');
  const user = document.createElement('span');
  user.className = 'user';
  user.textContent = entry.username || t('noUsername');
  button.append(title, user);
  button.addEventListener('click', onClick);

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
        ? t('lockedRetry')
        : t('secretFailed'),
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
      ? t('originChanged')
      : t('noPasswordField'),
    true,
  );
}

$('generate').addEventListener('click', async () => {
  const response = await send({ type: 'GENERATE_PASSWORD', length: GENERATED_LENGTH });
  if (response.type !== 'GENERATED_PASSWORD') {
    setStatus(t('generateFailed'), true);
    return;
  }
  $('generated').textContent = response.password;
  $('generated-row').hidden = false;
  $('generated-note').hidden = false;
});

$('copy').addEventListener('click', async () => {
  await navigator.clipboard.writeText($('generated').textContent ?? '');
  $('copy').textContent = t('copied');
});

void main().catch(() => setStatus(t('somethingWrong'), true));
