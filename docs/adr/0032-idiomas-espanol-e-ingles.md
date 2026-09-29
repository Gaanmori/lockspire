# ADR 0032 — Idiomas: español e inglés

- **Estado:** Aceptado
- **Fecha:** 2026-09-29
- **Origen:** el usuario pidió un selector de idioma para el MVP, solo con español e inglés por ahora. Eligió que la app siga el idioma del sistema y tenga un selector en ajustes. Pidió que agregar otro idioma más adelante sea fácil.

## Decisión

### Textos de la app

- **Mecanismo estándar:** Flutter `gen-l10n` con archivos ARB en `app/lib/l10n/`.
  - `app_es.arb` es la plantilla: el español se escribe primero y en "usted".
  - `app_en.arb` tiene exactamente las mismas claves.
  - El código generado va en `lib/l10n/generated/`.
- **Acceso desde las pantallas:** `context.l10n.clave` (extensión en `lib/l10n/l10n.dart`).
- **Plurales y concordancia de género:** con ICU (`plural`, `select`). Nunca se arma una frase concatenando pedazos: "Nueva ${tipo}" daba "Nueva documento".
- **Agregar un idioma:**
  1. Crear `app_xx.arb`.
  2. Agregar `xx` a `AppLanguage`, al selector de Apariencia y a `MESSAGES` de la extensión, con su `_locales/xx`.
  3. Hacer que `resolveSystemLocale` lo reconozca.

  Las pantallas no se tocan.

### Elección del idioma

- **Preferencia:** `AppLanguage { system, es, en }` es parte de `AppearancePreference` y se guarda en la clave `appearance.language`.
- **Idioma del sistema:** en modo `system`, `resolveSystemLocale` elige español si el sistema está en cualquier variante de español, e inglés en cualquier otro caso.
- **Ámbito:** lo usan las dos `MaterialApp`, la app y la de autocompletado de Android.
- **Sin `BuildContext`:** `appL10nProvider` da los textos del idioma activo a quien no tiene contexto. Por ejemplo:
  - el motivo del diálogo de huella o de Windows Hello, que se pasa al adaptador desde la raíz de composición;
  - el idioma que se informa a la extensión.
- **Menú de la bandeja:** se rearma al cambiar el idioma.

### Errores y valores: ningún texto fuera de la presentación

- **Errores:** dominio, casos de uso y adaptadores no conocen el idioma.
  - Lanzan `AppProblem(AppProblemCode, detail:)` (en `lib/shared/domain/app_problem.dart`) o sus excepciones tipadas de siempre.
  - La presentación los traduce con `localizeError(l10n, error)`.
  - `detail` lleva solo lo que no se traduce: el mensaje de un servidor, una ruta, un código HTTP o el nombre de un proveedor.
  - Un error ajeno a la app se muestra tal cual.
- **Valores con palabras:** salen de las capas internas como datos y la presentación los pone en palabras (`lib/l10n/localized_values.dart`):
  - el tiempo estimado de descifrado (`CrackTime`, unidad y cantidad);
  - el método biométrico (`BiometricMethod`);
  - el formato de exportación (`ExportFormat`);
  - el navegador que pide el autocompletado (`knownBrowserName`).
- **Política de contraseña maestra:** `checkNewMasterPassword` devuelve el problema y la presentación da el mensaje (`localizeMasterPasswordProblem`).

### Extensión del navegador

- **Idioma del popup:** sigue al de la app.
  - La app informa el idioma efectivo en el campo opcional `lang` del `PONG` ("es" o "en"). Una extensión vieja lo ignora; no hace falta subir la versión del protocolo.
  - Hasta que responde la app, el popup usa el último idioma recordado o, la primera vez, el del navegador.
  - Los textos están en `extension/src/i18n.ts`, y el tipo obliga a que el inglés tenga las claves del español.
- **Tienda:** el nombre y la descripción usan `_locales` (`__MSG_extName__`, `__MSG_extDescription__`) con `default_locale: en`. Así la tienda los muestra en el idioma del navegador.

### Generador "fácil de recordar": siempre en inglés

- **Una sola lista:** usa siempre la lista en inglés (EFF, 4438 palabras), sea cual sea el idioma de la app.
- **Lista en español eliminada:** existía una (`dadoware-bonito-es`, GFDL 1.3) para sistemas en español. La quité junto con su licencia a pedido del usuario: sus frases salían más débiles en el medidor.
- **Otras ventajas:** una sola lista ASCII evita teclas muertas y la ñ al teclear la contraseña en otro dispositivo.
- **Medidor:** sigue asumiendo 3050 palabras por palabra generada. Así subestima (el lado seguro) las contraseñas guardadas que se generaron con la lista española.

### Controles

- **`test/l10n_test.dart`:** cada idioma tiene las claves de `es`, con los mismos parámetros, y ningún texto vacío.
- **`test/ui_register_test.dart`:** revisa todo `lib/`, incluido el español generado desde el ARB. Ahora también detecta "verificate", "estarías" y "tuyo/tuya".
- **Tests de la extensión:** comprueban las mismas claves, el registro "usted", el `lang` del `PONG` y los `_locales`.

## Pendiente

- **Etiquetas de importación y exportación:** siguen en español. Son datos que se guardan en la bóveda o viajan en el archivo exportado:
  - los nombres de campos importados ("Teléfono", "Empresa", "Sin título");
  - las etiquetas de tarjeta y documento en las notas del CSV de Bitwarden.

  La importación usa esas mismas etiquetas para reconocer los campos de vuelta. Para traducirlas, la exportación tendría que usar el idioma activo y la importación reconocer las etiquetas de todos los idiomas.
- **Página de retorno del inicio de sesión de Microsoft:** se muestra en los dos idiomas a la vez. Es fija y no lleva datos.

## Consecuencias

- La app, el autocompletado de Android, el diálogo biométrico, la bandeja y la extensión muestran el mismo idioma.
- Todo texto nuevo de la interfaz va a los ARB. Un literal en español en una pantalla es un error de revisión, aunque todavía no hay un test que lo detecte.
- Se corrigieron de paso textos que no estaban en "usted" y concordancias de género.
