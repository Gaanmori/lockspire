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

**Pendiente de traducir a Flutter:** `main.dart` sigue usando `ColorScheme.fromSeed(seedColor: Colors.deepPurple)` del scaffold original — no refleja esta paleta. Hay que definir un `ColorScheme` explícito (no generado por seed) con estos tokens antes de aplicar el sistema a las pantallas reales.

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

## Espaciado

Escala en px: `4, 8, 12, 16, 20, 24, 32, 40`.

## Radios

- `sm` — 8px
- `md` — 16px (campos de texto, chips de icono)
- `lg` — 24px (tarjetas)
- `pill` — 999px / altura completa (botones)

## Componentes definidos

- Botón: primario, primario presionado, primario deshabilitado, secundario (outline).
- Campo de texto: default, focused (borde + halo de acento), error (borde rojo + helper text).
- Tarjeta (icono + título + subtítulo).
- Fila de lista — pensada para la futura pantalla de entradas de la bóveda (icono/inicial + título + subtítulo + chevron).
- Barra superior (título + acción a la derecha).

## Pantallas ya maquetadas con este sistema

- "Desbloquear bóveda" — móvil y escritorio.
- "Crear bóveda" — móvil y escritorio.

## Implementado en Flutter (no solo mockup)

- "Desbloquear bóveda" y "Crear bóveda" comparten el componente `AuthCard`
  (`lib/features/vault/presentation/widgets/auth_card.dart`): chip de icono,
  título, subtítulo y contenido, sobre tarjeta elevada — la misma
  composición del mockup, no solo los tokens de color/espaciado sueltos.

## Pendiente

- "Bóveda desbloqueada" queda con el tratamiento ligero (colores/espaciado
  heredados del tema, sin maquetar a medida) — es un placeholder a
  propósito hasta que exista la feature real de gestión de entradas; no
  tiene sentido diseñarla a medida antes de eso.
- Extender el sistema a las futuras pantallas: lista de entradas,
  agregar/editar entrada, configuración, setup de sync.
