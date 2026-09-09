# 0005 — Protocolo Native Messaging (App ↔ Extensión de navegador)

- Estado: Aceptado
- Fecha: 2026-09-09

## Contexto

La extensión de navegador necesita hablar con algo que tenga la bóveda desbloqueada en memoria para poder ofrecer autocompletado. Ver [Threat Model](../THREAT_MODEL.md), adversarios 5 y 6, para el análisis que motiva las decisiones de autenticación de este canal.

El framing de transporte —stdio, mensajes con longitud-prefijada (uint32 little-endian + JSON UTF-8), límite de ~1MB por mensaje en Chrome— es una restricción de la API de Native Messaging del navegador, no una decisión propia del proyecto.

Se decidió (usuario) que `native-host/` es un **relay delgado** hacia la app Flutter, no una implementación independiente con su propia lógica de desbloqueo — para no duplicar el motor criptográfico en dos binarios/lenguajes distintos.

## Decisión

### Arquitectura

```
[Extensión] --Native Messaging (stdio)--> [native-host] --IPC local autenticado--> [App Flutter, background]
```

El navegador lanza el proceso `native-host` por conexión (así funciona su API — spawnea el proceso y lo mata cuando el puerto se cierra). Ese proceso **no** contiene lógica de cripto ni de acceso a la bóveda: únicamente reenvía los mensajes que recibe por stdio hacia la app Flutter (que corre en background y mantiene la bóveda desbloqueada en memoria durante la sesión), y devuelve la respuesta.

Canal IPC local:
- **Windows:** Named Pipe (`\\.\pipe\lockspire`).
- **macOS/Linux:** Unix domain socket en un directorio con permisos `0700` del usuario (p. ej. `$XDG_RUNTIME_DIR/lockspire.sock` o equivalente).

**Autenticación del canal IPC** (defensa en profundidad, más allá de los permisos de sistema operativo sobre el pipe/socket, que ya restringen la conexión al mismo usuario del SO): la app Flutter genera un token de sesión aleatorio al arrancar, lo escribe en un archivo con permisos restringidos (`0600`, mismo directorio que el socket), y el `native-host` debe leerlo y presentarlo como primer mensaje del handshake antes de que la app acepte cualquier request. Esto cubre el escenario de un pipe/socket con permisos mal configurados o un ataque de "pipe squatting" en Windows.

El propio manifest de Native Messaging del navegador (registrado por extension ID / `allowed_origins`) ya garantiza que solo la extensión oficial puede lanzar el `native-host`; aun así, el host valida estrictamente la forma de cada mensaje entrante contra un schema — nunca deserializa JSON sin validación estricta, para evitar RCE vía parsing.

### Mensajes soportados (v1)

Request/response con `type` + `request_id` para correlación:

| Mensaje | Descripción |
|---|---|
| `PING` | Estado: ¿la app está corriendo? ¿la bóveda está desbloqueada? |
| `UNLOCK_REQUIRED` | Respuesta del host cuando la bóveda está bloqueada. La extensión muestra UI pidiendo al usuario abrir la app para desbloquear. **El native-host nunca pide ni recibe la contraseña maestra** — el desbloqueo ocurre siempre dentro de la UI propia de la app, nunca a través de una superficie inyectada por una página web (mitiga phishing vía la propia extensión). |
| `GET_CREDENTIALS_FOR_ORIGIN` | `{ origin }` → lista de credenciales que matchean ese origen (matching por dominio y subdominios). |
| `SAVE_CREDENTIAL` | `{ origin, username, password }` → dispara una UI de confirmación explícita en la app. Nunca autoguardado silencioso: el usuario debe poder notar si un sitio intenta que se guarde una credencial incorrecta. |
| `GENERATE_PASSWORD` | `{ policy }` → devuelve una contraseña generada según política. |

Passkeys/WebAuthn (`create`/`get`) requieren integración con el WebAuthn API del navegador vía la extensión y son sustancialmente más complejos — se especifican en un ADR aparte cuando se implemente esa feature, para no sobre-diseñar algo que todavía no se construye.

## Alternativas consideradas

- **Native host con su propia lógica de desbloqueo**, independiente de que la app Flutter esté corriendo. Descartado por el usuario: obligaría a duplicar el motor criptográfico en dos binarios/lenguajes distintos, casi doblando la superficie de auditoría en el código más sensible del proyecto.
