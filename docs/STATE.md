# Estado actual — Lockspire

Última actualización: 2026-09-09 (Fase 2 en curso — primera feature con estructura Hexagonal)

## Fase actual

Fase 2 en curso. Feature `vault` scaffolded con estructura Hexagonal completa (domain + application con tests; infrastructure/presentation aún sin adaptadores reales). Próximo paso: adaptadores reales de infraestructura.

## Completado

- Repo inicializado (privado) con `README.md`, `CLAUDE.md`, `LICENSE` (AGPLv3), `docs/STATE.md`, `docs/adr/`.
- Nombre del proyecto decidido: Lockspire.
- Licencia decidida: AGPLv3.
- Decisiones de arquitectura, stack criptográfico y modelo de seguridad documentadas en `docs/adr/`.
- Repo privado creado en GitHub (`github.com/Gaanmori/lockspire`), remoto `origin` configurado, rama por defecto `main` (renombrada desde `master`, HEAD remoto y local actualizado).
- Android Studio instalado (winget) y setup wizard completado manualmente por el usuario.
- Flutter SDK 3.44.1 (channel stable) instalado y verificado con `flutter doctor` — sin issues:
  - Android toolchain: SDK en `%LOCALAPPDATA%\Android\sdk`, cmdline-tools instalado manualmente (no lo incluye el wizard de Android Studio por defecto), todas las licencias del SDK aceptadas.
  - Soporte confirmado para Android, Windows desktop, Chrome/Edge (web).
  - Visual Studio Build Tools 2026 detectado (necesario para builds de Windows desktop).
- VS Code configurado con extensiones Claude Code + Flutter + Dart (confirmado por el usuario).
- Dispositivo de pruebas real conectado y detectado: `flutter devices` reconoce el Redmi (Android 16, API 36) por USB, además de Windows desktop, Chrome y Edge.
- Proyecto Flutter creado en `app/` (`flutter create --org com.lockspire --project-name lockspire --platforms=android,ios,windows,macos,linux,web .`):
  - Package/bundle ID: `com.lockspire.lockspire` (cambiable sin costo mientras no se publique en tiendas).
  - `app/README.md` preexistente se conservó, no fue sobrescrito.
  - `flutter analyze` sin issues sobre el scaffold generado.
  - Pendiente antes de considerarlo "listo": el scaffold es la plantilla estándar de Flutter (`lib/main.dart` de ejemplo) — **no** tiene todavía la estructura Hexagonal por feature (`lib/features/<feature>/{domain,application,infrastructure,presentation}`) exigida por `CLAUDE.md`, ni cabeceras de licencia AGPLv3 en los archivos de código. Se deja así a propósito: esa estructura se arma cuando el Threat Model (Fase 1) defina qué features/dominio existen, para no tener que rehacerla.
- CI configurado: `.github/workflows/flutter-ci.yml`, corre en push/PR a `main` — `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` sobre `app/` con Flutter 3.44.1 pinneado. Los 3 pasos verificados localmente contra el scaffold actual (pasan).
- **Fase 1 — Threat Model + specs, documentados como ADRs:**
  - `docs/THREAT_MODEL.md` (documento vivo, no ADR): activos a proteger, 7 actores/adversarios modelados con su mitigación correspondiente, alcance explícitamente excluido, diagrama de confianza extensión↔native-host↔app↔nube.
  - `docs/adr/0004-formato-boveda-v1.md`: header sin cifrar pero autenticado como AAD (magic, versión, params Argon2id, salt, nonce, `vault_id` UUID estable, `format_min_reader_version` con rechazo explícito de formatos futuros), payload JSON con `modified_at`/tombstone por entrada, **blob único cifrado** (no cifrado por entrada, decisión de producto para v1).
  - `docs/adr/0005-protocolo-native-messaging.md`: `native-host/` como relay delgado hacia la app Flutter vía IPC local (named pipe/unix socket) autenticado con token de sesión; mensajes v1 (`PING`, `UNLOCK_REQUIRED`, `GET_CREDENTIALS_FOR_ORIGIN`, `SAVE_CREDENTIAL`, `GENERATE_PASSWORD`); el native-host nunca maneja la contraseña maestra. Passkeys/WebAuthn quedan pendientes de un ADR aparte cuando se implementen.
  - `docs/adr/0006-modelo-resolucion-conflictos.md`: Last-Write-Wins por entrada + tombstones + merge manual solo ante choque real en la misma entrada (3-way merge con snapshot local de la última sync exitosa como ancestro común). CRDT completo descartado por complejidad/superficie de auditoría injustificada.
- **Fase 2 — estructura Hexagonal, feature `vault` (primera feature real, patrón a replicar para las demás):**
  - Dependencias añadidas a `app/pubspec.yaml`: `flutter_riverpod`, `riverpod_annotation`, `uuid` (runtime); `riverpod_generator`, `build_runner` (dev). `riverpod_lint`/`custom_lint` quedaron fuera: incompatibles con el Dart SDK 3.12.1 actual (piden >=3.13.0) en combinación con las versiones de `riverpod_annotation`/`riverpod_generator` disponibles — no bloquea nada, es tooling de lint opcional.
  - `lib/features/vault/domain/`: entidades `Vault`, `VaultEntry`, `VaultFolder` (con `toJson`/`fromJson`, 1:1 con el payload de ADR 0004) y puertos `CryptoPort`, `VaultStoragePort` (con `VaultHeader.toAadBytes()` para el AAD del AEAD).
  - `lib/features/vault/application/`: `CreateVaultUseCase`, `UnlockVaultUseCase` — dependen solo de los puertos, sin imports de infraestructura.
  - Decisión de diseño surgida durante la implementación (no estaba en el plan original): el `nonce` se excluye del AAD del header — se conoce recién al cifrar (lo devuelve `CryptoPort.encrypt`), así que incluirlo en el AAD creaba una dependencia circular con "calcular el AAD antes de cifrar". Alterar el nonce ya rompe el descifrado por sí solo, no necesita autenticarse aparte.
  - `lib/features/vault/infrastructure/` y `presentation/`: solo un `README.md` marcando qué falta (adaptador libsodium, adaptador de archivo atómico, providers Riverpod, pantallas) — deliberadamente sin implementación todavía.
  - Tests en `app/test/features/vault/application/` con fakes en memoria (`FakeCryptoPort`, `FakeVaultStoragePort`), incluye un test que verifica que manipular el header (AAD) rompe la autenticación.
  - Cabecera SPDX (`// SPDX-License-Identifier: AGPL-3.0-or-later` + `// Copyright (C) 2026 Lockspire`) aplicada a todos los archivos `.dart` nuevos y a los dos preexistentes (`main.dart`, `widget_test.dart`).
  - `main.dart` envuelto en `ProviderScope` (composition root de Riverpod), UI de demo sin tocar.
  - Verificado: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` — los 4 tests pasan, sin issues.

## Pendiente / próximo paso

- Adaptadores reales de infraestructura de `vault`: integración de libsodium para `CryptoPort` (ver ADR 0002) y adaptador de archivo con escritura atómica para `VaultStoragePort` (temp + fsync + rename, `CLAUDE.md`).
- Primera pantalla real (crear/desbloquear bóveda) en `vault/presentation/`, con sus providers Riverpod como composition root.
- Replicar el mismo patrón Hexagonal para las siguientes features cuando les toque: sesión/auto-lock, sync, native-messaging bridge.
- Reservar usuario/organización `lockspire` en GitHub, dominio `lockspire.com`, y hacer búsqueda formal de marca registrada antes de hacer público el repo.

## Bloqueos / preguntas abiertas

- Ninguno.
