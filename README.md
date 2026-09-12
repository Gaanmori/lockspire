# Lockspire

Gestor de contraseñas y Passkeys open source, multiplataforma y **local-first**, inspirado en SafeInCloud y KeePassXC.

Sin backend centralizado: la bóveda es un archivo local fuertemente cifrado que se sincroniza a través de las nubes personales del usuario (Google Drive, OneDrive, WebDAV). Estándar de seguridad Zero-Knowledge: la contraseña maestra nunca se almacena ni sale del dispositivo.

> Estado: en desarrollo, repo privado. Pendiente de definir versión inicial pública.

## Objetivos principales

- **Seguridad Zero-Knowledge:** la bóveda debe ser segura incluso si un atacante obtiene acceso a la nube del usuario.
- **Propiedad de los datos:** sin servidores centralizados; el usuario decide dónde guardar su bóveda.
- **Multiplataforma sin fricción:** apps nativas para Escritorio (Windows, macOS, Linux) y Móvil (iOS, Android) compartiendo la misma base de código.
- **Integración web:** extensión de navegador independiente para autocompletado de credenciales y Passkeys.
- **Sin suscripciones:** venta a precio fijo en Play Store / App Store.

## Principio rector

**La seguridad prevalece sobre el rendimiento** en cualquier decisión de diseño. Ver `docs/adr/` para el razonamiento detrás de cada decisión de arquitectura y seguridad.

## Stack

- **App principal (móvil y escritorio):** Flutter (Dart), arquitectura Clean/Hexagonal por features, Riverpod.
- **Criptografía:** libsodium vía bindings nativos — Argon2id (KDF) + XChaCha20-Poly1305 (AEAD).
- **Extensión de navegador:** TypeScript, Manifest V3.
- **Comunicación App/Extensión:** Native Messaging (STDIN/STDOUT).
- **Sincronización cloud:** Google Drive, OneDrive, WebDAV — cada uno como adaptador intercambiable.
- **Autocompletado nativo:** Android Autofill Framework / Credential Manager API, iOS Credential Provider Extension.

## Estructura del repo

```
/app            # App Flutter (móvil + escritorio)
/extension      # Extensión de navegador (TypeScript, Manifest V3)
/native-host    # Native Messaging host
/docs
  STATE.md      # Estado actual del desarrollo — leer primero
  adr/          # Architecture Decision Records
```

## Para empezar (entorno de desarrollo)

Ver `docs/adr/` y `CLAUDE.md` para el contexto completo de arquitectura y decisiones, y `docs/STATE.md` para el estado actual y el historial de la sesión de desarrollo.

Requisitos: Flutter SDK 3.47.2+ (channel stable) con el Android toolchain configurado (ver `flutter doctor`). En Windows hace falta además un `make` compatible con MSYS (no el nativo de Windows) para compilar el binding de libsodium — instalar [MSYS2](https://www.msys2.org/) y `pacman -S make`, con `<msys64>\usr\bin` al final del PATH (nunca al principio, para no romper la detección del Android SDK de Flutter).

```
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d <device-id>
```

## Pendiente de verificación

**ADR 0009 (merge automático por campo, reemplaza el picker manual de conflictos)** está implementado y cubierto por tests automatizados (`flutter test`, 83/83 pasan), pero todavía no se probó en dispositivos reales — falta repetir el escenario de dos dispositivos editando la misma entrada sin sincronizar entre medio (mismo setup Windows + Redmi por Google Drive que ya se usó para verificar Fases 7-9) y confirmar que se resuelve solo, sin picker. Detalle completo en `docs/STATE.md` y `docs/adr/0009-merge-automatico-por-campo.md`.

## Licencia

[GNU Affero General Public License v3.0](LICENSE) (AGPLv3). El código es abierto y auditable; el nombre y el logo "Lockspire" son marca registrada de forma independiente a la licencia del código.
