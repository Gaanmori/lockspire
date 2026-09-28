# ADR 0028 — Canales de distribución del MVP

- **Estado:** Aceptado
- **Fecha:** 2026-09-28
- **Reemplaza:** la decisión de MVP del 2026-09-27 registrada en `docs/STATE.md` ("lanzamiento sin costo → Linux y Android vía F-Droid").
- **Origen:** al revisar qué exigía F-Droid se vio que Google no admite, para clientes Android, ninguna forma de iniciar sesión sin Play Services que sirva en HyperOS sin rodeos (ver "Google Drive en Android sin Play Services" en STATE). El usuario comparó costos y eligió publicar en tiendas.

## Decisión

El MVP se publica en:

| Plataforma | Canal | Costo |
|---|---|---|
| Android | Google Play | US$25 una vez |
| Windows | Microsoft Store (MSIX) | Gratis (cuenta individual) |
| Linux | AppImage (GitHub Releases), Snap Store y Flathub | Gratis |
| Extensión | Chrome Web Store | US$5 una vez |
| Extensión | Edge Add-ons | Gratis |

- **F-Droid queda fuera por ahora.** El login de Google Drive en Android sigue siendo el nativo (`google_sign_in`, Play Services).
- **Una sola política de privacidad** (`docs/privacy-policy.md`, publicada con GitHub Pages) sirve para todas las tiendas y para la verificación de la pantalla de consentimiento de Google.
- La AGPLv3 se cumple con una pantalla **"Acerca de"** que enlaza el código fuente.

## Consecuencias

- **Google Play:**
  - La prueba cerrada obligatoria (12 probadores durante 14 días) hace que convenga crear la cuenta pronto.
  - El proyecto de Google Cloud tiene que pasar a producción.
  - Android necesita una clave de firma release propia.
- **Microsoft Store:** la app corre aislada (MSIX). Hay que comprobar que Chrome y Edge encuentran el native host de la extensión (ADR 0013/0014) cuando la app viene de la tienda.
- **Snap y Flathub:** su aislamiento complica el native host y, en Snap, quizá la confinación "classic" requiera aprobación. AppImage no tiene ese problema y va primero.
- **Volver a F-Droid** implicaría resolver Google Drive sin Play Services (opciones en STATE) o publicar ese build sin Drive.
