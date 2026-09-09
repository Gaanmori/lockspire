# Estado actual — Lockspire

Última actualización: 2026-09-09 (planificación inicial, sin código todavía)

## Fase actual

Fase 0 — Entorno de desarrollo. Repo creado con estructura base, documentación y licencia. Aún no se ha instalado el entorno Flutter ni escrito código de la app.

## Completado

- Repo inicializado (privado) con `README.md`, `CLAUDE.md`, `LICENSE` (AGPLv3), `docs/STATE.md`, `docs/adr/`.
- Nombre del proyecto decidido: Lockspire.
- Licencia decidida: AGPLv3.
- Decisiones de arquitectura, stack criptográfico y modelo de seguridad documentadas en `docs/adr/`.

## Pendiente / próximo paso

- Instalar Flutter SDK, Android SDK/platform-tools, configurar VS Code con extensión Claude Code + Flutter + Dart.
- Configurar dispositivo de pruebas real (Redmi Note 15 Pro+ 5G) vía USB debugging.
- Configurar CI (GitHub Actions) con `flutter test` + `flutter analyze`.
- Empezar Fase 1: Threat Model + specs (formato de bóveda v1, protocolo Native Messaging, modelo de resolución de conflictos) como ADRs.
- Reservar usuario/organización `lockspire` en GitHub, dominio `lockspire.com`, y hacer búsqueda formal de marca registrada antes de hacer público el repo.

## Bloqueos / preguntas abiertas

- Ninguno.
