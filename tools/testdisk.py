#!/usr/bin/env python3
# EFTP_XL - the files of the test disk for real hardware (EFTPTEST.ATR)
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Make the folder that becomes EFTPTEST.ATR's files (the 8-bit guidelines,
8, level 3): the test plan, a sample site and the files the plan sends.
The Makefile puts it on a disk with xl/tools/atari_src.py disk --tree,
with the program and AERA.FNT.

    tools/testdisk.py OUTDIR VERSION
"""
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EOL = b'\x9b'
WIDTH = 38


def atari_text(lines):
    """lines as ATASCII text, an EOL after each, as TYPE shows it"""
    return b''.join(line.encode('ascii') + EOL for line in lines)


def main():
    out, version = sys.argv[1], sys.argv[2]
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(os.path.join(out, 'TREE', 'SUB'))

    plan = open(os.path.join(ROOT, 'docs', 'TESTPLAN.TXT')).read()
    lines = plan.replace('@VERSION@', version).rstrip('\n').split('\n')
    wide = [n + 1 for n, line in enumerate(lines) if len(line) > WIDTH]
    if wide:
        raise SystemExit(f'TESTPLAN.TXT: lines over {WIDTH} columns: {wide}')
    files = {
        'TESTPLAN.TXT': atari_text(lines),
        # one site, By type; the server's address is for Erez to fill in,
        # and the password is left empty, so it is asked for
        'EFTPXL.CFG': atari_text([
            "; EFTPXL.CFG - EFTP_XL's sites",
            '; name|server|port|user|password|',
            '; folder|Atari folder|mode',
            '; a password here is plain text',
            'Test|PI_IP|21|ATARI||/|D1:|2']),
        'TEXT.TXT': atari_text([
            'EFTP_XL test file, text.',
            'Line two.',
            '',
            'Line four, after an empty one.']),
        'BIN.DAT': bytes((i * 7 + i // 256) & 255 for i in range(8192)),
        'EMPTY.DAT': b'',
        'BIG.DAT': bytes((i * 13 + i // 97) & 255 for i in range(65536)),
        os.path.join('TREE', 'A.TXT'): atari_text(['In the folder TREE.']),
        os.path.join('TREE', 'SUB', 'B.DAT'): bytes(range(256)) * 12,
    }
    for name, data in files.items():
        with open(os.path.join(out, name), 'wb') as f:
            f.write(data)
    print(out)


if __name__ == '__main__':
    main()
