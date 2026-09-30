# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Gabriel Ángel Montoya Rico
"""Genera todos los íconos de Lockspire a partir de una sola geometría.

Ícono "Candado aguja" (concepto A, 2026-09-27): un candado cuyo arco
termina en punta, como una aguja gótica (lock + spire). Colores del tema
Lineage. La misma geometría está en docs/design/brand/lockspire-icon.svg:
si se cambia una, cambiar la otra.

Uso (desde la raíz del repo, requiere Pillow):

    python tools/generate_icons.py

Dibuja a 4x y reduce con Lanczos para bordes suaves.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'app'

BRAND = (0x16, 0x7C, 0x80, 255)  # fondo: #167C80, teal de LineageOS
KEYHOLE = (0x32, 0x4B, 0x4C, 255)  # cerradura: #324B4C (accentHover)
GLYPH = (0xF6, 0xFA, 0xFA, 255)  # candado: #F6FAFA (bgPage de Lineage)
CLEAR = (0, 0, 0, 0)


def _hex(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


# Ícono por tema (ADR 0029/0031): fondo = acento, candado = fondo de página
# y cerradura = acento oscuro de la versión clara de cada tema. Mantener en
# sincronía con LockspireIconColors (app/lib/design/lockspire_icon.dart) y
# ICON_COLORS (extension/src/icon.ts).
THEMES = {
    'lineage': (BRAND, GLYPH, KEYHOLE),
    'pixel': (_hex('#445E91'), _hex('#F9F9FF'), _hex('#3E5480')),
    'ubuntu': (_hex('#E95420'), _hex('#FAFAFA'), _hex('#C7461A')),
    'mint': (_hex('#35A854'), _hex('#F8F8F9'), _hex('#2C8C46')),
    'windows': (_hex('#005FB8'), _hex('#F3F3F3'), _hex('#1A6FC0')),
    # Ícono principal de Android (android:icon de la app): lo usan el diálogo
    # de la huella e "Información de la aplicación", que no siguen al tema
    # elegido (solo el lanzador lo hace, con los alias de ADR 0031). Grafito
    # sobrio para que combine con cualquier tema (pedido del usuario,
    # 2026-09-30).
    # Es también el ícono del tema Grafito (ADR 0036): mismos colores que
    # LockspireIconColors.fromPalette(LockspirePalettes.grafito).
    'neutral': (_hex('#2B2E32'), _hex('#F7F7F8'), _hex('#1A1C1F')),
}
SUPERSAMPLE = 4

# Geometría en un lienzo de 180x180 (igual que el SVG maestro).
CANVAS = 180
CORNER = 40
SHACKLE_WIDTH = 15
BODY = (40, 90, 140, 158)
BODY_RADIUS = 16
KEYHOLE_CIRCLE = (90, 116, 10)
KEYHOLE_STEM = [(84, 120), (96, 120), (99, 140), (81, 140)]
# Alto y centro del candado (arco + cuerpo), para escalarlo solo.
GLYPH_TOP = 30 - SHACKLE_WIDTH / 2
GLYPH_BOTTOM = BODY[3]
GLYPH_CENTER = (90, (GLYPH_TOP + GLYPH_BOTTOM) / 2)


def _shackle_points(steps=400):
    """Arco en punta: dos rectas y dos curvas cuadráticas que se unen arriba."""

    def line(a, b):
        return [(a[0] + (b[0] - a[0]) * t / steps, a[1] + (b[1] - a[1]) * t / steps)
                for t in range(steps + 1)]

    def quad(a, c, b):
        pts = []
        for i in range(steps + 1):
            t = i / steps
            x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t ** 2 * b[0]
            y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t ** 2 * b[1]
            pts.append((x, y))
        return pts

    return (line((58, 100), (58, 76)) + quad((58, 76), (58, 52), (90, 30))
            + quad((90, 30), (122, 52), (122, 76)) + line((122, 76), (122, 100)))


def render(size, *, background='rounded', glyph_height=None, monochrome=False,
           colors=None):
    """Un PNG RGBA de size x size.

    background: 'rounded' (cuadrado redondeado), 'square' (a sangre, para
    iOS y máscaras) o None (transparente, primer plano adaptativo).
    glyph_height: fracción del lienzo que ocupa el candado; None usa la
    proporción del ícono maestro.
    monochrome: candado blanco con la cerradura calada (ícono temático de
    Android 13+).
    """
    brand, glyph_color, keyhole = colors or THEMES['lineage']
    n = size * SUPERSAMPLE
    img = Image.new('RGBA', (n, n), CLEAR)
    draw = ImageDraw.Draw(img)

    if background == 'rounded':
        draw.rounded_rectangle([0, 0, n - 1, n - 1], radius=CORNER * n / CANVAS, fill=brand)
    elif background == 'square':
        draw.rectangle([0, 0, n - 1, n - 1], fill=brand)

    if glyph_height is None:
        k = n / CANVAS
        ox, oy = 0.0, 0.0
    else:
        k = glyph_height * n / (GLYPH_BOTTOM - GLYPH_TOP)
        ox = n / 2 - GLYPH_CENTER[0] * k
        oy = n / 2 - GLYPH_CENTER[1] * k

    def pt(x, y):
        return (ox + x * k, oy + y * k)

    glyph = (255, 255, 255, 255) if monochrome else glyph_color
    radius = SHACKLE_WIDTH / 2 * k
    for x, y in _shackle_points():
        cx, cy = pt(x, y)
        draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=glyph)

    x0, y0 = pt(BODY[0], BODY[1])
    x1, y1 = pt(BODY[2], BODY[3])
    draw.rounded_rectangle([x0, y0, x1, y1], radius=BODY_RADIUS * k, fill=glyph)

    hole = CLEAR if monochrome else keyhole
    cx, cy = pt(KEYHOLE_CIRCLE[0], KEYHOLE_CIRCLE[1])
    r = KEYHOLE_CIRCLE[2] * k
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hole)
    draw.polygon([pt(x, y) for x, y in KEYHOLE_STEM], fill=hole)

    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f'  {path.relative_to(ROOT)}')


def save_ico(path, sizes, colors=None):
    images = [render(s, colors=colors) for s in sizes]
    path.parent.mkdir(parents=True, exist_ok=True)
    images[-1].save(path, format='ICO', sizes=[(s, s) for s in sizes],
                    append_images=images[:-1])
    print(f'  {path.relative_to(ROOT)}')


def main():
    print('Marca')
    brand = ROOT / 'docs/design/brand'
    save(render(1024), brand / 'lockspire-icon-1024.png')
    save(render(1024, background='square'), brand / 'lockspire-icon-square-1024.png')

    print('Android')
    res = APP / 'android/app/src/main/res'
    for density, legacy, adaptive in [('mdpi', 48, 108), ('hdpi', 72, 162),
                                      ('xhdpi', 96, 216), ('xxhdpi', 144, 324),
                                      ('xxxhdpi', 192, 432)]:
        folder = res / f'mipmap-{density}'
        save(render(legacy), folder / 'ic_launcher.png')
        # Adaptativo: lienzo de 108 dp con zona segura de 66 dp; el candado
        # ocupa ~56 % del alto para quedar dentro con cualquier máscara.
        save(render(adaptive, background=None, glyph_height=0.56),
             folder / 'ic_launcher_foreground.png')
        save(render(adaptive, background=None, glyph_height=0.56, monochrome=True),
             folder / 'ic_launcher_monochrome.png')
        # Un ícono por tema para el lanzador (ADR 0031): los activa la app
        # con un activity-alias por tema. Lineage es el ic_launcher de base.
        for name, colors in THEMES.items():
            if name == 'lineage':
                continue
            save(render(legacy, colors=colors), folder / f'ic_launcher_{name}.png')
            save(render(adaptive, background=None, glyph_height=0.56, colors=colors),
                 folder / f'ic_launcher_foreground_{name}.png')

    anydpi = res / 'mipmap-anydpi-v26'
    colors_xml = ['<?xml version="1.0" encoding="utf-8"?>',
                  '<!-- Generado por tools/generate_icons.py. -->',
                  '<resources>',
                  '    <color name="ic_launcher_background">#167C80</color>']
    for name, (bg, _, _) in THEMES.items():
        if name == 'lineage':
            continue
        colors_xml.append(
            f'    <color name="ic_launcher_background_{name}">'
            f'#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}</color>')
        xml = '\n'.join([
            '<?xml version="1.0" encoding="utf-8"?>',
            f'<!-- Ícono del tema {name} (ADR 0031). Generado por tools/generate_icons.py. -->',
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">',
            f'    <background android:drawable="@color/ic_launcher_background_{name}" />',
            f'    <foreground android:drawable="@mipmap/ic_launcher_foreground_{name}" />',
            '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />',
            '</adaptive-icon>',
        ]) + '\n'
        (anydpi / f'ic_launcher_{name}.xml').write_text(xml, encoding='utf-8')
        print(f'  {(anydpi / f"ic_launcher_{name}.xml").relative_to(ROOT)}')
    colors_xml.append('</resources>')
    (res / 'values/ic_launcher_background.xml').write_text(
        '\n'.join(colors_xml) + '\n', encoding='utf-8')

    # El ícono "del sistema" en escritorio (el .exe, la bandeja antes de
    # cargar el tema, el paquete MSIX) es el de Grafito, el tema por defecto
    # (ADR 0036). La ventana y la bandeja cambian después al tema elegido.
    grafito = THEMES['neutral']
    print('Windows')
    save_ico(APP / 'windows/runner/resources/app_icon.ico',
             [16, 24, 32, 48, 64, 128, 256], colors=grafito)
    save_ico(APP / 'assets/tray/tray_icon.ico', [16, 24, 32, 48, 64, 256],
             colors=grafito)
    save(render(144, colors=grafito), APP / 'assets/tray/tray_icon.png')

    print('MSIX (Microsoft Store)')
    msix = APP / 'windows/packaging/Assets'
    for name, px in [('StoreLogo', 50), ('Square44x44Logo', 44),
                     ('Square150x150Logo', 150)]:
        save(render(px, colors=grafito), msix / f'{name}.png')

    print('Web')
    web = APP / 'web'
    save(render(32), web / 'favicon.png')
    save(render(192), web / 'icons/Icon-192.png')
    save(render(512), web / 'icons/Icon-512.png')
    # Maskable: a sangre, con el candado dentro del círculo seguro (80 %).
    save(render(192, background='square', glyph_height=0.5), web / 'icons/Icon-maskable-192.png')
    save(render(512, background='square', glyph_height=0.5), web / 'icons/Icon-maskable-512.png')

    print('iOS')
    ios = APP / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for name, px in [('20x20@1x', 20), ('20x20@2x', 40), ('20x20@3x', 60),
                     ('29x29@1x', 29), ('29x29@2x', 58), ('29x29@3x', 87),
                     ('40x40@1x', 40), ('40x40@2x', 80), ('40x40@3x', 120),
                     ('60x60@2x', 120), ('60x60@3x', 180), ('76x76@1x', 76),
                     ('76x76@2x', 152), ('83.5x83.5@2x', 167), ('1024x1024@1x', 1024)]:
        # iOS aplica su propia máscara y no admite transparencia.
        save(render(px, background='square', glyph_height=0.62).convert('RGB'),
             ios / f'Icon-App-{name}.png')

    print('macOS')
    mac = APP / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for px in [16, 32, 64, 128, 256, 512, 1024]:
        save(render(px), mac / f'app_icon_{px}.png')

    print('Extensión')
    save(render(48, colors=grafito), ROOT / 'extension/public/icons/icon-48.png')
    save(render(128, colors=grafito), ROOT / 'extension/public/icons/icon-128.png')


if __name__ == '__main__':
    main()
