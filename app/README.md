# app/ — Lockspire (Flutter)

App principal (móvil + escritorio), Flutter/Dart, arquitectura Clean/Hexagonal por features (ver `docs/adr/0003-arquitectura-hexagonal.md`). Ver `/CLAUDE.md` y `/docs/adr/` en la raíz del repo para arquitectura y convenciones antes de añadir código aquí.

Plataformas soportadas hoy: **Android, Windows y Linux** (Linux con Linux Mint como referencia; compila en CI y está pendiente de la primera verificación manual). El resto de plataformas generadas por `flutter create` (iOS, macOS, web) existen pero no se prueban.

## Estructura

```
lib/
  main.dart           # Composition root (ProviderContainer), tema, navegación; en escritorio arranca
                      # el canal de la extensión e impone instancia única; rama /autofill para Android
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
| `home` | Navegación principal de Material 3 tras desbloquear: `HomeShell` (barra inferior en ventanas < 600 px, riel lateral en las demás) y la sección `SettingsScreen`. No conoce ninguna feature: recibe las secciones desde `lib/app_shell.dart`, la composición a nivel de app. |
| `appearance` | Temas (3 familias × claro/oscuro) y pantalla Apariencia. |
| `desktop` | Solo Windows/Linux (ADR 0012): `DesktopShell` (cerrar = ocultar en la bandeja, menú de bandeja, bloqueo al bloquear la sesión del SO o suspender) y `OsSessionEventsPort` con adaptadores Windows (runner C++ → `MethodChannel`) y Linux (D-Bus). |
| `browser_bridge` | Canal con la extensión de navegador (ADR 0013): matching de origen, manejo de peticiones, servidor IPC (vía `packages/lockspire_bridge`), registro opt-in del native host en Chrome/Edge y pantalla "Navegador". |

**Código nativo:**
- Autofill de Android (Kotlin): `android/app/src/main/kotlin/com/lockspire/lockspire/` (`LockspireCredentialProviderService`, `LockspireAutofillService`, `AutofillActivity`, `MainActivity`), no dentro de `lib/features/autofill/infrastructure` como pide `CLAUDE.md`: es la ubicación estándar del proyecto Android. Ver ADR 0011.
- Eventos de sesión de Windows (C++): `windows/runner/flutter_window.cpp` (`WTS_SESSION_LOCK`, `PBT_APMSUSPEND`). Ver ADR 0012.

## Configuración OAuth (solo para sync con Google Drive / OneDrive)

Los client IDs no se versionan. Copia los ejemplos, rellénalos y pásalos al compilar:

- `google_oauth_secrets.json.example` → `google_oauth_secrets.json` (Google Cloud Console: cliente "Desktop app" para Windows y Linux + cliente "Aplicación web" como server client ID de Android; scope `drive.appdata`).
- `microsoft_oauth_secrets.json.example` → `microsoft_oauth_secrets.json` (Azure App Registration: cliente público, redirect URI `http://localhost`, "Permitir flujos de clientes públicos"; scope `Files.ReadWrite.AppFolder`).

Ambos `.json` están en `.gitignore`. Si compilas sin los flags `--dart-define-from-file`, la app funciona igual pero esos dos proveedores quedan sin configurar (WebDAV no necesita nada). Si pasas el flag, el archivo tiene que existir.

## Linux (referencia: Linux Mint)

Dependencias de compilación (además del Flutter SDK):

```
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev build-essential libsecret-1-dev libayatana-appindicator3-dev
```

- `build-essential`: el build hook de `sodium` compila libsodium desde el código fuente (`./configure && make`).
- `libsecret-1-dev`: almacenamiento seguro (`flutter_secure_storage`). En ejecución hace falta un keyring activo (GNOME Keyring viene con Mint).
- `libayatana-appindicator3-dev`: icono de la bandeja (ADR 0012).

En Linux no hay desbloqueo biométrico (solo contraseña maestra). El bloqueo al bloquear la pantalla usa D-Bus (logind y el salvapantallas de Cinnamon, GNOME o freedesktop).

```
flutter run -d linux
flutter build linux --release     # → build/linux/x64/release/bundle/
```

## Extensión de navegador (escritorio)

Para probarla hace falta el native host junto al ejecutable de la app (ver `native-host/README.md`), después **Navegador → "Conectar con Chrome/Edge"** en la app, y cargar `extension/dist` en el navegador (ver `extension/README.md`).

## Comandos útiles

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenera los *.g.dart de Riverpod (no van al repo, ver .gitignore)
dart format --set-exit-if-changed .
flutter analyze
flutter test                                               # 146 tests a la fecha
flutter run -d <device-id> --dart-define-from-file=google_oauth_secrets.json --dart-define-from-file=microsoft_oauth_secrets.json
flutter build windows --debug
```

Benchmark de Argon2id (corre **en el dispositivo**, no en el host):

```
flutter test integration_test/argon2_benchmark_test.dart -d <device-id>
```

Los tests viven en `test/features/<feature>/` con la misma estructura por capas que `lib/`. Los adaptadores que dependen de OAuth real o de plugins nativos (Google/Microsoft login, biometría real, servicios Kotlin, bandeja, eventos de sesión del SO) se verifican a mano; ver `docs/STATE.md`.

Ver `docs/STATE.md` (raíz del repo) para el estado actual y el historial detallado de decisiones tomadas durante el desarrollo.
