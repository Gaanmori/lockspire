# ADR 0031 — Ícono del lanzador de Android según el tema

- **Estado:** Aceptado
- **Fecha:** 2026-09-29
- **Amplía:** el ícono temático de la app (ventana, bandeja y extensión, revisión de diseño del 2026-09-29)
- **Origen:** el usuario vio que en Android el ícono del lanzador no seguía al tema. Eligió que cambie solo al elegir el tema, conociendo que algunos lanzadores quitan el acceso directo de la pantalla de inicio.

## Decisión

- **Íconos generados:** `tools/generate_icons.py` genera un juego de íconos por tema (normal, adaptativo con fondo del acento, y el mismo monocromo para los íconos temáticos de Android 13+). Los colores son los de `LockspireIconColors` y la extensión.
- **Manifiesto:**
  - `MainActivity` ya no es la entrada del lanzador.
  - Hay un `activity-alias` por tema (`.LauncherLineage`, `.LauncherPixel`, `.LauncherUbuntu`, `.LauncherMint`, `.LauncherWindows`) con su ícono. Solo `.LauncherLineage` viene activo.
- **Cambio de ícono:** `LauncherIcon.kt` (canal `launcher_icon`) deja activo solo el alias del tema elegido.
  - Primero activa el nuevo y después apaga los demás, así la app nunca queda sin ícono.
  - Usa `DONT_KILL_APP`.
  - Si el alias ya está activo no toca nada: cada cambio de componente puede hacer que el lanzador quite el acceso directo.
- **Disparador en Dart:** `launcherIconSync` escucha el tema elegido desde el arranque de la app.
- **"Colores del sistema":** usa el ícono de Lineage, porque los íconos alternativos tienen que existir al compilar. El ícono temático de Android 13+ ya lo colorea el sistema.
- **Aviso:** Apariencia avisa en Android lo del acceso directo.

## Consecuencias

- El ícono del teléfono coincide con el tema, como en escritorio y en la extensión.
- Cambiar de tema puede dejar un acceso directo huérfano en algunos lanzadores (HyperOS incluido), y el cambio puede tardar unos segundos.
- Un intent explícito a `.MainActivity` (por ejemplo, `adb shell am start -n com.lockspire.lockspire/.MainActivity`) sigue funcionando.
