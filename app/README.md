# app/ — Lockspire (Flutter)

App principal (móvil + escritorio), Flutter/Dart, arquitectura Clean/Hexagonal por features (ver `docs/adr/0003-arquitectura-hexagonal.md`). Ver `/CLAUDE.md` y `/docs/adr/` en la raíz del repo para arquitectura y convenciones antes de añadir código aquí.

Plataformas soportadas hoy: **Android y Windows**. El resto de plataformas generadas por `flutter create` (iOS, macOS, Linux, web) existen pero no se prueban.

## Estructura

```
lib/
  main.dart           # Composition root (ProviderScope), tema, navegación; rama /autofill para Android
  design/             # Sistema de diseño transversal (colores, espaciado, ThemeData) — ver docs/design/README.md
  features/<feature>/
    domain/           # Entidades y puertos (interfaces) — nunca importa de infrastructure/ ni presentation/
    application/      # Casos de uso
    infrastructure/   # Adaptadores que implementan los puertos
    presentation/     # Providers Riverpod (composition root), controllers y pantallas
```

Features actuales:

| Feature | Qué contiene |
|---|---|
| `vault` | Bóveda cifrada (libsodium: Argon2id + XChaCha20-Poly1305, escritura atómica), sesión y auto-lock, gestión de entradas, generador y medidor de fortaleza de contraseñas, importar desde SafeInCloud (XML), desbloqueo biométrico (Android / Windows Hello). Es el patrón de referencia para las demás. |
| `sync` | `SyncPort` + adaptadores WebDAV, Google Drive y OneDrive; merge automático de 3 vías por entrada y por campo (`domain/vault_merge.dart`, ADR 0006/0009); sync automática; ajustes de sync. |
| `autofill` | Lado Dart del autofill de Android: `matchEntriesForPackage()` y la pantalla de selección de credencial que abre `AutofillActivity`. |

**Código nativo de autofill (Kotlin):** vive en `android/app/src/main/kotlin/com/lockspire/lockspire/` (`LockspireCredentialProviderService`, `LockspireAutofillService`, `AutofillActivity`, `MainActivity`), no dentro de `lib/features/autofill/infrastructure` como pide `CLAUDE.md` — es la ubicación estándar del proyecto Android. Ver ADR 0011.

## Configuración OAuth (solo para sync con Google Drive / OneDrive)

Los client IDs no se versionan. Copia los ejemplos, rellénalos y pásalos al compilar:

- `google_oauth_secrets.json.example` → `google_oauth_secrets.json` (Google Cloud Console: cliente "Desktop app" para Windows + cliente "Aplicación web" como server client ID de Android; scope `drive.appdata`).
- `microsoft_oauth_secrets.json.example` → `microsoft_oauth_secrets.json` (Azure App Registration: cliente público, redirect URI `http://localhost`, "Permitir flujos de clientes públicos"; scope `Files.ReadWrite.AppFolder`).

Ambos `.json` están en `.gitignore`. Si compilas sin los flags `--dart-define-from-file`, la app funciona igual pero esos dos proveedores quedan sin configurar (WebDAV no necesita nada). Si pasas el flag, el archivo tiene que existir.

## Comandos útiles

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenera los *.g.dart de Riverpod (no van al repo, ver .gitignore)
dart format --set-exit-if-changed .
flutter analyze
flutter test                                               # 131 tests a la fecha
flutter run -d <device-id> --dart-define-from-file=google_oauth_secrets.json --dart-define-from-file=microsoft_oauth_secrets.json
flutter build windows --debug
```

Benchmark de Argon2id (corre **en el dispositivo**, no en el host):

```
flutter test integration_test/argon2_benchmark_test.dart -d <device-id>
```

Los tests viven en `test/features/<feature>/` con la misma estructura por capas que `lib/`. Los adaptadores que dependen de OAuth real o de plugins nativos (Google/Microsoft login, biometría real, servicios Kotlin) se verifican a mano; ver `docs/STATE.md`.

Ver `docs/STATE.md` (raíz del repo) para el estado actual y el historial detallado de decisiones tomadas durante el desarrollo.
