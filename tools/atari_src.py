#!/usr/bin/env python3
# EFTP_XL - the Mac/65 sources on Atari disks
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Put the sources (and the program) on one SpartaDOS double density
disk that boots SpartaDOS 3.2, ready for Mac/65: each NAME.ASM as NAME.M65, in the tokenized form
Mac/65's SAVE writes and LOAD and .INCLUDE read (tools/mac65tok.py).
The lines are numbered 10, 20, ..., and the spaces that only line
things up are left out (Mac/65 lays a line out itself). Other files
go as they are.

    tools/atari_src.py OUT.ATR FILE...
    tools/atari_src.py --check OUT.ATR [--to DIR]

--check checks the disk (fsck) and lists it; with --to it writes each
.M65 back as NAME.ASM text, as ATasm takes it.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sparta  # noqa: E402
import mac65tok  # noqa: E402

BOOT = os.path.join(HERE, 'disk', 'SPARTA.BOOT')   # SpartaDOS 3's boot sectors
DOS = os.path.join(HERE, 'disk', 'X32G.DOS')       # and SpartaDOS 3.2, which they boot
DD_SECTORS = 720
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


def new_disk(path, volume):
    """an empty SpartaDOS double density disk (720 sectors of 256 bytes)"""
    size = 3 * 128 + (DD_SECTORS - 3) * 256
    paras = size // 16
    head = bytes([0x96, 0x02, paras & 255, (paras >> 8) & 255, 0, 1, paras >> 16]) + bytes(9)
    boot = bytearray(open(BOOT, 'rb').read())
    boot[0x0B], boot[0x0C] = DD_SECTORS & 255, DD_SECTORS >> 8
    template = path + '.tmp'
    open(template, 'wb').write(head + bytes(boot) + bytes(size - len(boot)))
    try:
        return sparta.new_disk(path, template, volume)
    finally:
        os.remove(template)


def files_of(path):
    """{name: data} of a SpartaDOS disk's root directory"""
    d = sparta.Disk(path)
    out = {}
    for _, e in d.entries():
        if d.live(e) and not e[0] & 0x20:
            out[d.name(e)] = d.read_file(d.w(e, 1), e[3] | e[4] << 8 | e[5] << 16)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--to')
    ap.add_argument('atr')
    ap.add_argument('files', nargs='*')
    a = ap.parse_args()

    if a.check:
        d = sparta.Disk(a.atr)
        problems, lost = d.fsck()
        if problems or lost:
            raise SystemExit(f'{a.atr}: {problems} {lost}')
        for name, data in files_of(a.atr).items():
            if a.to and name.endswith('.M65'):
                text = mac65tok.detokenize(data)
                open(os.path.join(a.to, name[:-4] + '.ASM'), 'w').write(text)
            print(f'{name} {len(data)} bytes')
        return 0

    files = []
    for path in a.files:
        name = os.path.basename(path).upper()
        data = open(path, 'rb').read()
        if name.endswith('.ASM'):
            text = mac65(data.decode('ascii')).replace(bytes([EOL]), b'\n')
            name, data = name[:-4] + '.M65', mac65tok.tokenize(text.decode('ascii'))
        files.append((name, data))
    files.insert(0, ('X32G.DOS', open(DOS, 'rb').read()))
    d = new_disk(a.atr, 'EFTPXL')
    for name, data in files:
        d.add(name, data)
    d.set_boot_file('X32G.DOS')
    d.save()
    got = files_of(a.atr)
    for name, data in files:
        assert got.get(name) == data, f'{name} reads back wrong'
    free = sparta.Disk(a.atr).w(sparta.Disk(a.atr).read(1), 0x0D)
    print(f'{a.atr}: {len(files)} files, {free} sectors free')
    return 0


if __name__ == '__main__':
    sys.exit(main())
