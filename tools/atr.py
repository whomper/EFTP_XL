#!/usr/bin/env python3
"""Write files into Atari DOS 2.0S / 2.5 / MyDOS (720-sector) ATR images.

  atr.py new    DISK.ATR                   blank DOS 2 single-density disk
  atr.py put    DISK.ATR FILE [NAME.EXT]   add or replace a file
  atr.py ls     DISK.ATR                   list the directory
  atr.py get    DISK.ATR NAME.EXT OUT      extract a file

Supports 720-sector disks with 128-byte sectors (DOS 2.0S, DOS 2.5 SD,
MyDOS SD) and 256-byte sectors (MyDOS DD). Boot sectors and DOS.SYS are left
alone, so 'put' on a copy of a DOS 2.5 or MyDOS master disk gives a bootable
disk. Enhanced-density (1040-sector, VTOC2) disks are refused.
"""
import struct
import sys

VTOC, DIR_FIRST, DIR_LAST = 360, 361, 368


class Disk:
    def __init__(self, path):
        self.path = path
        d = bytearray(open(path, 'rb').read())
        if d[:2] != b'\x96\x02':
            raise SystemExit(f"{path}: not an ATR image")
        self.hdr, self.body = d[:16], d[16:]
        self.secsize = d[4] | d[5] << 8
        size = (d[2] | d[3] << 8 | d[6] << 16) * 16
        if self.secsize == 128:
            self.count = size // 128
        else:
            self.count = 3 + (size - 3 * 128) // self.secsize
        if self.count != 720:
            raise SystemExit(f"{path}: {self.count} sectors; only 720-sector disks are supported")

    def check_dos2(self):
        if self.read(VTOC)[0] not in (2, 3):
            raise SystemExit(f"{self.path}: no DOS 2/MyDOS VTOC at sector 360 "
                             "(SpartaDOS disk?)")

    # sectors 1-3 are always 128 bytes in an ATR
    def _off(self, n):
        return (n - 1) * 128 if n <= 3 else 3 * 128 + (n - 4) * self.secsize

    def read(self, n):
        o = self._off(n)
        return bytearray(self.body[o:o + (128 if n <= 3 else self.secsize)])

    def write(self, n, data):
        o = self._off(n)
        ln = 128 if n <= 3 else self.secsize
        assert len(data) == ln
        self.body[o:o + ln] = data

    def save(self):
        open(self.path, 'wb').write(bytes(self.hdr) + bytes(self.body))

    # VTOC bitmap: bit set = free; sector n -> byte 10 + n//8, bit 7 - n%8
    def is_free(self, v, n):
        return bool(v[10 + n // 8] & (0x80 >> (n % 8)))

    def set_free(self, v, n, free):
        if free:
            v[10 + n // 8] |= 0x80 >> (n % 8)
        else:
            v[10 + n // 8] &= ~(0x80 >> (n % 8)) & 0xFF

    def entries(self):
        for s in range(DIR_FIRST, DIR_LAST + 1):
            sec = self.read(s)
            for k in range(8):
                yield (s - DIR_FIRST) * 8 + k, s, k, sec[k * 16:(k + 1) * 16]

    @staticmethod
    def fname(e):
        n = e[5:13].decode('latin1').rstrip()
        x = e[13:16].decode('latin1').rstrip()
        return n + ('.' + x if x else '')

    def chain(self, start, fileno):
        n, seen = start, set()
        while n and n not in seen:
            if n > self.count:
                raise SystemExit(f"bad sector link {n}")
            seen.add(n)
            sec = self.read(n)
            L = self.secsize
            fn = sec[L - 3] >> 2
            if fn != fileno:
                raise SystemExit(f"sector {n}: file number {fn}, expected {fileno}")
            yield n, bytes(sec[:sec[L - 1]])
            n = (sec[L - 3] & 3) << 8 | sec[L - 2]

    def find(self, name):
        for idx, s, k, e in self.entries():
            if e[0] & 0x40 and not e[0] & 0x80 and self.fname(e) == name:
                return idx, s, k, e
        return None


def split_name(name):
    name = name.upper()
    base, _, ext = name.partition('.')
    if not (1 <= len(base) <= 8 and len(ext) <= 3 and base.replace('_', 'A').isalnum()
            and (not ext or ext.isalnum())):
        raise SystemExit(f"invalid DOS 2 file name {name!r}")
    return base.ljust(8).encode(), ext.ljust(3).encode()


def cmd_new(path):
    secsize = 128
    size = 720 * 128
    paras = size // 16
    hdr = bytearray(16)
    hdr[0:2] = b'\x96\x02'
    struct.pack_into('<HH', hdr, 2, paras & 0xFFFF, secsize)
    hdr[6] = paras >> 16
    open(path, 'wb').write(bytes(hdr) + bytes(size))
    d = Disk(path)
    v = bytearray(128)
    v[0] = 2                                      # DOS 2 VTOC
    free = [n for n in range(1, 720) if not (n <= 3 or VTOC <= n <= DIR_LAST)]
    struct.pack_into('<HH', v, 1, len(free), len(free))
    for n in free:
        d.set_free(v, n, True)
    d.write(VTOC, v)
    d.save()
    print(f"{path}: blank DOS 2 disk, {len(free)} free sectors")


def cmd_put(path, src, name=None):
    import os
    d = Disk(path)
    d.check_dos2()
    name = (name or os.path.basename(src)).upper()
    base, ext = split_name(name)
    data = open(src, 'rb').read()
    v = d.read(VTOC)
    old = d.find(name)
    if old:                                       # delete, freeing its sectors
        idx, s, k, e = old
        start = e[3] | e[4] << 8
        for n, _ in list(d.chain(start, idx)):
            d.set_free(v, n, True)
        struct.pack_into('<H', v, 3, (v[3] | v[4] << 8) + (e[1] | e[2] << 8))
        slot = (idx, s, k)
    else:
        slot = next(((idx, s, k) for idx, s, k, e in d.entries()
                     if e[0] == 0 or e[0] & 0x80), None)
        if slot is None:
            raise SystemExit("directory full")
    idx, s, k = slot
    per = d.secsize - 3
    chunks = [data[i:i + per] for i in range(0, len(data), per)] or [b'']
    free = [n for n in range(1, 720) if d.is_free(v, n)]
    if len(free) < len(chunks):
        raise SystemExit(f"disk full: need {len(chunks)} sectors, {len(free)} free")
    secs = free[:len(chunks)]
    for i, (n, c) in enumerate(zip(secs, chunks)):
        nxt = secs[i + 1] if i + 1 < len(secs) else 0
        sec = bytearray(d.secsize)
        sec[:len(c)] = c
        sec[d.secsize - 3] = (idx << 2) | (nxt >> 8)
        sec[d.secsize - 2] = nxt & 0xFF
        sec[d.secsize - 1] = len(c)
        d.write(n, sec)
        d.set_free(v, n, False)
    struct.pack_into('<H', v, 3, (v[3] | v[4] << 8) - len(secs))
    d.write(VTOC, v)
    dsec = d.read(s)
    ent = bytearray(16)
    ent[0] = 0x42                                 # in use, DOS 2 file
    struct.pack_into('<HH', ent, 1, len(secs), secs[0])
    ent[5:13], ent[13:16] = base, ext
    dsec[k * 16:(k + 1) * 16] = ent
    d.write(s, dsec)
    d.save()
    print(f"{path}: {name} {len(data)} bytes in {len(secs)} sectors, "
          f"{v[3] | v[4] << 8} free")


def cmd_ls(path):
    d = Disk(path)
    d.check_dos2()
    for idx, s, k, e in d.entries():
        if e[0] == 0:
            break
        if e[0] & 0x80 or not e[0] & 0x40:
            continue
        size = sum(len(b) for _, b in d.chain(e[3] | e[4] << 8, idx))
        lock = '*' if e[0] & 0x20 else ' '
        print(f"{lock} {d.fname(e):<12} {e[1] | e[2] << 8:4d} sectors {size:7d} bytes")
    v = d.read(VTOC)
    print(f"{v[3] | v[4] << 8} free sectors")


def cmd_get(path, name, out):
    d = Disk(path)
    d.check_dos2()
    f = d.find(name.upper())
    if not f:
        raise SystemExit(f"{name}: not found")
    idx, s, k, e = f
    open(out, 'wb').write(b''.join(b for _, b in d.chain(e[3] | e[4] << 8, idx)))


if __name__ == '__main__':
    a = sys.argv[1:]
    cmds = {'new': (cmd_new, 1, 1), 'put': (cmd_put, 2, 3), 'ls': (cmd_ls, 1, 1), 'get': (cmd_get, 3, 3)}
    if not a or a[0] not in cmds or not cmds[a[0]][1] <= len(a) - 1 <= cmds[a[0]][2]:
        print(__doc__)
        sys.exit(1)
    cmds[a[0]][0](*a[1:])
