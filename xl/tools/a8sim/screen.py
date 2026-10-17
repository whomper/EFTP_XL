# AERA-Atari xl/tools/a8sim - the screen
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""The GRAPHICS 0 screen, read from SAVMSC: as text, or as a picture in the
program's own font (CHBAS) and colours, in the palette every README
picture uses; and atari800's screen dump to a picture in the same palette."""
import colorsys

SAVMSC, CHBAS = 0x58, 0x2F4
COLOR1, COLOR2, COLOR4 = 0x2C5, 0x2C6, 0x2C8


def screen_text(m, glyphs=None):
    """24 lines of 40; glyphs {ATASCII code: char} names the program's
    own characters (box lines, icons); any other is '?'"""
    glyphs = glyphs or {}
    base = m.word(SAVMSC)
    rows = []
    for r in range(24):
        row = ''
        for c in range(40):
            ch = m.mem[base + r * 40 + c] & 0x7F
            a = ch + 0x20 if ch < 0x40 else ch - 0x40 if ch < 0x60 else ch
            row += chr(a) if 0x20 <= a < 0x7B else glyphs.get(a, '?')
        rows.append(row.rstrip())
    return '\n'.join(rows)


def atari_rgb(colour):
    """an NTSC palette entry, approximately (EDOS's tools/screenshot.py)"""
    hue, lum = colour >> 4, (colour & 0x0F) / 15
    if hue == 0:
        v = int(lum * 255)
        return (v, v, v)
    angle = (45 - (hue - 1) * 24) % 360
    r, g, b = colorsys.hls_to_rgb(angle / 360, 0.10 + lum * 0.75, 0.70)
    return (int(r * 255), int(g * 255), int(b * 255))


def screen_png(m, path, scale=3):
    """the screen as the Atari shows it, with a border (needs Pillow)"""
    from PIL import Image
    font_at = m.mem[CHBAS] << 8
    font = bytes(m.mem[font_at:font_at + 1024])
    bg_c = m.mem[COLOR2]
    bg = atari_rgb(bg_c)
    fg = atari_rgb((bg_c & 0xF0) | (m.mem[COLOR1] & 0x0F))
    border = atari_rgb(m.mem[COLOR4])
    bx, by = 16, 12
    w, h = 40 * 8 + 2 * bx, 24 * 8 + 2 * by
    img = Image.new('RGB', (w, h), border)
    px = img.load()
    base = m.word(SAVMSC)
    for r in range(24):
        for c in range(40):
            ch = m.mem[base + r * 40 + c]
            for y in range(8):
                bits = font[(ch & 0x7F) * 8 + y]
                for x in range(8):
                    on = bool(bits & (0x80 >> x)) ^ bool(ch & 0x80)
                    px[bx + c * 8 + x, by + r * 8 + y] = fg if on else bg
    img.resize((w * scale, h * scale), Image.NEAREST).save(path)


def raw2png(dump, path, box=(24, 16, 360, 224), scale=2):
    """atari800's 384x240 screen (a8run's dump: one colour byte a pixel),
    cropped to the picture and scaled, in atari_rgb's palette"""
    from PIL import Image
    data = open(dump, 'rb').read() if isinstance(dump, str) else dump
    img = Image.new('RGB', (384, 240))
    img.putdata([atari_rgb(c) for c in data[:384 * 240]])
    img = img.crop(box)
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)
