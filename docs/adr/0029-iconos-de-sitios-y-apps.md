# ADR 0029 — Íconos de sitios y apps en las entradas

- **Estado:** Aceptado
- **Fecha:** 2026-09-29
- **Origen:** el usuario pidió que cada entrada muestre algo alusivo al sitio o la app en vez de una letra. Eligió la opción "del propio sitio, opcional" entre tres (del sitio; de un servicio de terceros como DuckDuckGo; solo apps instaladas y letras).

## Decisión

1. **Opcional y apagado por defecto** (Seguridad → "Íconos de los sitios"): descargar el ícono le hace saber a cada sitio que alguien lo visitó desde esa conexión. Sin activarlo, la inicial.
2. **Directo del sitio, sin terceros** (`HttpSiteIconFetcher`). Así ningún servicio recibe la lista de sitios de la bóveda. Por orden:
   - `apple-touch-icon`;
   - `<link rel="icon">`, por tamaño declarado;
   - `/favicon.ico`.
3. **Límites:**
   - **Protocolo:** solo `https`, también en redirecciones (se siguen a mano, hasta 3).
   - **Tiempo y tamaño:** 6 s por petición, 256 KB de HTML, 300 KB de imagen.
   - **Formato:** sin SVG ni `data:`.
   - **Sitios consultables:** nunca `localhost`, IPs ni nombres de red local (`.local`, `.lan`, `.internal`, `.home.arpa`, sin punto). Activar los íconos no sondea la red de la casa u oficina.
4. **Guardados en la bóveda** (`Vault.siteIcons`, host sin `www.` → PNG de 48 px en base64, o `''` si el sitio no tiene):
   - Son cifrados y sincronizados, así cada sitio se consulta una vez en total y no una por dispositivo.
   - Van uno por sitio, aunque varias entradas lo compartan.
   - El merge une ambos lados, y un ícono encontrado le gana a "sin ícono".
   - "Volver a buscar los que faltan" borra los `''`.
5. **Cuándo se buscan:** al abrir la bóveda y tras cada guardado (`SiteIconsController`, por los `VaultEvent`), todos juntos, de a 4 en paralelo y con un solo guardado. Sin conexión no se marca nada: se reintenta después. Nunca se muestra un error.
6. **Android:** si no hay ícono de sitio, el de la app instalada que tenga guardada la entrada. Se lee del sistema, sin red, con el canal `app_icons`, y solo queda en memoria. La visibilidad de apps se pide con `<queries>` de las apps con ícono en el lanzador, no con `QUERY_ALL_PACKAGES` (que Google Play restringe).
7. **Letra mejorada:** el primer carácter útil del título, o del sitio si el título no tiene ninguno ("::.SM4 Web.::" → S).

## Consecuencias

- La lista se reconoce de un vistazo.
- La bóveda crece unos pocos KB por sitio con ícono (48 px), aceptable para un archivo que se reescribe y sincroniza entero.
- Las versiones anteriores de la app no conocen `site_icons` y lo pierden si guardan. Todos los dispositivos deben actualizarse, como en ADRs anteriores.
