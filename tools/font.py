#!/usr/bin/env python3
# AERA-Atari xl/tools - AERA.FNT, the family's character set
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""AERA.FNT (the 8-bit guidelines, 5.3) is Erez's EREZ.FNT (xl/font/),
moved one pixel right where its glyph leaves column 7 empty, so inverse
characters show as solid blocks as the ROM font's do (EDOS's font), with
the family's four icons in the places kept for them (5.3; a program may
put its own there):

    ATASCII $00 (heart, screen code $40)  a folder
    ATASCII $10 (club, $50)               a file
    ATASCII $06 (/, $46)                  "..." for names that are cut off
    ATASCII $7B (spade, $7B)              the empty part of a progress bar

The built font is kept as xl/font/AERA.FNT, so a program carries it on its
disk and in its release without building it; `check` says it is up to date.

  font.py fnt OUT.FNT    the font
  font.py check          xl/font/AERA.FNT is the font built from EREZ.FNT
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EREZ = os.path.join(HERE, '..', 'font', 'EREZ.FNT')
AERA = os.path.join(HERE, '..', 'font', 'AERA.FNT')
ICONS = (0x40, 0x46, 0x50, 0x7B)        # screen codes kept for icons

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
    with open(EREZ, 'rb') as f:
        font = shifted(f.read())
    for a, rows in GLYPHS.items():
        i = internal(a) * 8
        font[i:i + 8] = bytes(int(r.replace('.', '0').replace('#', '1'), 2) for r in rows)
    return bytes(font)


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == 'fnt':
        with open(a[1], 'wb') as f:
            f.write(aera_font())
    elif a == ['check']:
        with open(AERA, 'rb') as f:
            if f.read() != aera_font():
                print(f'{AERA}: out of date; font.py fnt {AERA}')
                return 1
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
