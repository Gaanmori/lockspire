# ADR 0020 — Autofill de Android por dominio web, con aviso ante posible phishing

- **Estado:** Aceptado
- **Fecha:** 2026-09-27
- **Origen:** revisión de seguridad 2026-09-25, hallazgo S6. Extiende ADR 0011 (autofill Android) y reusa las reglas de coincidencia de origen de ADR 0013 y 0015.

## Contexto

El autofill de Android (ADR 0011) solo conoce el **paquete** de la app que pide credenciales. En un navegador o en un `WebView`, ese paquete es el del navegador o el de la app que aloja la página, no el sitio. La lista se ordena por parecido de texto con el nombre del paquete (`matchEntriesForPackage`) y cualquier entrada se rellena sin preguntar. Una página falsa (`banco-falso.com`) dentro de un navegador o de un WebView puede recibir la contraseña del banco sin ninguna advertencia. La extensión de escritorio no tiene este problema, porque rellena solo si el origen coincide (ADR 0013).

El Autofill Framework sí informa el dominio de la página: `ViewNode.getWebDomain()` desde Android 8 y `getWebScheme()` desde Android 9. Lo completan los navegadores y los `WebView`.

## Decisión

### 1. El servicio nativo pasa el dominio, sin decidir nada

`LockspireAutofillService` lee `webDomain` y `webScheme` de la estructura y los pasa a `AutofillActivity` junto al paquete, tanto al pedir credenciales como al guardarlas. Sigue siendo delgado (ADR 0011): no lee la bóveda ni decide nada. Toda la lógica está en Dart, en `lib/features/autofill/domain`.

- **Esquema desconocido** (Android 8 o un navegador que no lo informa): se asume `http`. Así una entrada guardada como `https` no coincide y se pide confirmación. Ante la duda, pesa la protección contra downgrade de ADR 0013, no la comodidad.
- **Credential Manager** (`LockspireCredentialProviderService`) queda **como está, sin dominio**. Solo informa el origen web a los navegadores de una lista privilegiada firmada, y hoy lo usan sobre todo apps nativas. Integrarlo es trabajo aparte.

### 2. Reglas cuando hay dominio web

Con el origen armado (esquema + dominio), cada entrada se clasifica con las mismas reglas que la extensión (`entryMatchesOrigin`: mismo host o subdominio, sin downgrade `https`→`http`):

| Entrada | Qué pasa al elegirla |
|---|---|
| **Coincide** con el sitio | Se rellena directamente. Aparece arriba en la lista, marcada. |
| **Tiene otro sitio** guardado | **Advertencia de posible phishing**, con el sitio de la entrada y el de la página. Rellenar exige confirmarlo. |
| **No tiene sitio** guardado | Se pregunta: "Rellenar y recordar este sitio" (guarda la URL con `linkedUrlForOrigin`, igual que ADR 0015), "Solo esta vez" o "Cancelar". |

- La lista **no oculta** nada: las entradas que no coinciden siguen visibles y con buscador, igual que hoy. El usuario puede necesitarlas, por ejemplo con dominios distintos del mismo servicio.
- **Guardar** una credencial nueva desde un sitio usa el dominio como título y la URL del sitio (`linkedUrlForOrigin`), en vez del paquete del navegador. La próxima vez coincide sola.

### 3. Sin dominio web (app nativa)

Sin cambios: la heurística por paquete de ADR 0011. Vincular apps a entradas queda para después.

### 4. Qué se muestra

La pantalla indica **quién pide**, con el sitio de la página y la app que lo muestra ("en Chrome" o "dentro de la app X"). Así el usuario ve de un vistazo si el sitio no es el que espera.

## Consecuencias

- **Una página falsa ya no recibe una contraseña sin advertencia.** Para rellenar hace falta que el sitio coincida o que el usuario confirme conscientemente la advertencia.
- Rellenar una entrada sin sitio guardado agrega un paso, pero solo la primera vez si se elige "recordar este sitio".
- **Límites documentados:**
  - El dominio lo informa la app que muestra la página. Una app maliciosa podría declarar `banco.com` en su propia vista. Esto no empeora el caso sin dominio, en el que cualquier app nativa ya puede mostrar un formulario falso. La verificación fuerte, Digital Asset Links (paquete ↔ dominio) o una lista de navegadores con certificados fijados como la privilegiada de Credential Manager, queda como mejora futura.
  - Credential Manager no aplica estas reglas todavía (ver 1).
  - Las apps nativas siguen dependiendo de la heurística por paquete.
