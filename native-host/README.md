# native-host/ — Native Messaging host

**Sin implementar todavía** — la carpeta solo contiene este README.

Puente entre `extension/` y `app/` vía Native Messaging (STDIN/STDOUT, protocolo JSON). Spec ya definida en `docs/adr/0005-protocolo-native-messaging.md`:

- Relay delgado: reenvía mensajes a la app Flutter por IPC local (named pipe en Windows / unix socket) autenticado con un token de sesión.
- Nunca maneja la contraseña maestra ni lee la bóveda: el desbloqueo ocurre solo en la UI de la app. Si la bóveda está bloqueada, responde `UNLOCK_REQUIRED`.
- Valida estrictamente cada mensaje entrante contra un schema antes de reenviarlo.
- El manifest de Native Messaging (`allowed_origins` por extension ID) restringe qué extensión puede lanzarlo.
- Amenazas relevantes: adversarios 5 y 6 de `docs/THREAT_MODEL.md`.

Todavía no se ha decidido en qué lenguaje escribirlo ni cómo se instala el manifest en cada navegador.
