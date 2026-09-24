# 0013 — Native host en Dart, canal IPC y protocolo v1 concreto

- Estado: Aceptado
- Fecha: 2026-09-24
- Concreta: [ADR 0005](0005-protocolo-native-messaging.md) (no lo reemplaza: mantiene relay delgado, IPC local autenticado con token y "el host nunca ve la contraseña maestra"). Detalla lo que 0005 dejó abierto y añade dos mensajes.

## Contexto

ADR 0005 fija la arquitectura `extensión → native host (stdio) → app (IPC local)` pero deja abiertos el lenguaje del host, los detalles del canal IPC y el formato exacto de los mensajes. Además, al implementarlo aparecieron dos hechos que condicionan el diseño:

1. **`dart:io` no soporta sockets Unix en Windows** (comprobado: `errno 10022` al conectar) **ni named pipes**. El named pipe de ADR 0005 en Windows hay que hacerlo con FFI a Win32.
2. `package:win32` 6.x no expone todas las funciones necesarias (`GetNamedPipeServerProcessId`, `ConvertStringSecurityDescriptorToSecurityDescriptorW`, `WaitNamedPipeW`, entre otras).

Alcance v1 elegido por el usuario: Chrome y Edge (Chromium, MV3), rellenar credenciales existentes y generar contraseña. Guardar credenciales nuevas (`SAVE_CREDENTIAL`) y Firefox quedan para la siguiente pasada.

## Decisión

### Lenguaje y estructura

- **Native host en Dart** (`native-host/`), compilado AOT con `dart compile exe` (sin runtime). Decisión del usuario: un solo lenguaje que auditar y el protocolo compartido con la app en vez de duplicado.
- **Paquete compartido `packages/lockspire_bridge/`** (Dart puro): mensajes, validación estricta, framing y transporte IPC (cliente y servidor). Lo usan la app (servidor) y el host (cliente).
- **Bindings FFI propios y mínimos** para Win32 (`kernel32`, `advapi32`) y POSIX (`libc`: `mkdir`, `chmod`, `getuid`), en vez de depender de `package:win32`. Son menos de 20 funciones, fáciles de auditar.
- En la app: feature nueva `lib/features/browser_bridge/` (matching de origen y manejo de peticiones en dominio/aplicación; servidor IPC e instalación del manifest en infraestructura).

### Canal IPC

| | Linux | Windows |
|---|---|---|
| Endpoint | Socket Unix `$XDG_RUNTIME_DIR/lockspire/ipc.sock` | Named pipe `\\.\pipe\lockspire-ipc-<SID del usuario>` |
| Token | `$XDG_RUNTIME_DIR/lockspire/ipc.token` | `%LOCALAPPDATA%\Lockspire\ipc\ipc.token` |
| Permisos | Directorio `0700`, token `0600` (creados con `mkdir`/`chmod` de libc; si el directorio existe y no es nuestro o no es `0700`, se aborta) | DACL protegida que solo concede acceso al SID del usuario (`D:P(A;;GA;;;<SID>)`), `PIPE_REJECT_REMOTE_CLIENTS`, primera instancia con `FILE_FLAG_FIRST_PIPE_INSTANCE`. El token hereda la ACL por usuario de `%LOCALAPPDATA%` |

- Sin `$XDG_RUNTIME_DIR` en Linux, el bridge no arranca (no hay caída a `/tmp`, que abriría la puerta a directorios pre-creados por otro usuario).
- **El nombre del pipe incluye el SID**: `\\.\pipe\lockspire` (ADR 0005) chocaría entre dos usuarios del mismo equipo.
- **Verificación del par, en los dos extremos** (defensa en profundidad además de los permisos y el token):
  - El host comprueba que el **servidor** corre como el mismo usuario del SO antes de enviarle el token. En Windows: `GetNamedPipeServerProcessId` → token del proceso → SID. En Linux: `SO_PEERCRED` → uid. Esto evita el *pipe squatting*: si otro usuario crea el pipe antes que la app, el host se niega a hablar con él y no le entrega el token.
  - La app comprueba lo mismo del **cliente** (`GetNamedPipeClientProcessId` / `SO_PEERCRED`).
  - En Windows el host abre el pipe con `SECURITY_SQOS_PRESENT | SECURITY_IDENTIFICATION`, para que el servidor no pueda suplantar al host más allá de identificarlo.
- **Token de sesión:** 32 bytes de `Random.secure()` en base64url, regenerado en cada arranque de la app. El primer mensaje de cada conexión es `HELLO` con el token, y la app lo compara en tiempo constante. Sin `HELLO` válido en 5 s, la conexión se cierra.
- **Framing** idéntico al de Native Messaging (uint32 little-endian + JSON UTF-8) en ambos tramos, con un límite de 1 MiB por mensaje.

### Protocolo v1

Cada mensaje es un objeto JSON con `v` (versión, `1`), `id` (correlación, 1–64 caracteres `[A-Za-z0-9_-]`) y `type`. Validación estricta en host **y** app: claves desconocidas, tipos incorrectos o longitudes fuera de rango hacen que se rechace el mensaje, que nunca se procesa a medias.

| Petición (extensión → app) | Respuesta | Requiere bóveda desbloqueada |
|---|---|---|
| `PING` | `PONG {locked}` | No |
| `GET_CREDENTIALS_FOR_ORIGIN {origin}` | `CREDENTIALS {entries: [{entry_id, title, username}]}` — **sin contraseñas** | Sí |
| `GET_CREDENTIAL_SECRET {origin, entry_id}` *(nuevo)* | `CREDENTIAL_SECRET {username, password}` solo si esa entrada coincide con ese origen | Sí |
| `GENERATE_PASSWORD {length}` (16–64) | `GENERATED_PASSWORD {password}` (generador aleatorio de la app) | No |
| `SHOW_APP` *(nuevo)* | `OK` — trae la ventana al frente (p. ej. "Desbloquear en Lockspire") | No |

Errores: `UNLOCK_REQUIRED` (ADR 0005), `ERROR {code}` con `code` ∈ `BAD_REQUEST`, `NOT_FOUND`, `APP_NOT_RUNNING` (lo genera el host), `INTERNAL`.

- **Por qué `GET_CREDENTIAL_SECRET` aparte:** la lista que ve el popup no lleva contraseñas. Solo viaja la de la entrada elegida, y solo si coincide con el origen de la pestaña. Así se reduce lo que expone cada consulta.
- **`SHOW_APP`** también sirve para la instancia única de ADR 0012: una segunda instancia de la app se conecta como cliente (`HELLO` con `client: "app-instance"`), envía `SHOW_APP` y termina.
- **Nunca se abre la app ni se muestra UI de desbloqueo por iniciativa del host:** con la bóveda bloqueada la respuesta es `UNLOCK_REQUIRED`, y el usuario decide pulsar "Abrir Lockspire" (ADR 0005).

### Matching de origen

Función pura en el dominio de `browser_bridge`. Una entrada coincide con un origen si el host de su URL es **igual** al del origen, o el origen es **subdominio** de él (`login.example.com` coincide con una entrada `example.com`, pero no al revés). Sin URL o con una URL no parseable, la entrada no coincide. Una entrada sin esquema se trata como `https`. **No se rellena en `http` una entrada guardada como `https`** (protección contra downgrade). Solo se aceptan orígenes `http`/`https` (se rechazan `file:`, `chrome:`, `data:`, etc.) y los puertos distintos no coinciden.

### Extensión (resumen; el detalle vive en `extension/README.md`)

- Permisos mínimos: `nativeMessaging`, `activeTab`, `scripting`. **Sin `host_permissions` ni content scripts permanentes**: el script de relleno solo se inyecta, en el frame principal, cuando el usuario pulsa una credencial en el popup.
- El script de relleno comprueba otra vez `location.origin === origen esperado` justo antes de escribir (evita TOCTOU si la pestaña navegó mientras el popup estaba abierto).
- ID de extensión estable vía `key` (clave pública) en `manifest.json`. **La clave privada no se genera ni se guarda en el repo**: la de la Chrome Web Store será otra y su ID se añadirá a `allowed_origins`.

### Registro del host en el navegador

Lo hace la app **solo cuando el usuario lo pide** (pantalla "Navegador", opt-in explícito; nunca en silencio al arrancar). Escribe el manifest `com.lockspire.native_host.json` con `allowed_origins` fijado al ID de la extensión y lo registra:

- Windows: `HKCU\Software\{Google\Chrome, Microsoft\Edge, Chromium}\NativeMessagingHosts\com.lockspire.native_host` (vía `reg.exe`).
- Linux: `~/.config/{google-chrome, chromium, microsoft-edge}/NativeMessagingHosts/`.

El binario del host se busca junto al ejecutable de la app. Si no está, la pantalla lo indica y no escribe nada.

## Consecuencias

- Tres binarios en escritorio: la app, el host y la extensión. El host no contiene lógica de bóveda ni cripto; lo más sensible que hace es reenviar respuestas que pueden llevar **una** contraseña (la elegida).
- El código FFI de Win32/POSIX es nuevo y crítico para la seguridad: lleva tests de ida y vuelta reales (pipe real en Windows, socket real en Linux), no mocks.
- Con la bóveda bloqueada, la extensión solo sabe que está bloqueada y que la app corre (`PONG {locked: true}`), nada del contenido.
- macOS queda fuera (el transporte Unix del paquete funcionaría, pero no se prueba ni se registra el manifest ahí).

## Alternativas consideradas

- **Loopback TCP (`127.0.0.1`) en Windows** en vez del named pipe: sería más fácil desde Dart, pero cualquier usuario del equipo podría conectarse (solo lo frenaría el token) y abandona la decisión de ADR 0005 sin necesidad. Descartado.
- **`package:win32`:** le faltan funciones clave y trae una API muy amplia. Se prefieren bindings mínimos propios.
- **Devolver las contraseñas en `GET_CREDENTIALS_FOR_ORIGIN`:** más simple, pero expone todas las contraseñas del sitio en cada apertura del popup. Descartado.
- **Registrar el host automáticamente al arrancar la app:** cómodo, pero modifica configuración del navegador sin que el usuario lo pida. Descartado a favor del opt-in.
- **Que el host lance la app si no está corriendo:** se deja para más adelante. v1 responde `APP_NOT_RUNNING` y la extensión pide abrir Lockspire.
