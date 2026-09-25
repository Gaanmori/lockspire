# Revisión de arquitectura, SOLID, clean code y seguridad — 2026-09-25

Alcance: `app/lib` (≈14.700 líneas sin contar listas de palabras), `packages/lockspire_bridge`, `native-host`, `extension`, código nativo Kotlin (autofill) y C++ (runner de Windows). Base: commit `f7e60f6`.

Método: comprobaciones automáticas de dependencias entre capas y features, lectura completa de los archivos críticos (cripto, almacenamiento, sync, autofill, OAuth, bridge) y **una prueba ejecutada** para confirmar el hallazgo más grave (S1). Este documento solo diagnostica: **no se cambió código**.

## 1. Qué arquitectura usamos

**Clean Architecture organizada como Hexagonal (puertos y adaptadores), por features** (`CLAUDE.md`, ADR 0003). Cada feature en `lib/features/<feature>/` tiene cuatro capas:

| Capa | Contiene | Puede depender de |
|---|---|---|
| `domain/` | Entidades, reglas puras, **puertos** (interfaces) | Nada de las otras capas, ni Flutter |
| `application/` | Casos de uso | `domain/` |
| `infrastructure/` | **Adaptadores** que implementan los puertos (libsodium, disco, WebDAV, Drive, OneDrive, D-Bus…) | `domain/` |
| `presentation/` | Providers de Riverpod (composition root), controllers, pantallas | Todo lo anterior |

`lib/main.dart` y `lib/app_shell.dart` componen las features. `lib/design/` es transversal (sistema de diseño).

**Veredicto: la arquitectura está bien aplicada en el núcleo.** Comprobado automáticamente: **ningún `domain/` ni `application/` importa Flutter, infraestructura ni presentación.** Los problemas están en los bordes entre features y en la capa de presentación (sección 2).

## 2. Arquitectura y SOLID

Severidad: 🔴 alta · 🟠 media · 🟡 baja.

| # | Sev. | Hallazgo | Dónde | Propuesta |
|---|---|---|---|---|
| A1 | 🟠 | **`VaultSessionController` tiene demasiadas responsabilidades (SRP):** 15 operaciones públicas que mezclan ciclo de vida de sesión, CRUD de entradas, importar, biometría, restaurar, temporizador de auto-lock y sync automática. 463 líneas. | `vault/presentation/vault_session_controller.dart` | Dividir: `VaultSessionController` (crear/desbloquear/bloquear), `VaultEntriesController` (CRUD + importar), `AutoLockService` (temporizador + actividad), `BiometricUnlockController`. La sync automática, como un listener en `sync`. |
| A2 | 🟠 | **Lógica de negocio en presentación (dominio anémico):** cómo se añade, edita o borra una entrada (tombstones, `modifiedAt`, reconstruir `Vault`) está en el controller, no en el dominio. | `vault_session_controller.dart` (`addEntry`, `updateEntry`, `deleteEntry`, `importEntries`) | Mover a métodos puros de `Vault` (`withEntryAdded`, `withEntryUpdated`, `withEntryDeleted`) o a casos de uso. Así se testean sin Riverpod. |
| A3 | 🟠 | **Ciclo entre features `vault` ↔ `sync`** en presentación: `vault` dispara la sync automática importando `SyncController`, y `sync` usa la sesión de `vault`. Además, `restoreFromDownloadedFile` (en `vault`) escribe el ancestro y el hash de sync, que son responsabilidad de `sync`. | `vault_session_controller.dart`, `sync_controller.dart` | Invertir la dependencia: `vault` publica eventos ("bóveda guardada", "desbloqueada") y `sync` los escucha. La restauración, como caso de uso de `sync`. |
| A4 | 🟠 | **`sync` depende de un adaptador de infraestructura de `vault`** (`AtomicFileVaultStorageAdapter` para el ancestro): una feature no debería conocer los adaptadores de otra. | `sync/presentation/providers/sync_ancestor_storage_port_provider.dart` | Que `vault` exponga una fábrica de `VaultStoragePort` por ruta, y `sync` dependa solo del puerto. |
| A5 | 🟡 | **Casos de uso instanciados dentro del controller** (`UnlockVaultUseCase(...)` 5 veces, `SaveVaultUseCase`, `CreateVaultUseCase`) en vez de inyectados (DIP a medias). | `vault_session_controller.dart`, `sync_controller.dart` | Un provider por caso de uso, igual que ya se hace con `CheckMasterPasswordRequiredUseCase`. |
| A6 | 🟡 | **Adaptador "gordo":** `SecureStorageSyncSettingsAdapter` implementa 5 puertos. Las interfaces están bien segregadas (ISP), pero la clase concentra todo. | `sync/infrastructure/secure_storage_sync_settings_adapter.dart` | Un adaptador por puerto, compartiendo el `FlutterSecureStorage` inyectado. |
| A7 | 🟡 | **`FlutterSecureStorage` se construye en 8 sitios**, sin un único composition root: las opciones de almacenamiento pueden divergir. | 8 adaptadores y providers | Un solo `secureStorageProvider` inyectado en todos los adaptadores. |
| A8 | 🟡 | **Código Kotlin del autofill fuera de `features/autofill/infrastructure`**, contra la convención de `CLAUDE.md`. Decisión pendiente del usuario desde el 2026-09-24. | `app/android/.../kotlin/` | Documentar la excepción en un ADR (es la ubicación que exige Gradle) o ajustar `CLAUDE.md`. |

**Bien resuelto (para mantener):** las features nuevas (`home`, `appearance`, `desktop`, `browser_bridge`) siguen el patrón: puertos en dominio, un provider por archivo, `HomeShell`/`SettingsScreen` abiertos a extensión, `VaultGateScreen` con `unlockedBuilder` (DIP) y el reloj inyectable.

## 3. Clean code

| # | Sev. | Hallazgo | Dónde | Propuesta |
|---|---|---|---|---|
| C1 | 🟡 | **Pantallas largas que mezclan UI y lógica:** `EntryFormScreen` (619 líneas) incluye el estado del generador, los temporizadores del portapapeles y el historial. | `entry_form_screen.dart` | Extraer `PasswordGeneratorPanel` y un `ClipboardPort` (que además resuelve S4). |
| C2 | 🟡 | **`Platform.isX` repartido por la presentación** (textos de "Windows Hello / la huella", disponibilidad de funciones). | `security_screen`, `unlock_vault_screen`, `vault_unlocked_screen`, `app_shell`… | Un provider de "capacidades de la plataforma" (`biometricMethodName`, `isDesktop`), sobreescribible en tests. |
| C3 | 🟡 | **7.550 líneas de listas de palabras en código Dart** dentro de `application/`. | `vault/application/memorable_wordlists.dart` | Pasarlas a un asset de texto, con un puerto para cargarlas. |
| C4 | 🟡 | **Mezcla de registro:** la UI usa voseo ("Ingresá") y los docs, tuteo. | UI y documentación | Decidir uno y aplicarlo. |

Puntos fuertes: comentarios que explican el **porqué** (con referencias a ADRs), nombres claros, 190 tests (+29 en el bridge, 6 en el host y 9 en la extensión), vectores RFC en código cripto-adyacente y regresiones de bugs reales.

## 4. Seguridad

| # | Sev. | Hallazgo | Escenario concreto | Propuesta |
|---|---|---|---|---|
| **S1** ✅ | 🔴 | **La sync descarga el archivo remoto sin validarlo.** Si solo cambió el remoto, se escribe en disco **sin descifrarlo con la clave de la sesión**, y también reemplaza el ancestro. **Confirmado con una prueba**: un archivo cifrado con otra contraseña devolvió `SyncDownloaded` y reemplazó la bóveda local y el ancestro. | Quien acceda a tu Drive/OneDrive/WebDAV (adversarios 1 y 3 del threat model) sube basura u otra bóveda. La siguiente sync destruye la copia local y la del ancestro. El AEAD lo habría detectado, pero ese camino no lo usa. | Antes de escribir: descifrar el remoto con la clave de la sesión (AEAD) y comprobar que el `vault_id` coincide. Si falla, no tocar nada y avisar. Test de regresión con el escenario de la prueba. Revisar también la rama "no hay bóveda local". |
| S2 | 🟠 | **Rollback:** la nube puede servir una versión **antigua pero válida** de la bóveda (el AEAD no lo impide) y se acepta como "cambio remoto". | Contraseñas cambiadas vuelven a su valor viejo; entradas borradas reaparecen. | Contador monotónico de versión dentro del payload cifrado: rechazar un remoto con versión menor que el último sincronizado. Requiere ADR (toca el formato, ADR 0004). |
| S3 ✅ | 🟠 | **Parámetros de Argon2id del archivo sin límites.** `memoryKib` e `iterations` se leen del header y se usan tal cual. | Un archivo manipulado pide 64 GiB o 10⁹ iteraciones y la app se cuelga o se cierra al desbloquear o restaurar. | Validar rangos antes de derivar: memoria entre 256 MiB y ~2 GiB, iteraciones entre 3 y ~20. Fuera de rango, rechazar. |
| S4 | 🟠 | **Portapapeles:** la contraseña copiada no se marca como sensible, y no se borra al bloquear ni al salir. Solo se borra a los 30 s si el proceso sigue vivo. | Android 13+ la muestra en la vista previa del portapapeles. En Windows queda en el **historial (Win+V)** y en el **portapapeles en la nube**. Si se sale desde la bandeja antes de 30 s, se queda para siempre. | `ClipboardPort` con adaptadores nativos: Android `EXTRA_IS_SENSITIVE`; Windows con los formatos `ExcludeClipboardContentFromMonitorProcessing` y `CanIncludeInClipboardHistory=0`. Limpiar también en `lock()` y al salir. |
| S5 ✅ | 🟠 | **Sin protección de pantalla:** Android no usa `FLAG_SECURE`. | La miniatura de "apps recientes" y las capturas muestran la bóveda desbloqueada. Cualquier app con permiso de grabar pantalla también. | `FLAG_SECURE` en `MainActivity` y `AutofillActivity`. En Windows, `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` como opción. |
| S6 | 🟠 | **Autofill de Android sin dominio web:** el servicio solo conoce el paquete. En navegadores y WebViews es el del navegador, no el del sitio, así que no puede advertir de phishing. La coincidencia por paquete es heurística y ofrece todas las entradas. | En una página falsa dentro de un WebView se puede rellenar la credencial del banco sin ninguna advertencia. | Leer `webDomain` de `AssistStructure` y aplicar el mismo `entryMatchesOrigin` que la extensión. Con la vinculación app↔entrada pendiente (campo propio), avisar cuando no hay coincidencia. |
| S7 ✅ | 🟠 | **WebDAV acepta `http://`:** usuario y contraseña del servidor viajan sin cifrar (Basic Auth). La bóveda sigue cifrada, pero la cuenta del servidor no. | En una red Wi-Fi pública se capturan las credenciales del WebDAV y, con ellas, se puede montar S1 o S2. | Rechazar `http://` salvo `localhost`, o pedir confirmación explícita. |
| S8 ✅ | 🟠 | **No se puede cambiar la contraseña maestra**, y la de creación solo exige 8 caracteres. | Ante una sospecha de filtración no hay forma de rotarla. "12345678" es válida. | Caso de uso "cambiar contraseña maestra": re-derivar con salt nuevo, re-cifrar, subir y borrar la clave biométrica cacheada. Exigir fortaleza mínima (el estimador ya existe). |
| S9 | 🟡 | **OAuth de Microsoft:** sin parámetro `state`, y el servidor local acepta la **primera** petición que llega, venga de donde venga. `error_description` se escribe en la página sin escapar. PKCE sí está bien. | Otra pestaña o proceso que golpee el puerto hace fallar el login. HTML inyectado en una página local. | Añadir `state`, ignorar peticiones sin él y escapar el HTML. |
| S10 ✅ | 🟡 | **`android:allowBackup` no está desactivado**, y por defecto es `true`. | La bóveda (cifrada) y las preferencias entran en la copia automática de Google, y la restauración entre dispositivos queda en un estado inconsistente. | `allowBackup="false"`, o reglas de extracción que excluyan esos datos. |
| S11 ✅ | 🟡 | **Robustez del decodificador:** longitudes del framing sin comprobar, así que un archivo truncado da `RangeError` en vez de un error claro. | Mensaje de error confuso, sin impacto de seguridad. | Validar longitudes y lanzar `FormatException`. |
| S12 | 🟡 | **Durabilidad en Linux:** tras el `rename` atómico no se hace `fsync` del directorio. | Ante un corte de luz justo después de guardar se puede perder el último cambio. | `fsync` del directorio padre en Linux. |
| S13 | 🟡 | **Secretos en memoria** como `Uint8List`/`String`, sin borrado explícito. **Ya documentado** (ADR 0008). | Malware con acceso a la memoria del proceso (adversario 4). | Sin cambio ahora; mantener documentado. |

**Bien resuelto en seguridad:**
- libsodium nativo, con Argon2id (512 MiB, 4 iteraciones) en un isolate aparte.
- XChaCha20-Poly1305 con el header autenticado como AAD, y rechazo de formatos futuros.
- Escritura atómica y control de concurrencia optimista al guardar.
- Ningún `print` ni log con secretos, y los estados que contienen la clave no la exponen en `toString`.
- Canal IPC autenticado con token, verificación del usuario en ambos extremos y DACL o `0700`.
- Extensión con permisos mínimos, validación estricta en los tres tramos, contraseñas de a una y re-verificación del origen antes de rellenar.
- Vincular un sitio se confirma en la UI de confianza de la app.
- Bloqueo por inactividad, por sesión del SO y por suspensión, y exigencia periódica de la contraseña maestra con reloj a prueba de atrasos.

## 5. Plan recomendado

> **Avance (2026-09-25):** ✅ = corregido. Pasos 1 y 2 hechos (S1, S3, S5, S7, S10, y de paso S11). Del paso 3, S8 hecho (ADR 0018). Detalle en `docs/STATE.md`.

1. **S1 ya**: es pérdida de datos confirmada ante una nube manipulada. Arreglo acotado y con test de regresión.
2. **S3, S5, S7 y S10**: arreglos pequeños y de alto valor.
3. **S4 y S8**: requieren código nativo (portapapeles) o un flujo nuevo (cambiar la contraseña).
4. **S2** (rollback) y **S6** (autofill por dominio): necesitan un ADR antes, porque tocan el formato de la bóveda y la vinculación de apps.
5. **Refactor de arquitectura A1–A5**, en commits pequeños y con los tests actuales como red de seguridad. Conviene hacerlo **después** de S1 y S2, porque tocan los mismos archivos.
6. A6–A8 y C1–C4, de forma oportunista.
