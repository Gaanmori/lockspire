# Estado actual — Lockspire

Última actualización: 2026-09-09 (proyecto Flutter scaffolded en `app/`, aún sin estructura hexagonal ni código de dominio)

## Fase actual

Fase 0 — Entorno de desarrollo. Repo remoto en GitHub sincronizado, entorno Flutter + Android SDK verificado con dispositivo físico real, y proyecto Flutter creado en `app/` con el scaffold estándar (todavía no con la estructura Hexagonal por feature).

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
  - Pendiente antes de considerarlo "listo": el scaffold es la plantilla estándar de Flutter (`lib/main.dart` de ejemplo) — **no** tiene todavía la estructura Hexagonal por feature (`lib/features/<feature>/{domain,application,infrastructure,presentation}`) exigida por `CLAUDE.md`, ni cabeceras de licencia AGPLv3 en los archivos de código.

## Pendiente / próximo paso

- Añadir estructura Hexagonal por feature en `lib/` y cabeceras de licencia AGPLv3 a los archivos de código antes de escribir la primera feature real.
- Configurar CI (GitHub Actions) con `flutter test` + `flutter analyze`.
- Empezar Fase 1: Threat Model + specs (formato de bóveda v1, protocolo Native Messaging, modelo de resolución de conflictos) como ADRs.
- Reservar usuario/organización `lockspire` en GitHub, dominio `lockspire.com`, y hacer búsqueda formal de marca registrada antes de hacer público el repo.

## Bloqueos / preguntas abiertas

- Ninguno.
