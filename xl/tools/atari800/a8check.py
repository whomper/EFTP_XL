#!/usr/bin/env python3
# AERA-Atari xl/tools - the release checks in atari800 (guidelines 8, level 2)
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""The program's disk in atari800 with its own OS ROM (no Atari ROMs needed),
through a8run (build.sh). From EFTP_XL's build-machine checks.

  a8check.py start A8RUN DISK.ATR PROGRAM TEXT
      the disk boots SpartaDOS, PROGRAM is typed at the D1: prompt, and
      TEXT (e.g. the title "EFTP_XL 1.1") must come on the screen
  a8check.py mac65 A8RUN DISK.ATR MAIN.M65 PROGRAM CART
      MAC/65 (CART: Erez's MAC/65 1.01 cartridge image, type 15, never
      in git) LOADs MAIN.M65 from the disk and assembles it with
      ASM ,,#D:A8CHECK.OBJ; it must report 0 errors, and the object must
      load the same bytes as PROGRAM on the disk (MAC/65 cuts its
      segments differently, so the files are compared as memory)

Both work on a copy of the disk. Exit 0 when the check passes.
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import sparta  # noqa: E402


def image(data):
    """{address: byte} a binary load file loads, and its segments"""
    i, mem, segs = 0, {}, []
    while i < len(data):
        if data[i:i + 2] == b'\xff\xff':
            i += 2
        a, b = data[i] | data[i + 1] << 8, data[i + 2] | data[i + 3] << 8
        i += 4
        segs.append((a, b))
        for k in range(b - a + 1):
            mem[a + k] = data[i + k]
        i += b - a + 1
    return mem, segs


def same_load(a, b):
    """the addresses where two binary load files differ"""
    m1, m2 = image(a)[0], image(b)[0]
    return sorted(x for x in set(m1) | set(m2) if m1.get(x) != m2.get(x))


def run(a8run, script, args):
    with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False) as f:
        f.write(script)
    try:
        r = subprocess.run([a8run, f.name, '--'] + args, capture_output=True, text=True,
                           timeout=3600)
    finally:
        os.remove(f.name)
    return r.returncode, r.stdout


def get(disk, name):
    d = sparta.Disk(disk)
    e = d.find(name)
    if not e:
        return None
    e = e[1]
    return d.read_file(d.w(e, 1), e[3] | e[4] << 8 | e[5] << 16)


def check_start(a8run, disk, program, text):
    tmp = tempfile.mkdtemp()
    try:
        t = os.path.join(tmp, 'T.ATR')
        shutil.copy(disk, t)
        code, out = run(a8run, f'until D1: 400\nwait 60\ntype {program}\\n\n'
                               f'until {text} 300\nscreen\n', ['-xl', '-nobasic', t])
        print(out)
        return code == 0 and text in out
    finally:
        shutil.rmtree(tmp)


def check_mac65(a8run, disk, main, program, cart):
    tmp = tempfile.mkdtemp()
    try:
        t = os.path.join(tmp, 'T.ATR')
        shutil.copy(disk, t)
        code, out = run(a8run, f'until Edit 200\nclear\ntype LOAD #D:{main}\\n\nuntil Edit 3000\n'
                               'clear\ntype ASM ,,#D:A8CHECK.OBJ\\n\nuntil ERRORS 60000\n'
                               'wait 300\nscreen\n',      # 300: MAC/65 closes the file
                        ['-xl', '-nobasic', '-cart', cart, '-cart-type', '15', t])
        print(out)
        if code or 'ERRORS: 0' not in out.replace('  ', ' '):
            return False
        obj, prg = get(t, 'A8CHECK.OBJ'), get(t, program)
        if not obj or not prg:
            print(f'no A8CHECK.OBJ or {program} on the disk')
            return False
        diff = same_load(obj, prg)
        print(f'MAC/65 on the Atari: {len(diff)} bytes differ from {program}'
              + (f' (first ${diff[0]:04X})' if diff else ''))
        return not diff
    finally:
        shutil.rmtree(tmp)


def main():
    a = sys.argv[1:]
    if len(a) == 5 and a[0] == 'start':
        ok = check_start(*a[1:])
    elif len(a) == 6 and a[0] == 'mac65':
        ok = check_mac65(*a[1:])
    else:
        print(__doc__)
        return 1
    print('PASS' if ok else 'FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
