# extension/ — Extensión de navegador (TypeScript, Manifest V3)

**Sin implementar todavía** — la carpeta solo contiene este README. Ver `/CLAUDE.md` y `/docs/adr/` en la raíz del repo antes de añadir código aquí.

- Objetivo: autocompletado de credenciales (y más adelante Passkeys) en navegadores de escritorio — Chrome, Firefox y Edge en Windows.
- Se comunica con `native-host/` vía Native Messaging; el protocolo (mensajes `PING`, `UNLOCK_REQUIRED`, `GET_CREDENTIALS_FOR_ORIGIN`, `SAVE_CREDENTIAL`, `GENERATE_PASSWORD`) está definido en `docs/adr/0005-protocolo-native-messaging.md`.
- La extensión nunca maneja la contraseña maestra ni la bóveda: solo pide credenciales para el origen actual a la app, que es la que las descifra.
- Passkeys/WebAuthn requieren un ADR propio antes de implementarse (pendiente según ADR 0005).
- Fuera de alcance: autofill en navegadores móviles (por ahora) y "auto-type" en apps de escritorio que no sean el navegador (ver `CLAUDE.md` #4).
