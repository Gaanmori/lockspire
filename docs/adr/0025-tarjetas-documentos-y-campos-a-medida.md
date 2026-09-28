# ADR 0025 — Tarjetas, documentos, varios sitios y apps, y campos a medida

- **Estado:** Aceptado
- **Fecha:** 2026-09-28
- **Amplía:** ADR 0004 (formato de bóveda v1), ADR 0009 (merge por campo)
- **Origen:** el usuario revisó cómo exporta SafeInCloud y pidió conservar todo en campos con nombre, no amontonado en notas:
  - varios sitios web por entrada;
  - apps Android (paquetes);
  - tarjetas: número, titular, vencimiento, CVV y PIN;
  - documentos: cédula, pasaporte y sus fechas;
  - el resto de campos con su nombre.
- **Fuera de alcance por decisión del usuario:** TOTP (generar códigos), carpetas, notas seguras, colores, fechas de creación y modificación importadas, hash MD5 e historial del generador.

## Decisión

Se mantiene el modelo de `VaultEntry.fields` como mapa de texto (ADR 0004). Así el merge por campo (ADR 0009) y el historial por campo funcionan sin cambios para todo lo nuevo. Lo que cambia son **keys con convención** y **dos tipos de entrada**.

### Tipos

`VaultEntryType` gana `card` y `document`. Leer un tipo desconocido ya no rompe: se trata como `password`, pensando en tipos futuros. Las versiones anteriores de la app **no** pueden leer `card` ni `document`, así que todos los dispositivos deben actualizarse, igual que en ADR 0019 y 0023.

### Keys

| Qué | Keys |
|---|---|
| Sitios web | `url`, `url_2`, `url_3`, … |
| Apps Android (paquete) | `app`, `app_2`, … |
| Tarjeta | `card_number`, `card_holder`, `card_expiry`, `card_cvv`, `card_pin` |
| Documento | `doc_number`, `doc_name`, `doc_birth_date`, `doc_issued`, `doc_expiry` |
| Campo a medida visible | `custom:<nombre>` |
| Campo a medida oculto (PIN, clave extra, secreto 2FA) | `hidden:<nombre>` |

- `url` sigue siendo el sitio principal, así que el código y los datos existentes no cambian.
- Un campo repetido usa una key por valor, no una lista en un solo campo. Así dos dispositivos que agregan sitios distintos no se pisan la lista entera en el merge.
- El nombre del campo a medida es parte de la key. Renombrar equivale a borrar y crear.

### Uso de los sitios y apps

- El autofill (Android y extensión) considera **todos** los sitios de la entrada, con las mismas reglas de origen de ADR 0013/0020.
- En Android, una entrada cuyo paquete coincide **exactamente** con la app que pide aparece primero, antes que la heurística de nombre (ADR 0011).

### Import de SafeInCloud

- **Tarjeta:** si algún campo tiene `autofill="cc-*"`.
- **Documento:** si el símbolo es `id`, `passport` o `social_security`, o si tiene fechas y no tiene usuario, contraseña ni sitio. Sus campos se asignan por nombre.
- **Resto de campos:**
  - `login` → `username`;
  - `password` → `password`;
  - `website` → `url`/`url_N`;
  - `application` → `app`/`app_N`;
  - `text` → `custom:` (o `notes` si se llama "Notas");
  - `pin`, contraseñas extra y secretos 2FA → `hidden:`;
  - `number`, `date`, `expiry` y `phone` → `custom:`.
- **Historial** (`history`, JSON `{ms: valor}`): los valores anteriores no vacíos pasan a `fieldHistory` de su key (máximo `maxFieldHistoryPerField`, los más recientes).
- Se ignoran:
  - papelera y plantillas;
  - `score`, `hash`, etiquetas, color, símbolo, estrella, `record` y `ghost`;
  - las fechas de la tarjeta (se importa con la fecha de hoy).

## Consecuencias

- Un solo modelo de datos para todo, sin migración del archivo: las entradas existentes siguen igual.
- El formulario de entrada muestra secciones según el tipo, listas de sitios y apps, y campos a medida.
- Las líneas transicionales `[safeincloud-import …]` de ADR anteriores dejan de generarse. Las ya importadas siguen en notas y se pueden reprocesar con la misma regex si hiciera falta.
