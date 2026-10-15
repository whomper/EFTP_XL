#!/usr/bin/env python3
# EFTP_XL - the Mac/65 sources on Atari disks
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Put ASM/*.ASM on DOS 2 disks (single density ATRs, which DOS 2.5
and SpartaDOS read) the way Mac/65 ENTERs them: ATASCII, numbered
lines (10, 20, ...), the spaces that only line things up taken out
(Mac/65 lays a line out itself). Whole files fill the first disk, then
the next: EFTPXL1.ATR, EFTPXL2.ATR, ...

    tools/atari_src.py OUT.ATR FILE.ASM...    (OUT1.ATR, OUT2.ATR, ...)
    tools/atari_src.py --check OUT1.ATR ...   the files on the disks

--check reads the disks back and writes their files (in ASCII, as
ATasm takes them) to the folder given with --to.
"""
import argparse
import os
import sys

SECTOR = 128
SECTORS = 720
DATA = 125                       # bytes a DOS 2 sector holds
VTOC, DIR = 360, 361
FREE = [s for s in range(4, SECTORS) if not 360 <= s <= 368]   # 707
EOL = 0x9B


def squeeze(line):
    """A source line as Mac/65 lists it: label, then the rest with one
    space between its fields (none taken out of strings or comments)."""
    line = line.rstrip()
    if not line.strip():
        return ';'
    if line.lstrip().startswith(';'):
        return line.strip()
    label = '' if line[0].isspace() else None
    fields, cur, i, comment = [], '', 0, ''
    quote = False
    while i < len(line):
        c = line[i]
        if c == '"':
            quote = not quote
        if c == ';' and not quote:
            comment = line[i:].rstrip()
            break
        if c == "'" and not quote and i + 1 < len(line):
            cur += line[i:i + 2]          # a character, even a space
            i += 2
            continue
        if c == ' ' and not quote:
            if cur:
                fields.append(cur)
                cur = ''
        else:
            cur += c
        i += 1
    if cur:
        fields.append(cur)
    if label is None:
        label = fields.pop(0)
    rest = ' '.join(fields + ([comment] if comment else []))
    return f'{label} {rest}'.rstrip() if label else ' ' + rest


def mac65(text):
    """the file as Mac/65 ENTERs it: numbered ATASCII lines"""
    out = bytearray()
    for n, line in enumerate(text.split('\n')[:-1] if text.endswith('\n')
                             else text.split('\n')):
        out += f'{(n + 1) * 10} {squeeze(line)}'.encode('ascii') + bytes([EOL])
    return bytes(out)


def dos_name(path):
    base, _, ext = os.path.basename(path).upper().partition('.')
    assert 1 <= len(base) <= 8 and len(ext) <= 3, path
    return base.ljust(8).encode() + ext.ljust(3).encode()


class Disk:
    def __init__(self):
        self.img = bytearray(SECTORS * SECTOR)
        self.free = list(FREE)
        self.files = 0

    def sector(self, n):
        return (n - 1) * SECTOR

    def room(self, size):
        return self.files < 64 and len(self.free) * DATA >= max(size, 1)

    def add(self, name, data):
        n = self.files
        self.files += 1
        chunks = [data[i:i + DATA] for i in range(0, len(data), DATA)] or [b'']
        secs = [self.free.pop(0) for _ in chunks]
        for i, (s, chunk) in enumerate(zip(secs, chunks)):
            nxt = secs[i + 1] if i + 1 < len(secs) else 0
            o = self.sector(s)
            self.img[o:o + len(chunk)] = chunk
            self.img[o + 125] = (n << 2) | (nxt >> 8)
            self.img[o + 126] = nxt & 255
            self.img[o + 127] = len(chunk)
        o = self.sector(DIR + n // 8) + (n % 8) * 16
        self.img[o] = 0x42
        self.img[o + 1:o + 3] = len(secs).to_bytes(2, 'little')
        self.img[o + 3:o + 5] = secs[0].to_bytes(2, 'little')
        self.img[o + 5:o + 16] = name

    def atr(self):
        o = self.sector(VTOC)
        self.img[o] = 2
        self.img[o + 1:o + 3] = len(FREE).to_bytes(2, 'little')
        self.img[o + 3:o + 5] = len(self.free).to_bytes(2, 'little')
        for s in self.free:
            self.img[o + 10 + s // 8] |= 0x80 >> (s % 8)
        size = len(self.img) // 16
        head = bytes([0x96, 0x02, size & 255, (size >> 8) & 255, SECTOR & 255,
                      SECTOR >> 8, size >> 16]) + bytes(9)
        return head + bytes(self.img)


def read_atr(path):
    """{name: data} of a DOS 2 single density ATR"""
    img = open(path, 'rb').read()[16:]
    files = {}
    for n in range(64):
        o = (DIR + n // 8 - 1) * SECTOR + (n % 8) * 16
        if not img[o] & 0x40 or img[o] & 0x80:
            continue
        name = img[o + 5:o + 13].decode().strip()
        ext = img[o + 13:o + 16].decode().strip()
        s, data = int.from_bytes(img[o + 3:o + 5], 'little'), bytearray()
        while s:
            so = (s - 1) * SECTOR
            assert img[so + 125] >> 2 == n, f'{name}: sector {s} is not its'
            data += img[so:so + img[so + 127]]
            s = (img[so + 125] & 3) << 8 | img[so + 126]
        files[name + ('.' + ext if ext else '')] = bytes(data)
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--to')
    ap.add_argument('out')
    ap.add_argument('files', nargs='*')
    a = ap.parse_args()

    if a.check:
        for atr in [a.out] + a.files:
            for name, data in read_atr(atr).items():
                text = data.replace(bytes([EOL]), b'\n').decode('ascii')
                if a.to:
                    open(os.path.join(a.to, name), 'w').write(text)
                print(f'{atr}: {name} {len(data)} bytes')
        return 0

    base, ext = os.path.splitext(a.out)
    disks = [Disk()]
    for path in sorted(a.files, key=lambda p: (not p.endswith('EFTPXL.ASM'), p)):
        data = mac65(open(path).read())
        if not disks[-1].room(len(data)):
            disks.append(Disk())
        assert disks[-1].room(len(data)), f'{path} does not fit on a disk'
        disks[-1].add(dos_name(path), data)
    for i, d in enumerate(disks):
        name = f'{base}{i + 1}{ext}'
        open(name, 'wb').write(d.atr())
        print(f'{name}: {d.files} files, {len(d.free) * DATA} bytes free')
    return 0


if __name__ == '__main__':
    sys.exit(main())
