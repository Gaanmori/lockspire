# Estado actual — Lockspire

Última actualización: 2026-09-09 (Fase 1 completa; arrancando Fase 2)

## Fase actual

Fase 1 completa. Arrancando Fase 2 — estructura Hexagonal por feature en `lib/` y primer código de dominio de la app.

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

## Pendiente / próximo paso

- Estructura Hexagonal por feature en `lib/` (`lib/features/<feature>/{domain,application,infrastructure,presentation}`) y cabeceras de licencia AGPLv3 en los archivos de código, ahora que el Threat Model y los specs de Fase 1 ya definen qué features/dominio existen.
- Reservar usuario/organización `lockspire` en GitHub, dominio `lockspire.com`, y hacer búsqueda formal de marca registrada antes de hacer público el repo.

## Bloqueos / preguntas abiertas

- Ninguno.
