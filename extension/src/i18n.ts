// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/**
 * Textos del popup en los idiomas de la app (ADR 0032). El popup usa el
 * idioma que informa la app en `PONG`; hasta entonces, el último conocido o,
 * la primera vez, el del navegador. `es` es la referencia: el tipo obliga a
 * que cada idioma tenga exactamente sus claves.
 */
const es = {
  connecting: 'Conectando con Lockspire…',
  chooseOther: 'Elegir otra entrada de Lockspire…',
  pickerNote:
    'Elija la entrada que usa en este sitio. Lockspire le va a pedir que confirme el vínculo en su ventana.',
  filterPlaceholder: 'Filtrar por título o usuario',
  generate: 'Generar contraseña',
  copy: 'Copiar',
  copied: 'Copiada',
  generatedNote: 'No se guarda sola: cree la entrada en Lockspire.',
  hostNotInstalled:
    'La extensión no está conectada con la app. En Lockspire: Navegador → "Conectar con Chrome/Edge".',
  appNotRunning: 'Abra Lockspire en este equipo para usar la extensión.',
  somethingWrong: 'Algo salió mal al hablar con Lockspire.',
  unexpectedResponse: 'Respuesta inesperada de Lockspire.',
  locked: 'Su bóveda está bloqueada.',
  unlockInApp: 'Desbloquear en Lockspire',
  pageNotSupported: 'Esta página no admite autocompletado.',
  noCredentials: 'No hay credenciales guardadas para este sitio.',
  chooseCredential: 'Elija una credencial para rellenar:',
  loadingEntries: 'Cargando sus entradas…',
  vaultEmpty: 'Su bóveda no tiene entradas todavía.',
  linkSiteTo: 'Vincular {host} a una entrada:',
  confirmLink:
    'Confirme el vínculo en la ventana de Lockspire. Después vuelva a abrir esta extensión para rellenar "{title}".',
  lockedRetry: 'La bóveda se bloqueó. Desbloquéela e intente de nuevo.',
  linkFailed: 'No se pudo pedir el vínculo.',
  untitled: 'Sin título',
  noUsername: '(sin usuario)',
  secretFailed: 'No se pudo obtener la credencial.',
  originChanged: 'La página cambió de sitio; no se rellenó nada.',
  noPasswordField: 'No se encontró un campo de contraseña en esta página.',
  generateFailed: 'No se pudo generar la contraseña.',
  // Guardar inicios de sesión en la página (ADR 0034).
  savePrompt: '¿Guardar la contraseña de {site} en Lockspire?',
  updatePrompt: '¿Actualizar la contraseña de "{title}" en Lockspire?',
  savePromptLocked: 'Lockspire está bloqueado: se guardará al desbloquearlo.',
  save: 'Guardar',
  update: 'Actualizar',
  notNow: 'Ahora no',
  neverHere: 'Nunca en este sitio',
  savedInLockspire: 'Guardada en Lockspire.',
  savedAfterUnlock: 'Desbloquee Lockspire para terminar de guardarla.',
  saveFailed: 'No se pudo guardar en Lockspire.',
  neverSaved: 'Lockspire no volverá a preguntar en {site}.',
  closePrompt: 'Cerrar',
} as const;

export type MessageKey = keyof typeof es;

const en: Record<MessageKey, string> = {
  connecting: 'Connecting to Lockspire…',
  chooseOther: 'Choose another Lockspire entry…',
  pickerNote:
    'Choose the entry you use on this site. Lockspire will ask you to confirm the link in its window.',
  filterPlaceholder: 'Filter by title or username',
  generate: 'Generate password',
  copy: 'Copy',
  copied: 'Copied',
  generatedNote: "It isn't saved on its own: create the entry in Lockspire.",
  hostNotInstalled:
    'The extension is not connected to the app. In Lockspire: Browser → "Connect with Chrome/Edge".',
  appNotRunning: 'Open Lockspire on this computer to use the extension.',
  somethingWrong: 'Something went wrong talking to Lockspire.',
  unexpectedResponse: 'Unexpected response from Lockspire.',
  locked: 'Your vault is locked.',
  unlockInApp: 'Unlock in Lockspire',
  pageNotSupported: "This page doesn't support autofill.",
  noCredentials: 'There are no saved credentials for this site.',
  chooseCredential: 'Choose a credential to fill in:',
  loadingEntries: 'Loading your entries…',
  vaultEmpty: 'Your vault has no entries yet.',
  linkSiteTo: 'Link {host} to an entry:',
  confirmLink:
    'Confirm the link in the Lockspire window. Then open this extension again to fill in "{title}".',
  lockedRetry: 'The vault locked. Unlock it and try again.',
  linkFailed: 'Could not request the link.',
  untitled: 'Untitled',
  noUsername: '(no username)',
  secretFailed: 'Could not get the credential.',
  originChanged: 'The page changed site; nothing was filled in.',
  noPasswordField: 'No password field was found on this page.',
  generateFailed: 'Could not generate the password.',
  savePrompt: 'Save the password for {site} in Lockspire?',
  updatePrompt: 'Update the password for "{title}" in Lockspire?',
  savePromptLocked: 'Lockspire is locked: it will be saved when you unlock it.',
  save: 'Save',
  update: 'Update',
  notNow: 'Not now',
  neverHere: 'Never on this site',
  savedInLockspire: 'Saved in Lockspire.',
  savedAfterUnlock: 'Unlock Lockspire to finish saving it.',
  saveFailed: 'Could not save it in Lockspire.',
  neverSaved: "Lockspire won't ask again on {site}.",
  closePrompt: 'Close',
};

export const MESSAGES = { es, en } as const;
export type Language = keyof typeof MESSAGES;
export const LANGUAGES = Object.keys(MESSAGES) as Language[];

const STORAGE_KEY = 'lockspire.lang';

/** "es" para cualquier variante de español; inglés para todo lo demás. */
export function languageFor(tag: string | undefined): Language {
  return tag?.toLowerCase().startsWith('es') ? 'es' : 'en';
}

/** Idioma de la app si es uno conocido; si no, `undefined`. */
export function parseLanguage(raw: unknown): Language | undefined {
  return typeof raw === 'string' && (LANGUAGES as string[]).includes(raw)
    ? (raw as Language)
    : undefined;
}

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

export function format(text: string, params: Record<string, string>): string {
  return text.replace(/\{(\w+)\}/g, (match, name: string) => params[name] ?? match);
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
