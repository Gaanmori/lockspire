# Lockspire

Gestor de contraseñas y Passkeys open source, multiplataforma y **local-first**, inspirado en SafeInCloud y KeePassXC.

Sin backend centralizado: la bóveda es un archivo local fuertemente cifrado que se sincroniza a través de las nubes personales del usuario (Google Drive, OneDrive, WebDAV). Estándar de seguridad Zero-Knowledge: la contraseña maestra nunca se almacena ni sale del dispositivo.

> Estado: versión 1.0 en preparación para Google Play y Microsoft Store. Ya se puede descargar desde GitHub (ver [Descarga](#descarga)).

## Descarga

[![Última versión](https://img.shields.io/github/v/release/Gaanmori/lockspire?label=%C3%BAltima%20versi%C3%B3n)](https://github.com/Gaanmori/lockspire/releases/latest)

Los enlaces llevan siempre a la última versión publicada. Todas las versiones están en [Releases](https://github.com/Gaanmori/lockspire/releases).

| Plataforma | Archivo | Cómo instalarlo |
|---|---|---|
| **Android** 7.0 o posterior | [Lockspire-android.apk](https://github.com/Gaanmori/lockspire/releases/latest/download/Lockspire-android.apk) | Ábralo en el teléfono. Android le pedirá permitir instalar apps desde el navegador o el gestor de archivos. |
| **Windows** 10 y 11, 64 bits | [Lockspire-windows-x64.zip](https://github.com/Gaanmori/lockspire/releases/latest/download/Lockspire-windows-x64.zip) | Descomprímalo y abra `Lockspire/lockspire.exe`. Si SmartScreen avisa (el ejecutable aún no está firmado), pulse "Más información" → "Ejecutar de todas formas". |
| **Linux** (Ubuntu 22.04, Linux Mint 21 o posteriores) | [lockspire_amd64.deb](https://github.com/Gaanmori/lockspire/releases/latest/download/lockspire_amd64.deb) | `sudo apt install ./lockspire_amd64.deb`, o doble clic. Queda en el menú de aplicaciones. |
| **Linux**, cualquier distribución de 64 bits | [Lockspire-x86_64.AppImage](https://github.com/Gaanmori/lockspire/releases/latest/download/Lockspire-x86_64.AppImage) | Clic derecho → Propiedades → Permitir ejecutar, y doble clic. |
| **Extensión** para Chrome y Edge | [Lockspire-extension.zip](https://github.com/Gaanmori/lockspire/releases/latest/download/Lockspire-extension.zip) | Descomprímala. En `chrome://extensions` (o `edge://extensions`), active "Modo de desarrollador" → "Cargar descomprimida" y elija la carpeta. Después, en la app: Ajustes → Navegador → Conectar con Chrome/Edge. |

- **Verificar la descarga:** cada versión trae `SHA256SUMS.txt` con la huella de cada archivo.
- **Próximamente:** Google Play, Microsoft Store, Chrome Web Store y Edge Add-ons. El APK de GitHub y el de Google Play van firmados con claves distintas: para pasar de uno a otro hay que desinstalar, así que sincronice o exporte su bóveda antes.
- La versión de Windows de GitHub no se actualiza sola. La de la Microsoft Store sí, y es la que tendrá donaciones.

## Objetivos principales

- **Seguridad Zero-Knowledge:** la bóveda debe ser segura incluso si un atacante obtiene acceso a la nube del usuario.
- **Propiedad de los datos:** sin servidores centralizados; el usuario decide dónde guardar su bóveda.
- **Multiplataforma sin fricción:** una sola base de código Flutter para escritorio y móvil. Plataformas objetivo hoy: **Android, Windows y Linux** (Linux Mint como referencia); iOS y macOS quedan para más adelante (el scaffold existe, no se prueban ni se les da soporte todavía).
- **Integración web:** extensión de navegador independiente para autocompletado de credenciales y Passkeys.
- **Gratis y sin suscripciones:** todas las funciones son libres; quien quiera puede hacer una donación voluntaria desde la app.

## Principio rector

**La seguridad prevalece sobre el rendimiento** en cualquier decisión de diseño. Ver `docs/adr/` para el razonamiento detrás de cada decisión de arquitectura y seguridad, y `docs/THREAT_MODEL.md` para el modelo de amenazas.

## Qué funciona hoy

Verificado en dispositivo real (Windows desktop + Android):

- **Bóveda cifrada:** crear/desbloquear, Argon2id (512 MiB, 4 iteraciones) + XChaCha20-Poly1305 vía libsodium, escritura atómica (ADR 0002, 0004, 0007).
- **Gestión de entradas de contraseña:** crear/editar/eliminar, búsqueda, copiar con auto-limpiado del portapapeles a los 30 s, generador (aleatorio o "fácil de recordar") con medidor de fortaleza.
- **Auto-lock** por inactividad (5 min) y al pasar a segundo plano (ADR 0008).
- **Desbloqueo biométrico** opt-in: huella en Android, Windows Hello en escritorio (ADR 0010).
- **Sincronización** con WebDAV, Google Drive (`drive.appdata`) y OneDrive (carpeta de app), automática tras desbloquear/guardar, con merge automático por entrada y por campo, sin intervención del usuario (ADR 0006, 0009). Restaurar una bóveda existente en un dispositivo nuevo.
- **Importar** desde SafeInCloud (XML), Bitwarden (JSON y CSV), Chrome, Firefox y KeePassXC (CSV); **exportar** a Bitwarden, Chrome o un respaldo cifrado.
- **Perfiles:** varias bóvedas en el mismo dispositivo, cada una con su contraseña maestra y sus ajustes (ADR 0039).
- **Temas:** Grafito por defecto, un color a elección, colores del sistema o inspirados en sistemas operativos (ADR 0036).
- **Autofill nativo en Android** vía Credential Manager + `AutofillService` legado (ADR 0011).

Implementado, con tests automatizados, **pendiente de verificación manual**:

- **Linux** (Linux Mint): mismas funciones que Windows salvo desbloqueo biométrico; compila en CI.
- **Escritorio en la bandeja del sistema** (ADR 0012): cerrar la ventana la oculta; la bóveda se bloquea por inactividad, manualmente, al bloquear la sesión del SO o al suspender.
- **Extensión de navegador para Chrome/Edge + native host** (ADR 0005, 0013, 0034): rellenar credenciales, generar contraseñas y ofrecer guardar las que se escriben en un sitio. Verificada en Windows, también con la app instalada como paquete MSIX (ADR 0037).

Pendiente de implementar: Firefox, Passkeys, iOS. El detalle de qué falta y qué está en verificación está en `docs/STATE.md`.

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
  adr/            # Architecture Decision Records (0001–0040)
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
