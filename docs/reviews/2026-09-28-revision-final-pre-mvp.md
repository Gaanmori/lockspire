# Revisión final antes del MVP — 2026-09-28

Alcance: todo `app/lib`, el código nativo de Android (Kotlin), los manifiestos y el repositorio público. Foco en lo que cambió desde la revisión del 2026-09-25 (ADRs 0023–0028: nube de la bóveda, contraseña cambiada en otro dispositivo, tarjetas y documentos, sesión de autofill, exportar e importar, canales de distribución).

Método:
- Comprobaciones automáticas: dependencias entre capas y features, tamaño de archivos, excepciones silenciadas, `print`/`TODO`, cabeceras de licencia, patrones inseguros (`Random()`, `http://`, certificados, portapapeles directo), componentes exportados y permisos de Android, secretos y datos personales en el repositorio y en su historial.
- Lectura del código nuevo más sensible (autofill nativo, sesión de autofill, OAuth de Google en Android, casos de uso de exportar e importar).
- Build release para detectar problemas de R8.

Leyenda: ✅ corregido en esta revisión · 📄 aceptado y documentado · 🟡 recomendación, no bloquea.

## Veredicto

**Sólido para el MVP**, con los arreglos de abajo ya hechos. No quedan hallazgos de severidad alta abiertos. Lo pendiente es de mantenimiento (tamaño de algunas pantallas y controllers) y de cobertura de pruebas del código nativo.

## Seguridad

| # | Sev. | Hallazgo | Estado |
|---|---|---|---|
| S14 | 🔴 | **Autofill directo por dominio declarado por cualquier app (ADR 0026).** El dominio web de `AssistStructure` lo declara la app que pide. Una app maliciosa podía mostrar un formulario falso, declarar `banco.com` y recibir la cuenta directa en el desplegable, sin el aviso "dentro de la app X" del flujo normal (ADR 0020). | ✅ `AutofillSession.matching` solo ofrece cuentas directas por dominio si quien pide es un navegador conocido (`trustedBrowserPackages`, misma lista que ya usaba Dart) o una app guardada en esa entrada. En cualquier otra app se sigue el flujo normal con su aviso. |
| S15 | 🟠 | **Token de la nube vencido reutilizado** (encontrado por el usuario). El puerto de sync se guardaba mientras vivía el proceso con un token de ~1 h. | ✅ `freshActiveSyncPort`/`freshSyncPortFor` en cada operación. En Android, Google Drive se autoriza en silencio con el correo guardado (sin la hoja "Iniciando sesión"). |
| S16 | 🟡 | **La consulta previa al desbloqueo descargaba la bóveda en cada autocompletado.** Gastaba datos y tiempo sin aportar nada para rellenar. | ✅ `UnlockVaultScreen(checkCloudForPasswordChange: false)` en el motor de autofill. |
| S17 | 🟡 | **Condición de carrera con la clave de la biometría** (encontrada por el usuario): tras adoptar una contraseña nueva se ofrecía activar la huella a quien ya la tenía. | ✅ Se reemplaza antes de abrir la bóveda y sin borrar antes. |
| S13 | 🟡 | Secretos en memoria como `Uint8List`/`String`, sin borrado explícito. | 📄 ADR 0008. |
| — | 🟡 | Credenciales en memoria nativa durante la sesión de autofill (hasta el tiempo del auto-bloqueo o el apagado de pantalla). | 📄 ADR 0026, aceptado por el usuario. |
| — | 🟡 | Windows Hello: la clave de biometría la protege DPAPI (sesión de Windows) y la exigencia de Windows Hello es de la app, no del sistema. | 📄 ADR 0010. |
| — | 🟡 | Exportaciones sin cifrar. | 📄 ADR 0027: pide la contraseña maestra, advierte antes y recuerda borrar el archivo después. |

**Verificado sin hallazgos:**
- **Repositorio (ya público):** sin secretos, claves ni datos de la bóveda, tampoco en el historial. Solo quedan públicos los `.example` de OAuth.
- **Android:**
  - `allowBackup="false"` (S10).
  - `AutofillActivity` no exportada.
  - Los servicios exportados exigen `BIND_AUTOFILL_SERVICE` / `BIND_CREDENTIAL_PROVIDER_SERVICE`.
  - La única actividad exportada sin permiso es `OAuthRedirectActivity`, que exige `state` y PKCE (ADR 0022).
- **Código:**
  - No hay `Random()` no criptográfico.
  - WebDAV rechaza `http://`.
  - El portapapeles solo se usa a través de `ClipboardGuard` (S4).
  - No hay logs.
  - Las comparaciones de `state` y de la contraseña maestra al exportar son en tiempo constante.
- **Importar:**
  - XML sin XXE (test).
  - El respaldo `.lockspire` pasa por `VaultFileCodec.decode` (límites de Argon2id: un archivo hostil no puede pedir una derivación enorme) y por AEAD antes de usarse.
  - Un JSON cifrado de Bitwarden se rechaza.

## Arquitectura

- **Capas:** ningún `domain/` importa Flutter, Riverpod, `infrastructure/` ni `presentation/`. Ningún `application/` importa `infrastructure/` ni `presentation/`.
- **Features:**
  - Sin ciclos: `vault` es el núcleo y solo depende de `clipboard`; `sync`, `autofill`, `browser_bridge` y `desktop` dependen de `vault`.
  - Las conexiones inversas (`vault` usa la sync sin conocerla) pasan por puertos definidos en `vault` y se conectan en `lib/app_composition.dart`: réplica del cambio de contraseña (ADR 0018) y contraseña cambiada en otro dispositivo (ADR 0024).
- **Formatos de exportación e importación:** son adaptadores detrás de `VaultImportSource`/`VaultExporter` (ADR 0027). Agregar uno no toca dominio ni casos de uso.
- **Código nativo:** delgado (ADR 0021). La única regla que vive en Kotlin es la coincidencia de la sesión de autofill: Dart ya reduce cada sitio a host + "exige https" y pasa la lista de navegadores de confianza.

| # | Sev. | Recomendación |
|---|---|---|
| A9 | 🟡 | **`SyncController`** (295 líneas) junta conectar/desconectar/mudar nubes con sincronizar/adoptar contraseña. Separar un `SyncAccountsController` cuando se toque de nuevo. |
| A10 | 🟡 | **Pantallas grandes:** `entry_form_screen` (542), `autofill_screen` (519), `vault_unlocked_screen` (484), `sync_settings_screen` (471). Ya delegan en widgets propios; extraer más si siguen creciendo. |

## Clean code

- ✅ **Normalizar nombres de campo:** había dos funciones casi iguales (una sin la ñ). Ahora hay una sola, `normalizeFieldName` (`interchange/entry_mapping.dart`).
- Sin `print`, `TODO` ni `FIXME`. Todos los archivos llevan la cabecera AGPL.
- Los 6 `catch (_) {}` que quedan son intencionales y están comentados: preferencias con valor por defecto, reemplazo de la clave de biometría, inicio de la sesión de autofill y la marca de contraseña cambiada.
- Textos de la interfaz en "usted" (test `ui_register_test.dart`).

## Rendimiento

- **Argon2id** corre fuera del hilo de la interfaz (arreglo de Fase 5).
- **Guardar** cifra con la clave de la sesión, sin re-derivar.
- **La sync automática** tiene debounce.
- **Búsqueda y orden de la lista:** se recalculan en cada build. Con ~230 entradas no se nota; memorizar si una bóveda pasa de unos miles.
- **Token fresco en cada operación:** es una llamada extra por sync (autorización silenciosa en Android, refresh en escritorio y OneDrive). Es despreciable frente a descargar la bóveda.
- **Al abrir la app** se descarga la bóveda dos veces (consulta previa al desbloqueo y sync tras desbloquear). Es aceptable por su tamaño. Se podría reutilizar la primera descarga si la bóveda creciera mucho.

## Pruebas

- 333 tests de la app y 9 de la extensión, en verde.

| # | Sev. | Recomendación |
|---|---|---|
| T1 | 🟡 | El Kotlin del autofill no tiene tests unitarios, incluida la regla de S14. Se verificó en el Redmi, y la parte que decide en Dart sí tiene tests. |
| T2 | 🟡 | Sin tests de widgets para Exportar, Importar y el formulario por tipo. La lógica debajo sí está cubierta (`interchange_test`, `entry_fields_test`, `vault_import_merge`). |

## Preparación para release

| # | Sev. | Hallazgo | Estado |
|---|---|---|---|
| R1 | 🔴 | **El manifiesto principal no pedía `INTERNET`.** Solo estaba en los de debug y profile (plantilla de Flutter), así que el build release no podía sincronizar. No se había visto porque todas las pruebas fueron con debug. | ✅ Agregado al manifiesto principal. |
| R2 | 🟠 | El release firma con la clave de depuración. | Pendiente: clave de subida propia para Google Play (checklist del MVP, ADR 0028). |
| R3 | — | Build release con R8. | Ver el resultado en `docs/STATE.md`. |
