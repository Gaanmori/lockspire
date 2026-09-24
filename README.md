# Lockspire

Gestor de contraseñas y Passkeys open source, multiplataforma y **local-first**, inspirado en SafeInCloud y KeePassXC.

Sin backend centralizado: la bóveda es un archivo local fuertemente cifrado que se sincroniza a través de las nubes personales del usuario (Google Drive, OneDrive, WebDAV). Estándar de seguridad Zero-Knowledge: la contraseña maestra nunca se almacena ni sale del dispositivo.

> Estado: en desarrollo, repo privado. Pendiente de definir versión inicial pública.

## Objetivos principales

- **Seguridad Zero-Knowledge:** la bóveda debe ser segura incluso si un atacante obtiene acceso a la nube del usuario.
- **Propiedad de los datos:** sin servidores centralizados; el usuario decide dónde guardar su bóveda.
- **Multiplataforma sin fricción:** una sola base de código Flutter para escritorio y móvil. Plataformas objetivo hoy: **Android, Windows y Linux** (Linux Mint como referencia); iOS y macOS quedan para más adelante (el scaffold existe, no se prueban ni se les da soporte todavía).
- **Integración web:** extensión de navegador independiente para autocompletado de credenciales y Passkeys.
- **Sin suscripciones:** venta a precio fijo en Play Store / App Store.

## Principio rector

**La seguridad prevalece sobre el rendimiento** en cualquier decisión de diseño. Ver `docs/adr/` para el razonamiento detrás de cada decisión de arquitectura y seguridad, y `docs/THREAT_MODEL.md` para el modelo de amenazas.

## Qué funciona hoy

Verificado en dispositivo real (Windows desktop + Android):

- **Bóveda cifrada:** crear/desbloquear, Argon2id (512 MiB, 4 iteraciones) + XChaCha20-Poly1305 vía libsodium, escritura atómica (ADR 0002, 0004, 0007).
- **Gestión de entradas de contraseña:** crear/editar/eliminar, búsqueda, copiar con auto-limpiado del portapapeles a los 30 s, generador (aleatorio o "fácil de recordar") con medidor de fortaleza.
- **Auto-lock** por inactividad (5 min) y al pasar a segundo plano (ADR 0008).
- **Desbloqueo biométrico** opt-in: huella en Android, Windows Hello en escritorio (ADR 0010).
- **Sincronización** con WebDAV, Google Drive (`drive.appdata`) y OneDrive (carpeta de app), automática tras desbloquear/guardar, con merge automático por entrada y por campo, sin intervención del usuario (ADR 0006, 0009). Restaurar una bóveda existente en un dispositivo nuevo.
- **Importar desde SafeInCloud** (XML).
- **Autofill nativo en Android** vía Credential Manager + `AutofillService` legado (ADR 0011).

Implementado, con tests automatizados, **pendiente de verificación manual**:

- **Linux** (Linux Mint): mismas funciones que Windows salvo desbloqueo biométrico; compila en CI.
- **Escritorio en la bandeja del sistema** (ADR 0012): cerrar la ventana la oculta; la bóveda se bloquea por inactividad, manualmente, al bloquear la sesión del SO o al suspender.
- **Extensión de navegador para Chrome/Edge + native host** (ADR 0005, 0013): rellenar credenciales guardadas y generar contraseñas. El native host y el canal IPC ya se probaron de punta a punta en Windows; falta la prueba con el navegador.

Pendiente de implementar: guardar credenciales desde la extensión, Firefox, Passkeys, iOS. El detalle de qué falta y qué está en verificación está en `docs/STATE.md`.

## Stack

- **App principal (móvil y escritorio):** Flutter (Dart), arquitectura Clean/Hexagonal por features, Riverpod 3 con code generation.
- **Criptografía:** libsodium vía bindings nativos (paquete `sodium`, variante Sumo) — Argon2id (KDF) + XChaCha20-Poly1305 (AEAD).
- **Extensión de navegador:** TypeScript, Manifest V3 (Chrome/Edge), empaquetada con esbuild.
- **Comunicación App/Extensión:** Native Messaging (STDIN/STDOUT) hacia un native host en Dart, y de ahí a la app por named pipe (Windows) o socket Unix (Linux) autenticados (ADR 0013).
- **Sincronización cloud:** WebDAV, Google Drive, OneDrive — cada uno como adaptador intercambiable de `SyncPort`. Dropbox descartado.
- **Autocompletado nativo:** Android Credential Manager + Autofill Framework (implementado); iOS Credential Provider Extension (futuro).

## Estructura del repo

```
/app              # App Flutter (móvil + escritorio) — ver app/README.md
/extension        # Extensión de navegador (TypeScript, Manifest V3) — ver extension/README.md
/native-host      # Native Messaging host (Dart) — ver native-host/README.md
/packages
  lockspire_bridge/ # Protocolo + transporte IPC compartido por app y native host
/docs
  STATE.md        # Estado actual del desarrollo — leer primero
  THREAT_MODEL.md # Modelo de amenazas (documento vivo)
  adr/            # Architecture Decision Records (0001–0013)
  design/         # Sistema de diseño (tokens, tipografía, componentes)
```

## Para empezar (entorno de desarrollo)

Ver `docs/adr/` y `CLAUDE.md` para el contexto completo de arquitectura y decisiones, y `docs/STATE.md` para el estado actual y el historial de la sesión de desarrollo.

Requisitos:

- Flutter SDK 3.47.2+ (channel stable) con el Android toolchain configurado (ver `flutter doctor`). Es la misma versión que usa el CI (`.github/workflows/flutter-ci.yml`).
- En Windows hace falta además un `make` compatible con MSYS (no el nativo de Windows) para compilar el binding de libsodium — instalar [MSYS2](https://www.msys2.org/) y `pacman -S make`, con `<msys64>\usr\bin` al final del PATH (nunca al principio, para no romper la detección del Android SDK de Flutter).
- Para compilar para Windows desktop: Visual Studio Build Tools con el componente **ATL** (`Microsoft.VisualStudio.Component.VC.ATL`) y el "Modo desarrollador" de Windows activado.
- Para compilar para Linux: paquetes de sistema listados en `app/README.md`.
- Para la extensión: Node 24+.
- Para sync con Google Drive / OneDrive: credenciales OAuth propias, ver `app/README.md`.

```
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d <device-id> --dart-define-from-file=google_oauth_secrets.json --dart-define-from-file=microsoft_oauth_secrets.json
```

## Licencia

[GNU Affero General Public License v3.0](LICENSE) (AGPLv3). El código es abierto y auditable; el nombre y el logo "Lockspire" no están cubiertos por la licencia del código (la búsqueda y el registro formal de marca siguen pendientes, ver `docs/STATE.md`).
