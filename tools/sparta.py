#!/usr/bin/env python3
# From EDOS (github.com/whomper/EDOS, tools/sparta.py at 6061ed6), as it is.
"""Read and write files on SpartaDOS 2.x/3.x ATR disk images.

  sparta.py ls    DISK.ATR                  list the root directory
  sparta.py get   DISK.ATR NAME.EXT OUT     extract a file
  sparta.py put   DISK.ATR FILE [NAME.EXT]  add or replace a file (root dir)
  sparta.py rm    DISK.ATR NAME.EXT         delete a file
  sparta.py fsck  DISK.ATR                  check maps, bitmap and directory

Layout (boot sector 1): $09 root directory sector map, $0B total sectors,
$0D free sectors, $0F number of bitmap sectors, $10 first bitmap sector,
$12 data / $14 directory allocation start, $16 volume name, $1F sector
size (0 = 256), $20 version ($20 = 2.x/3.x), $26 volume sequence number.
Files and directories are chains of sector maps: next map, previous map,
then data sector numbers. Directory entries are 23 bytes: status ($08 in
use, $10 deleted, $20 subdirectory, $01 protected), first map sector,
3-byte length, 8+3 name, date DMY, time HMS; entry 0 is the directory
header (its length field is the directory length). Bitmap: 1 = free,
sector n at byte n>>3, bit 7-(n&7).

Writing bumps the volume sequence number so SpartaDOS notices the change.
Only the root directory is written to; subdirectories are not supported.
new_disk() makes an empty disk using another disk's boot code, and
set_boot_file() points the boot sector ($28) at the DOS file to load.
"""
import datetime
import os
import sys

ENT = 23


def _read(path):
    with open(path, 'rb') as f:
        return f.read()


def _write(path, data):
    with open(path, 'wb') as f:
        f.write(data)


class SpartaError(SystemExit):
    pass


class Disk:
    def __init__(self, path):
        self.path = path
        d = bytearray(_read(path))
        if d[:2] != b'\x96\x02':
            raise SpartaError(f"{path}: not an ATR image")
        self.hdr, self.body = d[:16], d[16:]
        self.ss = d[4] | d[5] << 8
        boot = self.read(1)
        if boot[0x20] not in (0x11, 0x20, 0x21):
            raise SpartaError(f"{path}: not a SpartaDOS 1.1/2.x/3.x disk (version byte ${boot[0x20]:02X})")
        if (256 if boot[0x1F] == 0 else boot[0x1F]) != self.ss:
            raise SpartaError(f"{path}: sector size mismatch")
        self.total = self.w(boot, 0x0B)
        self.per_map = (self.ss - 4) // 2

    # -- sectors
    @staticmethod
    def w(b, o):
        return b[o] | b[o + 1] << 8

    def _off(self, n):
        if not 1 <= n <= self.total:
            raise SpartaError(f"sector {n} out of range")
        return (n - 1) * 128 if n <= 3 else 3 * 128 + (n - 4) * self.ss

    def read(self, n):
        o = self._off(n) if hasattr(self, 'total') else (n - 1) * 128
        return bytearray(self.body[o:o + (128 if n <= 3 else self.ss)])

    def write(self, n, data):
        ln = 128 if n <= 3 else self.ss
        data = bytes(data).ljust(ln, b'\0')
        assert len(data) == ln
        o = self._off(n)
        self.body[o:o + ln] = data

    def save(self):
        boot = self.read(1)
        boot[0x26] = (boot[0x26] + 1) & 0xFF            # volume sequence number
        self.write(1, boot)
        _write(self.path, bytes(self.hdr) + bytes(self.body))

    # -- bitmap
    def bitmap(self):
        boot = self.read(1)
        first, count = self.w(boot, 0x10), boot[0x0F]
        return bytearray(b''.join(self.read(first + k) for k in range(count)))

    def put_bitmap(self, bm):
        boot = self.read(1)
        first, count = self.w(boot, 0x10), boot[0x0F]
        for k in range(count):
            self.write(first + k, bm[k * self.ss:(k + 1) * self.ss])
        free = sum(1 for n in range(1, self.total + 1) if bm[n >> 3] & (0x80 >> (n & 7)))
        boot[0x0D], boot[0x0E] = free & 0xFF, free >> 8
        self.write(1, boot)

    @staticmethod
    def is_free(bm, n):
        return bool(bm[n >> 3] & (0x80 >> (n & 7)))

    @staticmethod
    def set_free(bm, n, free):
        if free:
            bm[n >> 3] |= 0x80 >> (n & 7)
        else:
            bm[n >> 3] &= ~(0x80 >> (n & 7)) & 0xFF

    # -- files
    def chain(self, first_map, length):
        """(map sectors, data sectors) needed to hold length bytes"""
        maps, data, m, need = [], [], first_map, (length + self.ss - 1) // self.ss
        while m and len(data) < need:
            if m in maps:
                raise SpartaError(f"sector map loop at {m}")
            maps.append(m)
            x = self.read(m)
            data += [self.w(x, i) for i in range(4, self.ss, 2)]
            m = self.w(x, 0)
        if len(data) < need:
            raise SpartaError(f"sector map at {first_map} too short for {length} bytes")
        return maps, data[:need]

    def read_file(self, first_map, length):
        maps, data = self.chain(first_map, length)
        return b''.join(self.read(s) if s else bytes(self.ss) for s in data)[:length]

    def root(self):
        return self.w(self.read(1), 0x09)

    def dir_bytes(self):
        m = self.root()
        hdr = self.read_file(m, ENT)
        return bytearray(self.read_file(m, hdr[3] | hdr[4] << 8 | hdr[5] << 16))

    def entries(self):
        d = self.dir_bytes()
        for i in range(ENT, len(d) - ENT + 1, ENT):
            yield i, d[i:i + ENT]

    @staticmethod
    def name(e):
        n = e[6:14].decode('latin1').rstrip()
        x = e[14:17].decode('latin1').rstrip()
        return n + ('.' + x if x else '')

    @staticmethod
    def live(e):
        return e[0] & 0x08 and not e[0] & 0x10

    def find(self, name):
        for i, e in self.entries():
            if self.live(e) and self.name(e) == name.upper():
                return i, e
        return None

    def write_dir(self, d):
        m = self.root()
        maps, data = self.chain(m, len(d))
        for k, s in enumerate(data):
            self.write(s, d[k * self.ss:(k + 1) * self.ss])

    def alloc(self, bm, n):
        boot = self.read(1)
        start = self.w(boot, 0x12) or 1
        order = list(range(start, self.total + 1)) + list(range(1, start))
        got = [s for s in order if self.is_free(bm, s)][:n]
        if len(got) < n:
            raise SpartaError(f"disk full: need {n} sectors, {len(got)} free")
        for s in got:
            self.set_free(bm, s, False)
        return got

    def grow_dir(self, length):
        """make sure the root directory's sectors can hold length bytes"""
        m = self.root()
        x = self.read(m)
        have = [self.w(x, i) for i in range(4, self.ss, 2)]
        n = sum(1 for v in have if v)
        need = (length + self.ss - 1) // self.ss
        if need <= n:
            return
        if need > self.per_map or self.w(x, 0):
            raise SpartaError("directory too large for one sector map")
        bm = self.bitmap()
        (new,) = self.alloc(bm, 1)
        self.put_bitmap(bm)
        self.write(new, b'')
        x[4 + 2 * n], x[5 + 2 * n] = new & 0xFF, new >> 8
        self.write(m, x)

    def set_boot_file(self, name):
        """point the boot sector's DOS file ($28) at a file's sector map"""
        f = self.find(name)
        if not f:
            raise SpartaError(f"{name}: not found")
        m = self.w(f[1], 1)
        boot = self.read(1)
        boot[0x28], boot[0x29] = m & 0xFF, m >> 8
        self.write(1, boot)

    def remove(self, name):
        f = self.find(name)
        if not f:
            raise SpartaError(f"{name}: not found")
        i, e = f
        if e[0] & 0x20:
            raise SpartaError(f"{name}: is a directory")
        length = e[3] | e[4] << 8 | e[5] << 16
        maps, data = self.chain(self.w(e, 1), length)
        bm = self.bitmap()
        for s in maps + [s for s in data if s]:
            self.set_free(bm, s, True)
        self.put_bitmap(bm)
        d = self.dir_bytes()
        d[i] = (d[i] | 0x10) & ~0x08 & 0xFF
        self.write_dir(d)

    def add(self, name, data, when=None, stamp=None):
        base, _, ext = name.upper().partition('.')
        if not (1 <= len(base) <= 8 and len(ext) <= 3):
            raise SpartaError(f"invalid name {name}")
        if self.find(name):
            self.remove(name)
        d = self.dir_bytes()
        slot = next((i for i, e in self.entries() if not self.live(e)), None)
        if slot is None:                                 # grow the directory
            slot = len(d)
            d += bytes(ENT)
            self.grow_dir(len(d))
            d[3], d[4], d[5] = len(d) & 0xFF, len(d) >> 8 & 0xFF, len(d) >> 16
        bm = self.bitmap()
        nsec = (len(data) + self.ss - 1) // self.ss
        nmap = max(1, (nsec + self.per_map - 1) // self.per_map)
        secs = self.alloc(bm, nmap + nsec)
        maps, dsecs = secs[:nmap], secs[nmap:]
        for k, m in enumerate(maps):
            x = bytearray(self.ss)
            nxt = maps[k + 1] if k + 1 < len(maps) else 0
            prv = maps[k - 1] if k else 0
            x[0:4] = bytes([nxt & 0xFF, nxt >> 8, prv & 0xFF, prv >> 8])
            for j, s in enumerate(dsecs[k * self.per_map:(k + 1) * self.per_map]):
                x[4 + 2 * j], x[5 + 2 * j] = s & 0xFF, s >> 8
            self.write(m, x)
        for k, s in enumerate(dsecs):
            self.write(s, data[k * self.ss:(k + 1) * self.ss])
        self.put_bitmap(bm)
        t = when or datetime.datetime.now()
        e = bytearray(ENT)
        e[0] = 0x08
        e[1], e[2] = maps[0] & 0xFF, maps[0] >> 8
        e[3], e[4], e[5] = len(data) & 0xFF, len(data) >> 8 & 0xFF, len(data) >> 16
        e[6:14] = base.ljust(8).encode()
        e[14:17] = ext.ljust(3).encode()
        e[17:20] = bytes([t.day, t.month, t.year % 100])
        e[20:23] = bytes([t.hour, t.minute, t.second])
        if stamp:                                        # keep a file's own date/time
            e[17:23] = stamp
        d[slot:slot + ENT] = e
        self.write_dir(d)

    def fsck(self):
        """return a list of problems (empty if consistent)"""
        problems, owner = [], {}
        boot = self.read(1)
        fixed = list(range(1, 4)) + [self.w(boot, 0x10) + k for k in range(boot[0x0F])]
        for s in fixed:
            owner[s] = 'system'

        def claim(s, who):
            if s in owner:
                problems.append(f"sector {s} used by {owner[s]} and {who}")
            owner[s] = who
        d = self.dir_bytes()
        maps, data = self.chain(self.root(), len(d))
        for s in maps + data:
            claim(s, 'root directory')
        for i, e in self.entries():
            if not self.live(e):
                continue
            n, length = self.name(e), e[3] | e[4] << 8 | e[5] << 16
            try:
                maps, data = self.chain(self.w(e, 1), length)
            except SpartaError as x:
                problems.append(f"{n}: {x.code}")
                continue
            for s in maps + [s for s in data if s]:
                claim(s, n)
        bm = self.bitmap()
        for s in range(1, self.total + 1):
            if s in owner and self.is_free(bm, s):
                problems.append(f"sector {s} ({owner[s]}) is marked free")
        used_unowned = [s for s in range(1, self.total + 1) if s not in owner and not self.is_free(bm, s)]
        free = sum(1 for s in range(1, self.total + 1) if self.is_free(bm, s))
        if free != self.w(boot, 0x0D):
            problems.append(f"boot says {self.w(boot, 0x0D)} free, bitmap has {free}")
        return problems, used_unowned


def new_disk(path, template, volume):
    """Empty SpartaDOS disk with the template's boot code and geometry.
    Layout: 1-3 boot, 4.. bitmap, then root directory map + one data sector."""
    t = Disk(template)
    ss, total = t.ss, t.total
    size = 3 * 128 + (total - 3) * ss
    hdr = bytearray(t.hdr)
    paras = size // 16
    hdr[2], hdr[3], hdr[6] = paras & 0xFF, paras >> 8 & 0xFF, paras >> 16
    _write(path, bytes(hdr) + bytes(size))
    d = Disk.__new__(Disk)
    d.path, d.hdr, d.body, d.ss, d.total = path, hdr, bytearray(size), ss, total
    d.per_map = (ss - 4) // 2
    for n in (1, 2, 3):
        d.write(n, t.read(n))
    nbm = (total + 1 + ss * 8 - 1) // (ss * 8)
    dmap, ddata = 4 + nbm, 5 + nbm
    boot = d.read(1)
    vol = volume.upper().ljust(8)[:8].encode()
    fields = {0x09: dmap, 0x0B: total, 0x10: 4, 0x12: ddata + 1, 0x14: dmap}
    for o, v in fields.items():
        boot[o], boot[o + 1] = v & 0xFF, v >> 8
    boot[0x0F] = nbm
    boot[0x16:0x1E] = vol
    boot[0x26] = 0                                      # keep the template's random id ($27)
    boot[0x28] = boot[0x29] = 0                         # no DOS file yet
    d.write(1, boot)
    bm = bytearray(nbm * ss)
    for n in range(ddata + 1, total + 1):
        Disk.set_free(bm, n, True)
    d.put_bitmap(bm)
    m = bytearray(ss)
    m[4], m[5] = ddata & 0xFF, ddata >> 8
    d.write(dmap, m)
    h = bytearray(ENT)
    h[0], h[3] = 0x28, ENT
    h[6:17] = b'MAIN       '
    d.write(ddata, h)
    _write(path, bytes(hdr) + bytes(d.body))
    return Disk(path)


def main():
    a = sys.argv[1:]
    if len(a) < 2 or a[0] not in ('ls', 'get', 'put', 'rm', 'fsck'):
        print(__doc__)
        return 1
    d = Disk(a[1])
    if a[0] == 'ls':
        for i, e in d.entries():
            if d.live(e):
                kind = '<DIR>' if e[0] & 0x20 else f"{e[3] | e[4] << 8 | e[5] << 16:7d}"
                print(f"{'*' if e[0] & 1 else ' '} {d.name(e):<12} {kind}  "
                      f"{e[17]:02d}-{e[18]:02d}-{e[19]:02d} {e[20]:02d}:{e[21]:02d}")
        print(f"{d.w(d.read(1), 0x0D)} free sectors")
    elif a[0] == 'get':
        f = d.find(a[2])
        if not f:
            raise SpartaError(f"{a[2]}: not found")
        e = f[1]
        _write(a[3], d.read_file(d.w(e, 1), e[3] | e[4] << 8 | e[5] << 16))
    elif a[0] == 'put':
        name = (a[3] if len(a) > 3 else os.path.basename(a[2])).upper()
        data = _read(a[2])
        d.add(name, data)
        d.save()
        print(f"{a[1]}: {name} {len(data)} bytes, {d.w(d.read(1), 0x0D)} free sectors")
    elif a[0] == 'rm':
        d.remove(a[2])
        d.save()
    elif a[0] == 'fsck':
        problems, lost = d.fsck()
        for p in problems:
            print(p)
        if lost:
            print(f"{len(lost)} sectors marked used but not owned by any file: {lost[:20]}")
        print('OK' if not problems else f"{len(problems)} problem(s)")
        return 1 if problems else 0
    return 0


if __name__ == '__main__':
    sys.exit(main())
