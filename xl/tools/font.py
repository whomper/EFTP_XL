#!/usr/bin/env python3
# AERA-Atari xl/tools - AERA.FNT, the family's character set
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""AERA.FNT (the 8-bit guidelines, 5.3) is Erez's EREZ.FNT (xl/font/),
moved one pixel right where its glyph leaves column 7 empty, so inverse
characters show as solid blocks as the ROM font's do (EDOS's font), with
four glyphs EFTP_XL draws:

    ATASCII $00 (heart)  a folder
    ATASCII $10 (club)   a file
    ATASCII $06 (/)      "..." for names that are cut off
    ATASCII $7B (spade)  the empty part of a progress bar

  font.py fnt OUT.FNT                         the font
  font.py m65 OUT.M65 PROGRAM VERSION [LABEL] the font as .BYTE lines, for a
                                              program that carries it (MAC/65
                                              has no .INCBIN); 1K aligned
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EREZ = os.path.join(HERE, '..', 'font', 'EREZ.FNT')

GLYPHS = {
    0x00: ['........',
           '.###....',
           '.######.',
           '.#....#.',
           '.#....#.',
           '.######.',
           '........',
           '........'],
    0x10: ['........',
           '.####...',
           '.#..##..',
           '.#...#..',
           '.#...#..',
           '.#####..',
           '........',
           '........'],
    0x06: ['........',
           '........',
           '........',
           '........',
           '........',
           '........',
           '.#.#.#..',
           '........'],
    0x7B: ['#.#.#.#.',
           '.#.#.#.#',
           '#.#.#.#.',
           '.#.#.#.#',
           '#.#.#.#.',
           '.#.#.#.#',
           '#.#.#.#.',
           '.#.#.#.#'],
}


def internal(a):
    """ATASCII code -> position in the character set"""
    return a + 0x40 if a < 0x20 else a - 0x20 if a < 0x60 else a


def shifted(font):
    """every glyph whose column 7 is empty, one pixel right"""
    font = bytearray(font)
    if len(font) != 1024:
        raise ValueError(f'a font is 1024 bytes, not {len(font)}')
    for g in range(128):
        rows = font[g * 8:g * 8 + 8]
        if not any(r & 1 for r in rows):
            font[g * 8:g * 8 + 8] = bytes(r >> 1 for r in rows)
    return font


def aera_font():
    font = shifted(open(EREZ, 'rb').read())
    for a, rows in GLYPHS.items():
        i = internal(a) * 8
        font[i:i + 8] = bytes(int(r.replace('.', '0').replace('#', '1'), 2) for r in rows)
    return bytes(font)


def as_m65(data, name, program, version, label='FONT'):
    out = [';',
           f'; {name} - {program} {version}',
           '; The font: AERA.FNT, built in',
           '; Copyright (C) 2026 AERA | Erez Yaary',
           ';',
           '; Made by xl/tools/font.py; it',
           '; must be 1K aligned',
           ';']
    for c in range(128):
        row = data[c * 8:c * 8 + 8]
        lab = label.ljust(9) if c == 0 else ' ' * 9
        out.append(lab + '.BYTE ' + ','.join(f'${b:02X}' for b in row))
    return '\n'.join(out) + '\n'


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == 'fnt':
        open(a[1], 'wb').write(aera_font())
    elif len(a) in (4, 5) and a[0] == 'm65':
        open(a[1], 'w').write(as_m65(aera_font(), os.path.basename(a[1]).upper(), *a[2:]))
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
