// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import { format, MESSAGES, type MessageKey } from './messages.ts';
import { pickLoginFields, type FieldInfo } from './login_fields.ts';
import type { AnswerResult, ContentMessage, PromptAnswer, SavePrompt } from './save_prompt.ts';

/**
 * Content script (ADR 0034): corre en el mundo aislado de cada página, en
 * el frame principal. Solo lee los campos cuando se envía un formulario con
 * una contraseña escrita, y dibuja el aviso "¿Guardar?" en un Shadow DOM
 * cerrado, que la página no puede leer. Nunca guarda nada por su cuenta:
 * todo pasa por el service worker.
 */

const ask = <T>(message: ContentMessage): Promise<T | null> =>
  chrome.runtime.sendMessage<ContentMessage, T | null>(message).catch(() => null);

// ---------------------------------------------------------------------
// Detección
// ---------------------------------------------------------------------

let lastSent = '';

function fieldsOf(scope: ParentNode): FieldInfo[] {
  return Array.from(scope.querySelectorAll<HTMLInputElement>('input')).map((input) => ({
    type: (input.getAttribute('type') ?? 'text').toLowerCase(),
    value: input.value,
    autocomplete: (input.getAttribute('autocomplete') ?? '').toLowerCase(),
    name: `${input.name} ${input.id}`,
  }));
}

/**
 * El botón de "mostrar contraseña" vive junto al campo, sin otro campo al
 * lado. Tocarlo no es enviar: la contraseña puede estar a medio escribir
 * (revisión 2026-09-30).
 */
function isPasswordToggle(button: Element): boolean {
  const box = button.parentElement;
  if (!box) return false;
  const inputs = box.querySelectorAll('input');
  return inputs.length === 1 && inputs[0]!.type === 'password';
}

/** El formulario del elemento, o toda la página si no hay (SPA). */
function scopeOf(target: EventTarget | null): ParentNode {
  return target instanceof Element ? (target.closest('form') ?? document) : document;
}

function onPossibleSubmit(target: EventTarget | null): void {
  const login = pickLoginFields(fieldsOf(scopeOf(target)));
  if (!login) return;
  // Un mismo envío dispara submit, click y Enter: se manda una vez.
  const signature = `${login.username}\n${login.password}`;
  if (signature === lastSent) return;
  lastSent = signature;
  void ask<SavePrompt>({ kind: 'submitted', ...login }).then((prompt) => {
    if (prompt) showPrompt(prompt);
  });
}

document.addEventListener('submit', (e) => onPossibleSubmit(e.target), true);
document.addEventListener(
  'click',
  (e) => {
    if (!e.isTrusted || !(e.target instanceof Element)) return;
    const button = e.target.closest('button, input[type="submit"], [role="button"]');
    if (button && !isPasswordToggle(button)) onPossibleSubmit(button);
  },
  true,
);
document.addEventListener(
  'keydown',
  (e) => {
    if (e.isTrusted && e.key === 'Enter' && e.target instanceof HTMLInputElement) {
      onPossibleSubmit(e.target);
    }
  },
  true,
);

// Si la página navegó justo después de iniciar sesión, el aviso sigue aquí.
void ask<SavePrompt>({ kind: 'pending' }).then((prompt) => {
  if (prompt) showPrompt(prompt);
});

// ---------------------------------------------------------------------
// Aviso
// ---------------------------------------------------------------------

let host: HTMLElement | null = null;

/**
 * El aviso no acepta clics hasta llevar este tiempo en pantalla: una página
 * no puede hacerlo aparecer justo debajo del puntero para que el usuario lo
 * toque sin verlo (revisión 2026-09-30, S21).
 */
const MIN_VISIBLE_MS = 500;
let shownAt = 0;

const STYLE = `
  :host { all: initial; }
  .card {
    position: fixed; top: 16px; right: 16px; z-index: 2147483647;
    width: 340px; max-width: calc(100vw - 32px); box-sizing: border-box;
    padding: 16px; border-radius: 16px;
    font: 14px/1.4 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    color: #1b1c1c; background: #fdfdfb;
    box-shadow: 0 8px 28px rgba(0,0,0,.28);
  }
  @media (prefers-color-scheme: dark) {
    .card { color: #e4e2e0; background: #242625; }
    .secondary { color: #e4e2e0 !important; }
  }
  .head { display: flex; align-items: center; gap: 8px; font-weight: 600; margin-bottom: 8px; }
  .close { margin-left: auto; border: 0; background: none; color: inherit; font-size: 18px; cursor: pointer; }
  p { margin: 0 0 12px; }
  .note { font-size: 12px; opacity: .8; }
  .actions { display: flex; flex-wrap: wrap; gap: 8px; justify-content: flex-end; }
  button.action { border: 0; border-radius: 20px; padding: 8px 16px; font: inherit; cursor: pointer; }
  .primary { background: #00696d; color: #fff; }
  .secondary { background: transparent; color: #1b1c1c; }
  .never { margin-right: auto; }
`;

function removePrompt(): void {
  host?.remove();
  host = null;
}

function showPrompt(prompt: SavePrompt): void {
  removePrompt();
  const text = (key: MessageKey, params: Record<string, string> = {}) =>
    format(MESSAGES[prompt.lang][key], params);

  host = document.createElement('div');
  const root = host.attachShadow({ mode: 'closed' });
  const style = document.createElement('style');
  style.textContent = STYLE;
  const card = document.createElement('div');
  card.className = 'card';
  card.setAttribute('role', 'dialog');

  const head = document.createElement('div');
  head.className = 'head';
  head.textContent = 'Lockspire';
  const close = button('×', 'close', () => answer('later'));
  close.setAttribute('aria-label', text('closePrompt'));
  head.append(close);

  const question = document.createElement('p');
  question.textContent =
    prompt.action === 'update' && prompt.title
      ? text('updatePrompt', { title: prompt.title })
      : text('savePrompt', { site: prompt.site });
  card.append(head, question);
  if (prompt.locked) {
    const note = document.createElement('p');
    note.className = 'note';
    note.textContent = text('savePromptLocked');
    card.append(note);
  }

  const actions = document.createElement('div');
  actions.className = 'actions';
  actions.append(
    button(text('neverHere'), 'action secondary never', () => answer('never')),
    button(text('notNow'), 'action secondary', () => answer('later')),
    button(text(prompt.action === 'update' ? 'update' : 'save'), 'action primary', () =>
      answer('save'),
    ),
  );
  card.append(actions);
  root.append(style, card);
  document.documentElement.append(host);
  shownAt = performance.now();

  function answer(choice: PromptAnswer): void {
    actions.querySelectorAll('button').forEach((b) => (b.disabled = true));
    void ask<AnswerResult>({ kind: 'answer', answer: choice }).then((result) => {
      const done: Partial<Record<AnswerResult, string>> = {
        saved: text('savedInLockspire'),
        'after-unlock': text('savedAfterUnlock'),
        never: text('neverSaved', { site: prompt.site }),
        failed: text('saveFailed'),
      };
      const message = result ? done[result] : undefined;
      if (!message) return removePrompt();
      question.textContent = message;
      card.querySelectorAll('.note, .actions').forEach((el) => el.remove());
      setTimeout(removePrompt, 4000);
    });
  }
}

/**
 * Solo clics reales y con el aviso ya visible: la página no puede "tocar"
 * Guardar por el usuario.
 */
function button(label: string, className: string, onClick: () => void): HTMLButtonElement {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = className;
  b.textContent = label;
  b.addEventListener('click', (e) => {
    e.stopPropagation();
    if (e.isTrusted && performance.now() - shownAt >= MIN_VISIBLE_MS) onClick();
  });
  return b;
}
