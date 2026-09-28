# Sistema de diseño — Lockspire

Dirección visual elegida por el usuario: **cálido y cercano** (frente a "minimalista y clínico" estilo 1Password/Bitwarden, y "técnico y directo" estilo KeePassXC — descartadas). Objetivo: bajar la barrera de entrada a alguien que nunca usó un gestor de contraseñas.

Canvas editable (fuente viva de este sistema, con los mockups aplicados a móvil y escritorio): https://claude.ai/code/artifact/3066d5e2-2452-4cf6-af99-e51ec83f0f0f

Este documento es el resumen en texto para que cualquier agente/dev pueda implementar contra estos valores sin depender de abrir el canvas.

## Color

| Token | Hex | Uso |
|---|---|---|
| `bg/page` | `#FFF8F1` | Fondo general de pantalla |
| `bg/surface` | `#FFFFFF` | Tarjetas, superficies elevadas |
| `bg/surface-subtle` | `#FDEDE6` | Chips de icono, fondos sutiles de acento |
| `bg/input` | `#F6ECE1` | Fondo de campos de texto en estado default |
| `text/primary` | `#3A2E2A` | Texto principal |
| `text/secondary` | `#8A7A73` | Texto secundario, captions, labels |
| `text/placeholder` | `#C9B8AF` | Placeholder de inputs |
| `accent/default` | `#EA6C4D` | Acento primario (botones, iconos activos) |
| `accent/hover` | `#D65A3C` | Estado presionado del acento |
| `accent/secondary` | `#4FA391` | Confirmaciones / éxito |
| `danger` | `#C23B3B` | Errores (ej. contraseña incorrecta) |

La tabla de arriba es el tema **Cálido claro**, el original.

> **Desde 2026-09-27 el tema principal y por defecto es Lineage** (decisión del usuario), basado en el tema por defecto de LineageOS. Cálido sigue disponible como una familia más.

### Temas (2026-09-24)

Hay **5 familias, cada una en claro y oscuro** (10 temas). El usuario elige familia y modo (según el sistema, claro u oscuro) en la pantalla **Apariencia** de la app (`lib/features/appearance/`), y la extensión de navegador usa el mismo tema: la app se lo indica en la respuesta a `PING`.

| Familia | Claro: página / acento | Oscuro: página / acento |
|---|---|---|
| **Lineage** (por defecto) | `#F6FAFA` / `#167C80` | `#121212` / `#80D4D8` |
| **Pixel** | `#F9F9FF` / `#445E91` | `#111318` / `#ADC6FF` |
| Cálido | `#FFF8F1` / `#EA6C4D` | `#1E1714` / `#F07A5A` |
| Menta | `#F3FAF7` / `#178A6B` | `#0F1C18` / `#3CC49B` |
| Lavanda | `#F7F5FD` / `#6C5CE0` | `#16142A` / `#8F82F2` |

**Cuarta opción, "Colores del sistema"** (Material You): la paleta se **genera** con el algoritmo tonal de M3 (`ColorScheme.fromSeed` → `LockspirePalette.fromSeed`) a partir del color del sistema operativo: los colores del fondo de pantalla en Android 12+ y el color de acento en Windows, Linux y macOS. Lo obtiene el paquete `dynamic_color`, detrás de `SystemAccentColorPort`. Si la plataforma no ofrece color, se usa Lineage. El popup de la extensión todavía no replica la paleta generada y muestra Lineage.

Todos los tokens de cada tema están en `app/lib/design/lockspire_colors.dart` (`LockspirePalettes`) y, en espejo, en `extension/public/popup.css`.

- **Código:** cada tema es una `LockspirePalette`, una `ThemeExtension` con los mismos tokens de la tabla más `onAccent` (texto sobre el acento: blanco en los claros, el fondo de página en los oscuros). `LockspireTheme.of(palette)` construye el `ThemeData` y lo guarda en caché. Las pantallas leen `context.palette.X`, nunca un color fijo, así que un tema nuevo no toca ninguna pantalla.
- **Contraste verificado en tests** (`test/design/lockspire_theme_test.dart`, WCAG) para los 10 temas fijos y para paletas generadas desde rojo, amarillo, verde, azul, morado y gris: texto principal ≥ 7:1 sobre página y tarjetas, secundario ≥ 3:1, texto de botón sobre el acento ≥ 3:1. El verde de Menta claro se oscureció respecto a la primera propuesta (`#1F9E7A` → `#178A6B`) para cumplirlo con holgura.

### Tema Lineage: de dónde salen los colores

Basado en el tema por defecto de **LineageOS**, verificado en su código fuente el 2026-09-27:
- **Claro:** la paleta de marca de la wiki (`LineageOS/lineage_wiki`, `_sass/lineage/_theme.scss`):
  - primario `#167C80`, que también es `lineage_accent` en `android_packages_apps_SetupWizard`;
  - oscuro de marca `#324B4C`;
  - fondos `#F6FAFA`, `#E1EFEF` y `#CCE8E9`;
  - texto `#3C4858` y `#6C757D`;
  - secundario `#4A6364`, el tono secundario de Material You de `#167C80`. Al principio se usó el verde de éxito de la wiki (`#1F6B3A`), y el usuario notó que no era de LineageOS.
- **Oscuro:** en Android, LineageOS pasa la semilla `#167C80` por el algoritmo tonal de Material You (`lineage_accent` oscuro = `system_accent1_100`).
- **Clave:** la paleta de marca de LineageOS **es** la paleta secundaria de Material You de `#167C80`. "brand-light" `#CCE8E9` y "brand-dark" `#324B4C` coinciden exactamente con el contenedor secundario claro y su texto (en oscuro, al revés). Por eso lo seleccionado se ve teal claro con texto teal oscuro.
  - Acento: el tono 80 que da esa semilla (`#80D4D8`, texto encima `#003739`).
  - Fondos oscuros de marca: `#121212`, `#1F2526` y `#243738`.

Nota para la comercialización: "LineageOS" es una marca de su proyecto. El tema se llama "Lineage" por su inspiración; antes de lanzar conviene confirmar que el nombre no sugiera una afiliación, o renombrarlo.

### Tema Pixel: de dónde salen los colores

El aspecto de un **Google Pixel**. Material You genera todos los colores con el algoritmo tonal (*tonal spot*) a partir de una semilla; aquí la semilla es el azul de Google `#4285F4`. Los valores se calcularon con el mismo algoritmo que usa "Colores del sistema" (`LockspirePalette.fromSeed`) y quedaron fijos como en las demás familias. Por eso el acento no es el azul puro de Google: *tonal spot* lo suaviza, igual que en un Pixel. La tipografía sigue siendo la de Lockspire; Google Sans no tiene licencia libre.

### Estado seleccionado (todos los temas)

Lo seleccionado (segmentos, chips, indicador de la barra de navegación) usa un **contenedor tonal**, como en Material You: `secondaryContainer` = `bgSurfaceSubtle` con el texto principal encima, y no el acento sólido. Hasta el 2026-09-28 el tema no definía `secondaryContainer`, Flutter usaba `secondary`, y lo seleccionado salía como un bloque del color secundario. El contraste de ese texto se verifica en los tests (≥ 4.5:1).

## Tipografía

Dos familias (Google Fonts):

- **Quicksand** (600/700) — títulos, nombre de la app, texto de botones.
- **Karla** (400/500/600) — cuerpo de texto, labels, captions.

| Estilo | Familia | Peso | Tamaño |
|---|---|---|---|
| Display | Quicksand | 700 | 20px |
| Heading | Quicksand | 700 | 17px |
| Body | Karla | 500 | 15px |
| Caption | Karla | 500 | 13px |
| Label | Karla | 600 | 12px |

Las fuentes van empaquetadas como assets locales (`app/assets/fonts/`, variable fonts, licencia OFL en `OFL.txt`). Se decidió **no** usar el paquete `google_fonts`, que las descarga en tiempo de ejecución: un gestor de contraseñas local-first no debe hacer una llamada de red a Google en el primer arranque.

## Espaciado

Escala en px: `4, 8, 12, 16, 20, 24, 32, 40` — `LockspireSpacing` (`xs, sm, smMd, md, mdLg, lg, xl, xxl`) en `app/lib/design/lockspire_spacing.dart`.

## Radios

- `sm` — 8px
- `md` — 16px (campos de texto, chips de icono)
- `lg` — 24px (tarjetas)
- `pill` — 999px / altura completa (botones)

En código: `LockspireRadius` (mismo archivo que el espaciado).

## Componentes definidos

- Botón: primario, primario presionado, primario deshabilitado, secundario (outline).
- Campo de texto: default, focused (borde + halo de acento), error (borde rojo + helper text).
- Tarjeta (icono + título + subtítulo).
- Fila de lista — pensada para la futura pantalla de entradas de la bóveda (icono/inicial + título + subtítulo + chevron).
- Barra superior (título + acción a la derecha).

El patrón de tarjeta de autenticación (chip de icono + título + subtítulo + contenido) está extraído como widget compartido: `AuthCard` (`app/lib/features/vault/presentation/widgets/auth_card.dart`).

## Pantallas

Maquetadas en el canvas **e implementadas** con la composición completa:

- "Desbloquear bóveda" — móvil y escritorio (`unlock_vault_screen.dart`, con `AuthCard`).
- "Crear bóveda" — móvil y escritorio (`create_vault_screen.dart`, con `AuthCard`).

Implementadas usando los tokens y componentes del sistema, **sin mockup propio** en el canvas:

- Lista de entradas (`vault_unlocked_screen.dart`) — usa la fila de lista definida arriba.
- Crear/editar entrada (`entry_form_screen.dart`) — usa `AuthCard`; incluye el panel del generador y la barra de fortaleza (niveles con `danger` / `accentDefault` / `accentSecondary`).
- Restaurar bóveda desde la nube (`restore_vault_screen.dart`) — usa `AuthCard`.

Con estilo básico (heredan el tema, sin composición a medida): `sync_settings_screen.dart`, `import_screen.dart`, `security_screen.dart`, y la pantalla de selección de credencial del autofill de Android (`autofill_screen.dart`).

## Navegación (Material 3, 2026-09-25)

Tras desbloquear, la app usa la **navegación adaptable de M3** con cuatro secciones: **Bóveda**, **Sincronización**, **Seguridad** y **Ajustes**. Ajustes agrupa Apariencia, Importar desde SafeInCloud y, en escritorio, Navegador.

- En ventanas compactas (< 600 px, la clase de ventana "compacta" de M3), una `NavigationBar` inferior.
- En las demás, un `NavigationRail` lateral con **Bloquear** al pie.
- La barra de la Bóveda solo conserva Bloquear, y **solo con barra inferior**: con el riel, Bloquear ya está al pie y no se repite. Antes tenía 7 iconos.
- Cada sección conserva su estado al cambiar de pestaña.

## Pendiente

- Maquetar y aplicar el sistema a las pantallas con estilo básico de la lista anterior (no bloqueante).
- Pantallas futuras: configuración general y la UI de la extensión de navegador.
- ~~Modo oscuro~~: hecho, ver "Temas".
- Maquetar en el canvas vivo los temas nuevos (hoy solo existen en código).

## Ícono y marca

**"Candado aguja"** (2026-09-27, elegido por el usuario entre tres conceptos): un candado cuyo arco termina en punta, como una aguja gótica. Es el nombre dibujado: lock + spire. Candado `#F6FAFA` sobre el teal de LineageOS `#167C80`, con la cerradura en `#324B4C`.

- **SVG maestro:** `docs/design/brand/lockspire-icon.svg`.
- **PNG para marketing:** `lockspire-icon-1024.png` (redondeado) y `lockspire-icon-square-1024.png` (a sangre).
- **Generador:** `python tools/generate_icons.py` produce todos los tamaños con la misma geometría:
  - Android: el ícono clásico y el adaptativo (primer plano, fondo y monocromo para los íconos temáticos).
  - Windows (`.ico` de la app y de la bandeja), web (incluido maskable), iOS, macOS y la extensión.
- Si se retoca el diseño, cambiar el SVG y el script juntos y volver a generar.
