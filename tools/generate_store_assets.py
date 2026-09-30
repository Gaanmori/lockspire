# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Gabriel Ángel Montoya Rico
"""Genera las imágenes de las fichas de las tiendas, en grafito (ADR 0036).

- Google Play: ícono de 512 x 512 a sangre (Play le pone las esquinas) e
  imagen destacada de 1024 x 500.
- Microsoft Store: la misma imagen destacada sirve de base; los logos del
  paquete los genera generate_icons.py.

Uso (desde la raíz del repo, requiere Pillow):

    python tools/generate_store_assets.py
"""

from PIL import Image, ImageDraw, ImageFont

from generate_icons import ROOT, THEMES, render, save

OUT = ROOT / 'docs/store/assets'
FONTS = ROOT / 'app/assets/fonts'
BRAND, GLYPH, _ = THEMES['neutral']
MUTED = (0xB8, 0xBC, 0xC2, 255)

TAGLINE = {
    'es': 'Sus contraseñas, cifradas y solo suyas',
    'en': 'Your passwords, encrypted and only yours',
}


def _font(name, size, weight):
    font = ImageFont.truetype(str(FONTS / name), size)
    font.set_variation_by_axes([weight])
    return font


def feature_graphic(lang):
    width, height = 1024, 500
    img = Image.new('RGBA', (width, height), BRAND)
    icon = render(260, background=None, glyph_height=0.9, colors=THEMES['neutral'])
    img.alpha_composite(icon, (90, (height - 260) // 2))

    draw = ImageDraw.Draw(img)
    title = _font('Quicksand[wght].ttf', 104, 700)
    tagline = _font('Karla[wght].ttf', 28, 500)
    x = 390
    draw.text((x, 170), 'Lockspire', font=title, fill=GLYPH)
    draw.text((x + 4, 300), TAGLINE[lang], font=tagline, fill=MUTED)
    return img.convert('RGB')


def main():
    print('Google Play')
    save(render(512, background='square', glyph_height=0.62,
                colors=THEMES['neutral']).convert('RGB'),
         OUT / 'play-icon-512.png')
    for lang in TAGLINE:
        save(feature_graphic(lang), OUT / f'feature-graphic-1024x500-{lang}.png')


if __name__ == '__main__':
    main()
