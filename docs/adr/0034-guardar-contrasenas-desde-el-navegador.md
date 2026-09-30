# ADR 0034 — Guardar contraseñas desde el navegador

- **Estado:** Aceptado
- **Fecha:** 2026-09-30
- **Origen:** el usuario pidió, antes del lanzamiento, que la extensión detecte cuando se inicia sesión en una página y ofrezca guardar usuario, contraseña y sitio, como SafeInCloud. Eligió dos cosas:
  - la detección siempre activa, aunque Chrome muestre el aviso de "todos los sitios";
  - el aviso dentro de la página, no en la ventana de la app.
- **Relación:** amplía el ADR 0013 (extensión con permisos mínimos) y el ADR 0015 (la bóveda solo cambia desde la app). Ver "Consecuencias".

## Decisión

### Extensión

- **Content script** (`capture.ts`), en todas las páginas `http` y `https`, solo en el frame principal.
  - Lee los campos solo cuando se envía un formulario con una contraseña escrita: `submit`, clic en un botón o Enter.
  - La elección de usuario y contraseña es pura y está probada (`login_fields.ts`). Con varias contraseñas (registro o cambio) toma la nueva: la marcada `new-password`, o la que se repite.
- **Aviso:** se dibuja en un Shadow DOM **cerrado**, que la página no puede leer. Solo acepta clics reales (`isTrusted`). Opciones: Guardar o Actualizar, Ahora no, Nunca en este sitio.
- **Service worker** (`background.ts`):
  - Es lo único que habla con la app.
  - **El origen sale siempre de la pestaña** (`sender.url`), nunca del mensaje del content script, y solo se aceptan mensajes del frame principal.
  - El inicio de sesión espera la respuesta en `chrome.storage.session`, que vive solo en memoria y no la leen los content scripts. Se borra al responder, al cerrar la pestaña o a los 3 minutos.
  - Si la página navega después de iniciar sesión, el aviso aparece en la página siguiente.
- **Permisos nuevos:** `storage` y `content_scripts` en `http://*/*` y `https://*/*`. Chrome muestra "Leer y cambiar todos tus datos en todos los sitios web", y la revisión en Chrome Web Store es más estricta.

### Protocolo (v1, ampliado)

- **`CHECK_LOGIN {origin, username, password}`:** responde `LOGIN_STATUS` con `new`, `update` (con el título de la entrada), `saved` o `never`, o `UNLOCK_REQUIRED`. No cambia nada.
- **`SAVE_LOGIN`:** mismos campos que `CHECK_LOGIN`. Con la bóveda bloqueada, la app lo guarda al desbloquear, sale al frente y responde `UNLOCK_REQUIRED`.
- **`NEVER_SAVE_FOR_ORIGIN {origin}`:** guarda "nunca en este sitio".
- **Validación:** el usuario y la contraseña tienen como máximo 1024 caracteres, y la contraseña no puede estar vacía. La app, el native host y la extensión validan con el mismo rigor que el resto del protocolo.

### App

- **Qué ofrecer:** `matchLogin` (dominio) compara con las contraseñas del sitio (`entryMatchesOrigin`).
  - Si ninguna tiene ese usuario (comparado sin distinguir mayúsculas ni espacios de los extremos), es **nuevo**.
  - Si una tiene ese usuario y otra contraseña, se **actualiza** (la modificada más recientemente).
  - Si ya está igual, no se pregunta.
- **Guardar:**
  - Una entrada nueva lleva el sitio sin "www." como título y la dirección vinculada al origen (la regla del ADR 0015).
  - **Actualizar conserva la contraseña anterior en el historial** (`Vault.withFieldReplaced`, hasta 3). Un error de tipeo en la página no borra la buena.
- **"Nunca en este sitio":** es de este equipo, en el almacenamiento seguro (`browser.never_save_sites`), y no se sincroniza. Se puede quitar en Navegador.

## Consecuencias

- **Superficie nueva:** la extensión corre en todas las páginas. Se mitiga:
  - no lee nada hasta un envío con contraseña;
  - no guarda nada en disco;
  - la página no ve el aviso ni puede responderlo.
- **Una página maliciosa** puede simular un inicio de sesión. Solo logra un aviso para su propio sitio, y guardar exige un clic real del usuario.
- **Excepción al ADR 0015:** una extensión comprometida podría pedir `SAVE_LOGIN` para cualquier origen sin preguntar.
  - Si agrega entradas, no se pierde nada.
  - Si cambia una contraseña, la anterior queda en el historial y se puede recuperar.
  - Leer contraseñas ya lo podía hacer con `GET_CREDENTIAL_SECRET`, así que el riesgo nuevo es acotado. Por eso no se pide confirmar en la app, como pidió el usuario.
- **Native host:** hay que recompilarlo junto con la app, porque valida los tipos nuevos.
- **Privacidad:** la política explica que la extensión lee el formulario al enviarlo y no manda nada a internet.
