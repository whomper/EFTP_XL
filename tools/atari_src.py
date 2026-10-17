#!/usr/bin/env python3
# AERA-Atari xl/tools - the MAC/65 sources on an Atari disk, and back
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""The sources between git and the Atari (the 8-bit guidelines, 2.1).

In git a NAME.M65 is text without line numbers, laid out in columns.
On the disk it is numbered 10, 20, ... and tokenised as MAC/65 1.01's
SAVE writes it (mac65tok.py), so MAC/65 LOADs and assembles it on a
real Atari. Coming back, a file SAVEd (or LISTed) on the Atari loses
its numbers again and keeps the layout of every line that didn't change.

  atari_src.py disk OUT.ATR --program EFTP_XL --version 1.1 FILE...
        [--volume NAME] [--base BASE.ATR]
      A bootable SpartaDOS 3.2 double density disk with the files:
      each .M65 tokenised, anything else as it is. Each .M65 must start
      with "; NAME.M65 - PROGRAM x.y" (xl/src's AXNAME.M65: "; AXNAME.M65 -
      AERA XL shared code") in its first 4 lines and be at most MAXTOK
      bytes tokenised. --base starts from a copy of a
      SpartaDOS disk (its boot sectors, DOS and files) instead.
  atari_src.py check DISK.ATR [--to DIR]
      fsck and list the disk; with --to, each .M65 into DIR in git's
      form (as import does, against DIR's file when there is one).
  atari_src.py import ATARI.M65 GIT.M65
      the file from the Atari (tokenised, or LIST's numbered text) into
      GIT.M65: lines whose tokens are unchanged keep git's layout, new
      ones are laid out in the family's columns.
  atari_src.py layout FILE...
      each file in git's form, in place: line numbers gone, every line in
      the family's columns (for a program moving to these rules; the
      tokens, and so the program, stay the same).
"""
import argparse
import difflib
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sparta  # noqa: E402
import mac65tok  # noqa: E402

BOOT = os.path.join(HERE, 'disk', 'SPARTA.BOOT')   # SpartaDOS 3's boot sectors
DOS = os.path.join(HERE, 'disk', 'X32G.DOS')       # and SpartaDOS 3.2, which they boot
DD_SECTORS = 720
EOL = 0x9B
SHARED = 'AERA XL shared code'   # the header of xl/src's AX files
MAXTOK = 16384      # tokenised bytes a file, so MAC/65 LOADs and edits it on any DOS
OPCOL, COMCOL = 9, 28   # the family's columns: operation, end-of-line comment


class SrcError(Exception):
    pass


def split_line(line):
    """(label, statement, comment) of a source line, strings kept whole"""
    q, i, cut = False, 0, None
    while i < len(line):
        c = line[i]
        if c == '"':
            q = not q
        elif c == "'" and not q:
            i += 2
            continue
        elif c == ';' and not q:
            cut = i
            break
        i += 1
    code, comment = (line, '') if cut is None else (line[:cut], line[cut:].rstrip())
    code = code.rstrip()
    if code and not code[0].isspace():
        p = code.split(None, 1)
        return p[0], (p[1] if len(p) > 1 else ''), comment
    return '', code.strip(), comment


def tokens(line):
    """what MAC/65 keeps of a line: two lines with the same tokens are
    the same line, however they are spaced"""
    return mac65tok.tokenize_line(squeeze(line))


def squeeze(line):
    """a line as MAC/65 lists it: one space between its fields"""
    if not line.strip():
        return ';'
    label, stmt, comment = split_line(line)
    if not label and not stmt:
        return comment.strip()
    stmt = squeeze_stmt(stmt)
    rest = ' '.join(x for x in (stmt, comment) if x)
    return f'{label} {rest}'.rstrip() if label else ' ' + rest


def squeeze_stmt(stmt):
    out, q, i = '', False, 0
    while i < len(stmt):
        c = stmt[i]
        if c == '"':
            q = not q
        if c == "'" and not q and i + 1 < len(stmt):
            out += stmt[i:i + 2]
            i += 2
            continue
        if c == ' ' and not q:
            if out and not out.endswith(' '):
                out += ' '
        else:
            out += c
        i += 1
    return out.strip()


def layout(line):
    """a line in the family's columns: label, the operation at OPCOL, an
    end-of-line comment at COMCOL (or one space after longer code)"""
    label, stmt, comment = split_line(line)
    if not label and not stmt:
        return comment.strip() or ';'
    code = (label.ljust(OPCOL - 1) + ' ' + squeeze_stmt(stmt)).rstrip() if stmt else label
    if comment:
        code = code.ljust(COMCOL - 1) + ' ' + comment if len(code) < COMCOL else code + ' ' + comment
    return code


def numbered(text):
    """git's text as MAC/65 lines: 10 LINE, 20 LINE, ..."""
    lines = text.split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    out = []
    for n, line in enumerate(lines, 1):
        if re.match(r'\d', line):
            raise SrcError(f'line {n} starts with a number: git keeps the sources without them')
        if '\t' in line:
            raise SrcError(f'line {n} has a TAB, which MAC/65 has not')
        out.append(f'{n * 10} {squeeze(line)}')
    return '\n'.join(out) + '\n'


def to_disk(text, name, program, version):
    """a git .M65 as its tokenised disk file"""
    head = f'; {name} - ' + (SHARED if name.startswith('AX') else f'{program} {version}')
    if head not in text.split('\n')[:4]:
        raise SrcError(f'{name}: no "{head}" line at the top')
    data = mac65tok.tokenize(numbered(text))
    if len(data) > MAXTOK:
        raise SrcError(f'{name}: {len(data)} bytes tokenised, over {MAXTOK}: split it')
    return data


def from_atari(data):
    """a file from the Atari (tokenised, or LIST's ATASCII) as lines
    without their numbers"""
    if data[:2] == b'\xfe\xfe':
        text = mac65tok.detokenize(data)
    else:
        text = mac65tok.from_bytes(data.replace(bytes([EOL]), b'\n')).replace('', '\n')
    out = []
    for line in text.split('\n'):
        if not line.strip():
            continue
        m = re.match(r'(\d+) ?(.*)$', line)
        if not m:
            raise SrcError(f'not a MAC/65 line: {line[:40]!r}')
        out.append(m.group(2))
    return out


def merge(atari_lines, git_text):
    """the Atari's lines in git's form: unchanged lines keep git's text"""
    old = git_text.split('\n') if git_text else []
    if old and old[-1] == '':
        old.pop()
    a = [tokens(x) for x in old]
    b = [tokens(x) for x in atari_lines]
    out = []
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if op == 'equal':
            out += old[i1:i2]
        else:
            out += [layout(x) for x in atari_lines[j1:j2]]
    return '\n'.join(out) + '\n'


def new_disk(path, volume):
    """an empty bootable SpartaDOS double density disk (720 x 256)"""
    size = 3 * 128 + (DD_SECTORS - 3) * 256
    paras = size // 16
    head = bytes([0x96, 0x02, paras & 255, (paras >> 8) & 255, 0, 1, paras >> 16]) + bytes(9)
    boot = bytearray(open(BOOT, 'rb').read())
    boot[0x0B], boot[0x0C] = DD_SECTORS & 255, DD_SECTORS >> 8
    template = path + '.tmp'
    open(template, 'wb').write(head + bytes(boot) + bytes(size - len(boot)))
    try:
        d = sparta.new_disk(path, template, volume)
    finally:
        os.remove(template)
    d.add('X32G.DOS', open(DOS, 'rb').read())
    d.set_boot_file('X32G.DOS')
    return d


def files_of(path):
    """{name: data} of a SpartaDOS disk's root directory"""
    d = sparta.Disk(path)
    out = {}
    for _, e in d.entries():
        if d.live(e) and not e[0] & 0x20:
            out[d.name(e)] = d.read_file(d.w(e, 1), e[3] | e[4] << 8 | e[5] << 16)
    return out


def cmd_disk(a):
    files = []
    for path in a.files:
        name = os.path.basename(path).upper()
        data = open(path, 'rb').read()
        if name.endswith('.M65'):
            data = to_disk(data.decode('utf-8'), name, a.program, a.version)
        files.append((name, data))
    if a.base:
        shutil.copyfile(a.base, a.atr)
        d = sparta.Disk(a.atr)
    else:
        d = new_disk(a.atr, a.volume or a.program.replace('_', '')[:8])
    for name, data in files:
        if d.find(name):
            d.remove(name)
        d.add(name, data)
    d.save()
    got = files_of(a.atr)
    for name, data in files:
        if got.get(name) != data:
            raise SrcError(f'{name} reads back wrong')
    problems, lost = sparta.Disk(a.atr).fsck()
    if problems or lost:
        raise SrcError(f'{a.atr}: {problems} {lost}')
    print(f'{a.atr}: {len(files)} files')


def cmd_check(a):
    d = sparta.Disk(a.atr)
    problems, lost = d.fsck()
    if problems or lost:
        raise SrcError(f'{a.atr}: {problems} {lost}')
    for name, data in files_of(a.atr).items():
        if a.to and name.endswith('.M65'):
            git = os.path.join(a.to, name)
            old = open(git, encoding='utf-8').read() if os.path.exists(git) else ''
            open(git, 'w', encoding='utf-8').write(merge(from_atari(data), old))
        print(f'{name} {len(data)} bytes')


def cmd_import(a):
    old = open(a.git, encoding='utf-8').read() if os.path.exists(a.git) else ''
    text = merge(from_atari(open(a.atari, 'rb').read()), old)
    open(a.git, 'w', encoding='utf-8').write(text)
    print(f'{a.git}: {text.count(chr(10))} lines')


def cmd_layout(a):
    for path in a.files:
        text = open(path, encoding='utf-8').read()
        lines = [re.sub(r'^\d+ ?', '', x) for x in text.split('\n')]
        if lines and lines[-1] == '':
            lines.pop()
        out = [layout(x) for x in lines]
        for old, new in zip(lines, out):
            if tokens(old) != tokens(new):
                raise SrcError(f'{path}: laying out changes {old!r}')
        open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
        print(f'{path}: {len(out)} lines')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('disk')
    p.add_argument('atr')
    p.add_argument('files', nargs='+')
    p.add_argument('--program', required=True)
    p.add_argument('--version', required=True)
    p.add_argument('--volume')
    p.add_argument('--base')
    p = sub.add_parser('check')
    p.add_argument('atr')
    p.add_argument('--to')
    p = sub.add_parser('layout')
    p.add_argument('files', nargs='+')
    p = sub.add_parser('import')
    p.add_argument('atari')
    p.add_argument('git')
    a = ap.parse_args()
    try:
        {'disk': cmd_disk, 'check': cmd_check, 'import': cmd_import,
         'layout': cmd_layout}[a.cmd](a)
    except (SrcError, mac65tok.TokError) as e:
        print(f'error: {e}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
