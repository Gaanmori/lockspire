# app/ — Lockspire (Flutter)

App principal (móvil + escritorio), Flutter/Dart, arquitectura Clean/Hexagonal por features (ver `docs/adr/0003-arquitectura-hexagonal.md`). Ver `/CLAUDE.md` y `/docs/adr/` en la raíz del repo para arquitectura y convenciones antes de añadir código aquí.

## Estructura

```
lib/features/<feature>/
  domain/          # Entidades y puertos (interfaces) — nunca importa de infrastructure/ ni presentation/
  application/      # Casos de uso
  infrastructure/  # Adaptadores que implementan los puertos
  presentation/    # Providers Riverpod (composition root) y pantallas
```

`vault` es la primera feature implementada de punta a punta (bóveda cifrada con libsodium — Argon2id + XChaCha20-Poly1305, escritura atómica) y es el patrón a replicar para las siguientes.

## Comandos útiles

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenera los *.g.dart de Riverpod (no van al repo, ver .gitignore)
flutter analyze
flutter test
flutter run -d <device-id>
```

Ver `docs/STATE.md` (raíz del repo) para el estado actual y el historial detallado de decisiones tomadas durante el desarrollo.
