// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/**
 * Colores del ícono "Candado aguja" por familia de tema: fondo = acento,
 * candado = fondo de página y cerradura = acento oscuro de la versión
 * clara (igual que `LockspireIconColors.fromPalette` en la app; mantener
 * en sincronía con `app/lib/design/lockspire_colors.dart`).
 */
export const ICON_COLORS: Record<string, readonly [string, string, string]> = {
  grafito: ['#2b2e32', '#f7f7f8', '#1a1c1f'],
  lineage: ['#167c80', '#f6fafa', '#324b4c'],
  pixel: ['#445e91', '#f9f9ff', '#3e5480'],
  ubuntu: ['#e95420', '#fafafa', '#c7461a'],
  mint: ['#35a854', '#f8f8f9', '#2c8c46'],
  windows: ['#005fb8', '#f3f3f3', '#1a6fc0'],
};

/**
 * Los del tema, o los de Grafito (el tema por defecto) para "Colores del
 * sistema", "Personalizado" o uno desconocido.
 */
export function iconColorsFor(family: string): readonly [string, string, string] {
  return ICON_COLORS[family] ?? ICON_COLORS['grafito']!;
}

/**
 * Dibuja el ícono en un lienzo de [size]. Misma geometría que
 * `docs/design/brand/lockspire-icon.svg` (lienzo base de 180×180).
 */
export function drawIcon(
  ctx: OffscreenCanvasRenderingContext2D,
  size: number,
  [background, glyph, keyhole]: readonly [string, string, string],
): void {
  ctx.save();
  ctx.scale(size / 180, size / 180);
  ctx.fillStyle = background;
  ctx.beginPath();
  ctx.roundRect(0, 0, 180, 180, 40);
  ctx.fill();

  ctx.strokeStyle = glyph;
  ctx.lineWidth = 15;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(58, 100);
  ctx.lineTo(58, 76);
  ctx.quadraticCurveTo(58, 52, 90, 30);
  ctx.quadraticCurveTo(122, 52, 122, 76);
  ctx.lineTo(122, 100);
  ctx.stroke();

  ctx.fillStyle = glyph;
  ctx.beginPath();
  ctx.roundRect(40, 90, 100, 68, 16);
  ctx.fill();

  ctx.fillStyle = keyhole;
  ctx.beginPath();
  ctx.arc(90, 116, 10, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(84, 120);
  ctx.lineTo(96, 120);
  ctx.lineTo(99, 140);
  ctx.lineTo(81, 140);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/**
 * Pone en la barra del navegador el ícono con los colores del tema de la
 * app. Queda hasta que se reinicie el navegador; al abrir el popup se
 * vuelve a aplicar.
 */
export async function setToolbarIcon(family: string): Promise<void> {
  if (typeof OffscreenCanvas === 'undefined' || !globalThis.chrome?.action?.setIcon) {
    return;
  }
  const colors = iconColorsFor(family);
  const imageData: Record<string, ImageData> = {};
  for (const size of [16, 32, 48]) {
    const ctx = new OffscreenCanvas(size, size).getContext('2d');
    if (!ctx) return;
    drawIcon(ctx, size, colors);
    imageData[String(size)] = ctx.getImageData(0, 0, size, size);
  }
  await chrome.action.setIcon({ imageData });
}
