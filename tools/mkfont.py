#!/usr/bin/env python3
# EFTP_XL - make the program's character set
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Make fonts/EFTPXL.FNT from fonts/EDOS.FNT, EDOS's character set (made
by EDOS's tools/font.py from EREZ.FNT), with four characters EFTP_XL
draws differently:

    ATASCII $00 (heart)  a folder
    ATASCII $10 (club)   a file
    ATASCII $06 (/)      "..." for names that are cut off
    ATASCII $7B (spade)  the empty part of a progress bar

    mkfont.py            writes fonts/EFTPXL.FNT
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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


def main():
    font = bytearray(open(os.path.join(ROOT, 'fonts', 'EDOS.FNT'), 'rb').read())
    for a, rows in GLYPHS.items():
        i = internal(a) * 8
        font[i:i + 8] = bytes(int(r.replace('.', '0').replace('#', '1'), 2)
                              for r in rows)
    open(os.path.join(ROOT, 'fonts', 'EFTPXL.FNT'), 'wb').write(font)


if __name__ == '__main__':
    main()
