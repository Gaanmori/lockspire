# extension/ — Extensión de navegador (TypeScript, Manifest V3)

Extensión de Lockspire para **Chrome y Edge** (Chromium). Rellena usuario y contraseña de la bóveda en el sitio de la pestaña actual y genera contraseñas. Habla con la app de escritorio a través de `native-host/` (Native Messaging). Diseño en [ADR 0013](../docs/adr/0013-native-host-dart-e-ipc.md).

## Qué hace (v1)

- Popup con las credenciales que coinciden con el sitio actual (mismo dominio o subdominio; nunca rellena en `http` una entrada guardada como `https`).
- Clic en una credencial → la app devuelve **solo esa** contraseña → se rellena en la página.
- Si la bóveda está bloqueada: botón "Desbloquear en Lockspire", que trae la app al frente. El desbloqueo ocurre siempre en la app, nunca en el navegador.
- Generar contraseña (aleatoria, 20 caracteres) y copiarla. No se guarda sola.

Todavía no: guardar credenciales nuevas (`SAVE_CREDENTIAL`), Firefox, Passkeys.

## Seguridad

- Permisos mínimos: `nativeMessaging`, `activeTab`, `scripting`. **Sin `host_permissions` ni content scripts permanentes**: el script de relleno se inyecta en el frame principal solo al elegir una credencial, en el mundo aislado de la extensión.
- El script vuelve a comprobar que el origen de la página es el mismo que se consultó justo antes de escribir.
- La lista del popup no incluye contraseñas (`GET_CREDENTIALS_FOR_ORIGIN`); la contraseña viaja solo para la entrada elegida (`GET_CREDENTIAL_SECRET`).
- Toda respuesta del host se valida (`src/protocol.ts`) antes de usarse; el DOM del popup se construye con `textContent`, nunca `innerHTML`.
- CSP estricta en las páginas de la extensión.
- ID fijo en desarrollo (`gmlibgaohpjlblfapahkkjcoohpdeofk`) gracias a la clave pública `key` del manifest. La clave privada no existe en el repo. La Chrome Web Store asignará otro ID, que habrá que añadir a `allowedExtensionIds` en la app.

## Estructura

```
public/            # manifest.json, popup.html/css, iconos (se copian tal cual a dist/)
src/protocol.ts    # tipos del protocolo, validación de respuestas, envío al host
src/popup.ts       # lógica del popup
src/fill.ts        # función que se inyecta en la página para rellenar
test/              # tests (node --test) y fixtures/login.html para probar el relleno a mano
build.mjs          # esbuild: src/popup.ts → dist/popup.js + copia de public/
```

## Desarrollo

Requiere Node 24+.

```
npm install
npm run typecheck
npm test
npm run build        # genera dist/
```

Cargarla: `chrome://extensions` (o `edge://extensions`) → "Modo de desarrollador" → "Cargar descomprimida" → carpeta `extension/dist`. Para que funcione hace falta además la app abierta con el native host registrado (ver `native-host/README.md`).
