#!/usr/bin/env python3
# EFTP_XL - fonts/EFTPXL.FNT as Mac/65 source (ASM/FONT.ASM)
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Mac/65 has no .INCBIN, so the font goes into the program as .BYTE
lines: 8 bytes, one character, a line.

    tools/font2asm.py [fonts/EFTPXL.FNT] [ASM/FONT.ASM]
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'fonts', 'EFTPXL.FNT')
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'ASM', 'FONT.ASM')
    data = open(src, 'rb').read()
    assert len(data) == 1024, 'a font is 1024 bytes'
    out = [';',
           '; EFTP_XL - the font: EDOS\'s, with EFTP_XL\'s own characters',
           '; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.',
           ';',
           '; Made by tools/font2asm.py from fonts/EFTPXL.FNT; 1K-aligned.',
           ';']
    for c in range(128):
        row = data[c * 8:c * 8 + 8]
        label = 'FONT     ' if c == 0 else '         '
        out.append(label + '.BYTE ' + ','.join(f'${b:02X}' for b in row))
    open(dst, 'w').write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main()
