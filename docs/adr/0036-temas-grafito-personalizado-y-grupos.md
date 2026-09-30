# ADR 0036 — Temas: Grafito por defecto, Personalizado y grupos

- **Estado:** Aceptado
- **Fecha:** 2026-09-30
- **Origen:** el usuario pidió tres cosas:
  - que el ícono grafito del sistema también fuera un tema, y el predeterminado;
  - un tema para elegir cualquier color;
  - agrupar los temas, que ya eran muchos, con permiso para renombrarlos.
- **Relación:**
  - amplía los ADR 0029 y 0031 (ícono según el tema);
  - reemplaza a Lineage como tema por defecto.

## Decisión

### Temas y grupos

| Grupo | Temas |
|---|---|
| **Lockspire** | **Grafito** (por defecto) y **Personalizado** |
| **Automático** | Colores del sistema |
| **Inspirados en sistemas operativos** | LineageOS (antes "Lineage"), Pixel, Ubuntu, Linux Mint y Windows 11 |

- **Grafito:** paleta fija y sobria, con grises casi sin color.
  - En claro, el acento es grafito `#2B2E32` y los botones llevan texto blanco. En oscuro, el acento se invierte a gris claro `#D9DCE0` con texto grafito.
  - Cumple los mismos contrastes WCAG que las demás paletas (`lockspire_theme_test`).
- **Personalizado:** el usuario elige un color, entre 14 sugeridos o cualquiera en hexadecimal. La paleta clara y oscura sale del algoritmo tonal de Material 3 (`LockspirePalette.fromSeed`), el mismo de "Colores del sistema".
  - El color se guarda en `appearance.custom_color`, siempre opaco, y se conserva al cambiar a otro tema.
- **Los grupos** son del dominio (`ThemeGroup`), así la pantalla solo los recorre.

### Íconos

- **Android:**
  - El ícono de la app (`android:icon`) es el grafito. Lo usan el diálogo de la huella, "Información de la aplicación", el autocompletado y Credential Manager, que Android no deja cambiar en ejecución.
  - El lanzador tiene un alias `LauncherGrafito`, activo por defecto.
  - Personalizado y Colores del sistema usan el ícono Grafito en el lanzador, porque Android no permite íconos generados.
- **Escritorio y bandeja:** el ícono sale de la paleta de cada tema (`LockspireIconColors.fromPalette`). Personalizado tiene el suyo, con el color elegido.
- **Extensión:** Grafito tiene sus colores y su ícono. Personalizado y Colores del sistema se muestran como Grafito, porque el popup no genera paletas.

## Consecuencias

- **Quien no había elegido tema** pasa de Lineage a Grafito. Quien había elegido uno lo conserva.
- **En Android**, el acceso directo del lanzador pasa del alias de Lineage al de Grafito en esta versión. Algunos lanzadores lo quitan y hay que volver a ponerlo. Todavía no hay usuarios fuera del autor.
- **Agregar un tema fijo** sigue siendo lo mismo de antes:
  - una paleta en `lockspire_colors.dart`;
  - un valor en `ThemeFamilyId` y en `LockspireThemeFamily`;
  - un alias en el manifiesto y en `LauncherIcon.kt`;
  - su bloque en `popup.css`.
