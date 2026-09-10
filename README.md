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
- **Sincronización cloud:** Google Drive, OneDrive, Dropbox, WebDAV — cada uno como adaptador intercambiable.
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

## Problemas conocidos / propuestas en revisión

### No hay forma de restaurar una bóveda existente en un dispositivo nuevo

**Problema:** hoy, si un dispositivo no tiene bóveda local todavía, el único flujo de inicio es "Crear bóveda" (`VaultGateScreen` → `CreateVaultScreen`, cuando el estado de sesión es `VaultSessionNoVault`). Crear una bóveda genera siempre un salt/`vaultId` nuevo — aunque el usuario tipee la misma contraseña maestra que ya usa en otro dispositivo sincronizado, el resultado es una bóveda distinta e incompatible, porque la clave se deriva de `Argon2id(contraseña, salt)` y el salt no coincide.

Si ese dispositivo nuevo después intenta sincronizar contra un proveedor donde ya existe una bóveda real (ej. Google Drive con datos subidos desde otro dispositivo), la sincronización falla con un error de desencriptado en cuanto hace falta comparar o mergear contenido remoto (el tag de autenticación AEAD no valida contra la clave de este dispositivo). No hay pérdida ni corrupción de datos — el fallo es explícito — pero tampoco hay manera de **unirse** a una bóveda ya existente desde un dispositivo sin datos locales.

Encontrado durante la verificación manual de Fase 8 (proveedor de sync Google Drive), al intentar preparar una segunda instalación (Android) para sincronizar contra una bóveda ya creada en otro dispositivo (Windows) — antes de instalarla en el dispositivo real se identificó que el diseño actual no contempla este caso.

**Propuesta:** agregar una segunda opción en el flujo de onboarding, junto a "Crear bóveda nueva": **"Restaurar bóveda existente"**, disponible cuando el estado es `VaultSessionNoVault` y hay un proveedor de sync configurado. El flujo:

1. Descarga el `VaultFile` cifrado del proveedor activo (`SyncPort.downloadVault()`, ya existe, no hace falta ningún caso de uso nuevo).
2. Pide la contraseña maestra y la usa para desbloquear ese archivo descargado (reusa `UnlockVaultUseCase`, mismo mecanismo que "Desbloquear bóveda" hoy — solo cambia el origen del `VaultFile`, no la lógica de desbloqueo).
3. Si desbloquea bien: se persiste localmente y queda como una bóveda normal, ya sincronizada (mismo criterio que ya usa `SyncVaultUseCase` cuando descubre que solo existe la remota).
4. Si la contraseña es incorrecta: mismo manejo de error inline que ya existe en "Desbloquear" — sin reintentos automáticos ni pistas sobre cuál de los dos datos (contraseña o archivo) está mal.

No requiere cambios de dominio ni casos de uso nuevos — es una pantalla más una rama de UI en el punto de entrada, reusando piezas que ya existen. Alcance acotado, candidato a fase corta.

## Licencia

[GNU Affero General Public License v3.0](LICENSE) (AGPLv3). El código es abierto y auditable; el nombre y el logo "Lockspire" son marca registrada de forma independiente a la licencia del código.
