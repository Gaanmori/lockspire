# Revisión general — 2026-09-30

**Alcance:** todo lo construido hasta hoy, con foco en lo nuevo desde la revisión del 2026-09-28:
- los tests (reorganización, flujos, 90 % en las cuatro capas);
- idiomas (ADR 0032);
- donaciones en Google Play y Microsoft Store (ADR 0033, 0035);
- guardar contraseñas desde el navegador (ADR 0034).

**Método:**
- **Comprobaciones automáticas:**
  - dependencias entre capas y features;
  - tamaño de archivos;
  - `print`, `TODO`, `catch` vacíos y cabeceras;
  - `Random()`, parámetros de Argon2id y manejo de claves;
  - esperas fijas en los tests.
- **Lectura del código nuevo:** extensión (`capture.ts`, `background.ts`), `HandleBridgeRequest`, `matchLogin`, canal nativo de la Store en C++ y escritura de la bóveda (`saveVault`).
- **Estado de la suite:** 603 tests de la app, 26 de la extensión, 29 del paquete del puente y 6 del native host, en verde. Cobertura: dominio 95,4 %, aplicación 95,2 %, infraestructura 92,7 %, presentación 90,4 %.

Leyenda: 🔴 alta · 🟠 media · 🟡 baja o mantenimiento.

**Estado (mismo día):** todo lo de abajo quedó resuelto, cada punto con su test, salvo S19, que se decidió no hacer (ver su fila). La sección "Resolución", al final, dice qué se hizo en cada uno.

## Veredicto

La base es sólida:
- ningún `domain/` ni `application/` importa Flutter, infraestructura ni presentación;
- no hay dependencias circulares entre features;
- la criptografía sigue el ADR 0002 (Argon2id de 512 MiB y 4 pasadas, XChaCha20-Poly1305 con libsodium);
- no hay logs, `Random()` inseguro ni TODOs.

**Queda un hallazgo de prioridad media que conviene resolver antes del lanzamiento: P1**, las escrituras simultáneas de la bóveda. Lo agrava guardar desde el navegador.

## Seguridad

| # | Sev. | Hallazgo | Recomendación |
|---|---|---|---|
| S18 | 🟠 | **Las contraseñas que esperan el desbloqueo no vencen.** Con la bóveda bloqueada, "Guardar" en el navegador deja el usuario y la contraseña en memoria de la app (`PendingBrowserLogins`) hasta desbloquear, aunque pasen horas. En la extensión vencen a los 3 minutos; en la app no. | Descartarlas a los ~10 minutos o al bloquear otra vez. Test de flujo con el reloj de la prueba. |
| S19 | 🟡 | **La clave de la sesión no se borra al bloquear.** `lock()` cambia el estado, pero el `Uint8List` de la clave queda en el heap hasta que el recolector lo libere. Ya está aceptado como S13 (ADR 0008): Dart no puede borrar `String`. | La clave sí se puede borrar: `fillRange(0, length, 0)` al bloquear, después de confirmar que no hay otra escritura en curso con esa clave (ver P1). Es barato y reduce la ventana de exposición de lo más sensible. |
| S20 | 🟡 | **Editar la contraseña a mano no guarda la anterior.** Solo la guardan el merge y, desde hoy, el navegador (ADR 0034). Si el usuario se equivoca al editar, la buena se pierde. | Mover la regla al dominio: `withEntryUpdated` registra el historial de `password`, con la misma lógica que `withFieldReplaced`. Una sola regla para todos los caminos. |
| S21 | 🟡 | **El aviso de la extensión se puede tapar.** Una página puede poner algo encima del aviso (clickjacking). El daño es bajo: solo guarda credenciales de esa misma página, y exige un clic real. | Aceptable. Si se quiere endurecer: exigir que el aviso lleve visible un mínimo de tiempo antes de aceptar el clic. |
| S22 | 🟡 | **`capture.ts` importa `i18n.ts`,** que al cargarse lee `localStorage`, es decir, **el de la página** donde corre el content script. Solo lee una clave de idioma y no filtra nada, pero una página puede cambiar en qué idioma sale el aviso. | Separar los textos (`messages.ts`, sin efectos al importar) de la lógica del popup. |

**Verificado sin hallazgos:**
- **Protocolo nuevo** (`CHECK_LOGIN`, `SAVE_LOGIN`, `NEVER_SAVE_FOR_ORIGIN`): validación estricta en los tres lados, con límites de 1024 caracteres, contraseña no vacía y ninguna clave extra.
- **Origen:** el service worker lo toma de `sender.url` y solo acepta mensajes del frame principal.
- **Aviso:** Shadow DOM cerrado y solo clics reales (`isTrusted`).
- **Pendientes:** en `storage.session` (en memoria y sin acceso de los content scripts).
- **Nunca en este sitio:** la lista va en el almacenamiento seguro.
- **Donaciones:** la app nunca ve datos del pago. En Play y en la Store, la compra se confirma para evitar reembolsos o bloqueos.
- **Canal de la Store en C++:** no tiene lógica de negocio. Sin identidad MSIX no hace nada, y las respuestas vuelven por un mensaje de ventana registrado, no `WM_APP`.

## Arquitectura (SOLID)

| # | Sev. | Hallazgo | Recomendación |
|---|---|---|---|
| A11 | 🟠 | **`HandleBridgeRequest` crece con cada función de la extensión.** Hoy recibe 9 dependencias en el constructor y un `switch` de 10 casos que mezcla leer credenciales, vincular sitios, guardar inicios de sesión, tema e idioma. Cada función nueva lo toca (abierto/cerrado) y junta varias razones de cambio (responsabilidad única). | Separarlo en manejadores por tema: `CredentialRequests`, `LinkRequests`, `LoginSaveRequests`, `AppInfoRequests`. Un despachador elige por tipo. Los tests ya están agrupados por tema, así que la división es natural. |
| A12 | 🟠 | **`SyncAccountsController` depende de `GoogleDriveDesktopAuth` y `MicrosoftOAuthAuth` concretos** (inversión de dependencias). Ya estaba anotado como pendiente. | Un `CloudAuthPort` por nube: conectar, reconectar y desconectar. Permite además tests de flujo de conectar Drive y OneDrive. |
| A13 | 🟡 | **Puertos fuera de lugar:** `password_changed_elsewhere_port.dart` está en `vault/application/`, no en `vault/domain/ports/` como el resto. `launcherIconPortProvider` vive en `launcher_icon_sync.dart`, no en `presentation/providers/`. | Moverlos para que "dónde está cada cosa" sea predecible. |
| A14 | 🟡 | **Claves de campo como texto suelto:** `HandleBridgeRequest` usa `fields['username']`, `['password']` y `['url']` en vez de `EntryFields`. | Usar `EntryFields` en todos lados. |
| A15 | 🟡 | **Pantallas todavía grandes:** `entry_form_screen` (512 líneas), `sync_settings_screen` (391), `import_screen` (388), `unlock_vault_screen` (366). | Extraer widgets por sección, como se hizo en A10. En el formulario de entradas, la lógica de "qué campos tiene cada tipo" puede ir a un objeto propio, fuera del `State`. |

## Clean code

- **Bien:**
  - sin `print`, `TODO` ni `FIXME`;
  - textos en "usted";
  - toda la lógica nueva de la extensión que se puede probar está en módulos puros (`login_fields.ts`, `save_prompt.ts`).
- **`catch (_) {}` vacíos:** subieron de 6 a 10. Revisarlos uno por uno: cada uno debería tener un comentario que diga por qué no importa el error.
- **`capture.ts`:** detecta un posible envío con **cualquier** clic en un botón si hay una contraseña escrita. Un botón de "mostrar contraseña" puede adelantar el aviso antes de enviar. Conviene ignorar botones con `type="button"` que no estén dentro de un formulario con `submit`.
- **Runner de Windows:** los archivos de la plantilla de Flutter (`main.cpp`, `win32_window.*`, `utils.*`) no llevan cabecera. Son de la plantilla, con su propia licencia BSD. Está bien dejarlos así, pero `flutter_window.*` ya tiene código propio y le correspondería la cabecera AGPL.

## Rendimiento

| # | Sev. | Hallazgo | Recomendación |
|---|---|---|---|
| P1 | 🟠 | **Escrituras simultáneas de la bóveda.** `saveVault` recibe la bóveda ya modificada y valida el hash del archivo. Si dos escrituras salen a la vez, la segunda falla con conflicto y **su cambio se pierde**: el usuario ve "no se pudo guardar". No se corrompe nada, porque el hash lo impide, pero el cambio no queda. Hasta hoy escribían en segundo plano los íconos y la sync. Desde ADR 0034 también escribe la extensión, en cualquier momento, incluso mientras el usuario edita una entrada. | Pasar las escrituras por una cola (una a la vez) y que `saveVault` reciba **el cambio** (`Vault Function(Vault)`) en vez de la bóveda terminada, aplicado sobre la versión vigente al momento de escribir. Así ninguna escritura pisa ni pierde a otra. Test: dos escrituras simultáneas, las dos quedan. |
| P2 | 🟡 | **Cifrar y serializar en el hilo de la interfaz.** Cada guardado arma el JSON de toda la bóveda y la cifra en el hilo principal. Con los íconos de sitios (unos 3 KB en base64 cada uno), una bóveda de 500 entradas pesa unos 1,5 MB. Es rápido, pero puede notarse en teléfonos modestos. | Medir en el Redmi con una bóveda grande. Si se nota, mover `encode` y `encrypt` a un isolate. |
| P3 | 🟡 | **Búsqueda y orden de la lista** en cada build. Ya estaba anotado, sin cambios. | Memorizar si una bóveda pasa de unos miles de entradas. |

**Bien:**
- Argon2id corre en un isolate.
- Los íconos se buscan de a 4 a la vez.
- La lista usa `ListView.separated`, que construye solo lo visible.
- El content script no hace nada hasta un envío.

## Pruebas

**Bien:**
- La pirámide está sana: 13 archivos de dominio, 18 de aplicación, 37 de infraestructura, 8 de presentación y 23 de flujo.
- Hay dobles compartidos, el arnés `TestApp` y el robot `AppRobot`.
- Los flujos usan la raíz de composición real.
- Los tests nuevos encontraron bugs reales: login de OneDrive y de Google en escritorio, historial de contraseñas.

| # | Sev. | Hallazgo | Recomendación |
|---|---|---|---|
| T3 | 🟠 | **Esperas de tiempo real en tests** (`Future.delayed` real): `vault_session_controller_test` (8 lugares), `export_import_screens_test`, `app_smoke_test` y el de D-Bus. Son lentas y pueden fallar en una CI cargada. | Usar `fake_async` (ya es dependencia) o el reloj de `testWidgets`. En D-Bus, esperar el evento con un `Completer` en vez de dormir. |
| T4 | 🟡 | **`vault_session_controller_test` tiene 969 líneas.** Cuesta encontrar qué cubre cada parte. | Dividirlo por tema (crear, desbloquear, bloquear, recargar, escribir), como el controller. |
| T5 | 🟡 | **Comentarios desactualizados:** los tests de biometría de Android y Windows dicen que `_storage` "nunca se toca" y citan "el plan aprobado". Desde hoy `biometric_key_storage_test` sí lo prueba. | Quitar esos comentarios. |
| T6 | 🟡 | **Partes sin test automático:** el pegamento DOM de la extensión (`capture.ts`, `background.ts`) y el canal C++ de la Store. | Extensión: un test con un DOM simulado (`linkedom`, liviano) para envío, aviso y respuesta. Store: solo prueba manual con el MSIX, como está anotado. |
| T7 | 🟡 | **Margen de presentación chico** (90,4 %). Cualquier pantalla nueva sin test baja el piso de la CI. | Escribir el test de flujo junto con cada pantalla nueva, como se viene haciendo. |

## Orden sugerido

1. **P1** (cola de escrituras) y **S18** (vencimiento de lo pendiente), antes del lanzamiento. Son cambios chicos y bien delimitados.
2. **S20** (historial al editar) y **S19** (borrar la clave al bloquear).
3. **A11** (dividir `HandleBridgeRequest`) y **T3** (tests sin esperas reales).
4. El resto, como mantenimiento.

## Resolución (2026-09-30)

Suite después de los arreglos: 625 tests de la app, 36 de la extensión, 29 del puente y 6 del native host, en verde. Cobertura: dominio 95,3 %, aplicación 95,6 %, infraestructura 92,8 %, presentación 92,8 %.

| # | Qué se hizo | Test |
|---|---|---|
| P1 | `VaultSessionController.updateVault(cambio)`: las escrituras van en fila y cada cambio se aplica sobre la bóveda vigente. Ante un conflicto con el disco, se recarga y el cambio se aplica otra vez. **Bug encontrado al hacerlo:** si se bloqueaba mientras se escribía, al terminar la sesión volvía a abrirse. Corregido. | `vault_session_writes_test`: dos escrituras a la vez, conflicto con otro dispositivo, bloquear mientras se escribe |
| S18 | Lo pendiente de guardar desde el navegador se descarta a los 10 minutos (`pendingBrowserLoginTtl`). | `browser_flow_test` |
| S19 | **No se hace**, a propósito. La sync, la mudanza y la exportación usan la misma clave durante operaciones de red. Borrarla al bloquear con una sync en curso cifraría la bóveda con una clave en ceros y la subiría a la nube. Además, Dart puede mover objetos en memoria, así que quedarían copias. Sigue aceptado como S13 (ADR 0008). | — |
| S20 | `withEntryUpdated` guarda el valor anterior de los secretos (contraseña, CVV, PIN y campos ocultos), también al borrarlos. **Además:** el historial ahora permite copiar un secreto anterior con el portapapeles protegido; antes se mostraba enmascarado y no se podía recuperar. | `vault_test`, `entries_flow_test` |
| S21 | El aviso de la extensión no acepta clics hasta llevar 500 ms en pantalla. | Manual; la lógica de clics reales exige `isTrusted` |
| S22 | Textos de la extensión en `messages.ts`, sin efectos al importarse; el content script ya no toca el `localStorage` de la página. | `i18n.test`, `capture.test` |
| A11 | `HandleBridgeRequest` despacha a `BridgeAppRequests`, `BridgeCredentialRequests`, `BridgeLinkRequests` y `BridgeLoginSaveRequests`. | `handle_bridge_request_test` |
| A12 | `CloudSignInPort` con `GoogleDriveDesktopSignIn`, `GoogleDriveAndroidSignIn` y `OneDriveSignIn`. El controller ya no conoce los adaptadores concretos. OneDrive sin refresh token da un error claro. | `cloud_accounts_flow_test` (nuevo: conectar, mudar, falla y sin token), `cloud_sign_in_adapters_test` |
| A13 | `launcherIconPortProvider` pasó a `presentation/providers/`. `password_changed_elsewhere_port.dart` **se queda** en `application/`: devuelve `UnlockedVaultResult`, de esa capa, y ya lo explicaba su comentario. Era un falso hallazgo. | — |
| A14 | `EntryFields` en lugar de claves sueltas (extensión, autofill, vínculos, generador). Las claves del canal con Kotlin siguen como texto: son el protocolo. | Suites existentes |
| A15 | `entry_form_screen` pasó de 512 a 391 líneas (`EntryFormModel`, `PasswordEntrySection`), `sync_settings_screen` de 391 a 293 (`WebDavSettingsForm`) e `import_screen` de 388 a 327 (`BackupPasswordDialog`). | `entry_form_model_test` y flujos |
| P2 | Medido: 500 entradas con íconos (~2 MB) tardan unos 17 ms por guardado en escritorio. Un isolate no ayuda, porque copiar la bóveda cuesta lo mismo. Se aplicó `JsonUtf8Encoder` (mismos bytes, −13 % y una copia de 2 MB menos). | Codec existente. Pendiente: medir en el Redmi |
| P3 | `searchEntries` (pura, cada título se pasa a minúsculas una vez) y resultado memorizado mientras no cambien la bóveda ni la búsqueda. | `search_entries_test` |
| T3 | Auto-bloqueo y sync automática con reloj simulado (`fake_async`). Las pantallas con I/O real usan `waitForIo` (reintenta sin espera fija). | — |
| T4 | `vault_session_controller_test` (1062 líneas) quedó en 6 archivos por tema, más `vault_session_harness.dart`. | — |
| T5 | Comentarios de los tests de biometría actualizados. | — |
| T6 | Extensión: `background.test` (el origen sale de la pestaña, iframes y otras extensiones ignorados, pendiente, respuesta y vencimiento) y `capture.test` con linkedom (envío, una sola vez, aviso fuera de la página). El canal C++ de la Store sigue siendo prueba manual con el MSIX. | — |
| T7 | Presentación subió a 92,8 %. | — |
| Clean code | Los 10 `catch (_) {}`: cinco pasaron a `saveAppliedPreference` (una sola regla, con test) y los otros cinco explican por qué. El botón de "mostrar contraseña" ya no cuenta como envío. Cabecera AGPL en `flutter_window.*`. | `preferences_test` |

