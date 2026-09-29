# ADR 0030 — Íconos: respaldo opcional con DuckDuckGo

- **Estado:** Aceptado
- **Fecha:** 2026-09-29
- **Amplía:** ADR 0029 (íconos de sitios y apps)
- **Origen:** con los íconos directos activados, el usuario vio que varios sitios no ofrecen uno (Agrocampo, AnyDesk…). Pidió poder completar esos con DuckDuckGo, la alternativa que se había descartado como opción principal.

## Decisión

- **Segunda opción, apagada por defecto:** Seguridad → "Completar los que falten con DuckDuckGo". Solo se muestra con los íconos activados.
- **Solo los que faltan:** se consulta `https://icons.duckduckgo.com/ip3/<dominio>.ico` únicamente para los sitios donde la descarga directa no encontró ícono.
  - Esos sitios tienen el marcador `''` en `Vault.siteIcons` (`hostsForIconFallback`).
  - DuckDuckGo recibe solo esos dominios: nunca usuarios, contraseñas ni el resto de la lista.
- **Mismos límites que ADR 0029:** `https`, tiempo, tamaño y reducción a 48 px. Es `HttpSiteIconFetcher.duckDuckGo`.
- **Marcadores:**
  - `''`: el sitio no ofrece ícono; se le puede preguntar a DuckDuckGo.
  - `'-'`: tampoco DuckDuckGo tiene uno; no se vuelve a preguntar.
  - En el merge, un ícono real le gana a cualquier marcador. "Volver a buscar los que faltan" borra los dos.

## Consecuencias

- Más entradas con ícono, a cambio de que DuckDuckGo conozca los dominios de los sitios que no ofrecen uno propio. El usuario decide, con el texto de la opción que lo explica.
