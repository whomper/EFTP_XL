# AERA-Atari xl/tools/mac65real - from EDOS (tools/run65), as EDOS sent it
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Run the MAC/65 cartridge (OSS 091M, .car type 15) on py65 with a small
CIO (E:, K:, D:) so a program can be assembled by the real MAC/65.

    run65.py CAR DIR MEMLO 'COMMAND' ['COMMAND' ...]

DIR holds the D: files (read and written there). Prints the screen."""
import os, sys
from py65.devices.mpu6502 import MPU
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fp as fpmod

EOL = 0x9B
CIOV, SIOV, DSKINV = 0xE456, 0xE459, 0xE453
RET = 0xFFF0
PUTB = 0xE700           # device put-byte entry put into ICPTL/H (CIO does this on OPEN)


class Mem:
    MAP = {0x00: 1, 0x01: 3, 0x09: 2, 0x08: None}     # $D5xx & $09 -> file block at $A000
    def __init__(self, rom):
        self.ram = bytearray(0x10000)
        self.rom = rom
        self.bank = 1
        self.switches = []
    def sel(self, a):
        b = self.MAP.get(a & 0x09, 'x')
        if b != 'x':
            self.bank = b
            self.switches.append(a)
    def __getitem__(self, a):
        if isinstance(a, slice):
            return [self[i] for i in range(*a.indices(0x10000))]
        if 0xB000 <= a < 0xC000:
            return self.rom[a - 0xB000]
        if 0xA000 <= a < 0xB000 and self.bank is not None:
            return self.rom[self.bank * 4096 + a - 0xA000]
        if 0xD500 <= a <= 0xD5FF:
            self.sel(a); return 0xFF
        return self.ram[a]
    def __setitem__(self, a, v):
        if isinstance(a, slice):
            for i, x in zip(range(*a.indices(0x10000)), v): self[i] = x
            return
        if 0xD500 <= a <= 0xD5FF:
            self.sel(a); return
        if 0xB000 <= a < 0xC000 or (0xA000 <= a < 0xB000 and self.bank is not None):
            return
        self.ram[a] = v & 0xFF
    def __len__(self):
        return 0x10000


class Stop(Exception):
    pass


class Atari:
    def __init__(self, rom, files_dir, lines, memlo=0x2000, memtop=0x9C1F):
        self.m = Mem(rom)
        self.cpu = MPU(memory=self.m)
        self.dir = files_dir
        self.lines = list(lines)
        self.screen = bytearray()
        self.open = {}
        self.unknown = []
        self.sparta = bool(os.environ.get('SPARTA'))
        self.fp = fpmod.FP(self)
        self.fpcalls = {}
        m = self.m
        m.ram[0x6A] = 0xA0                      # RAMTOP
        m.ram[0x2E5], m.ram[0x2E6] = memtop & 0xFF, memtop >> 8
        m.ram[0x2E7], m.ram[0x2E8] = memlo & 0xFF, memlo >> 8
        m.ram[0x0E], m.ram[0x0F] = memlo & 0xFF, memlo >> 8   # APPMHI
        m.ram[0x11] = 0x80                      # BRKKEY: not pressed
        m.ram[0x244] = 1                        # COLDST: cold start (cart init sets its vectors)
        m.ram[0x08] = 0                         # WARMST
        for x in range(0, 0x80, 0x10):
            m.ram[0x340 + x] = 0xFF             # IOCBs closed
        m.ram[0x340] = 0                        # IOCB 0: E:
        m.ram[0x346], m.ram[0x347] = (PUTB - 1) & 0xFF, (PUTB - 1) >> 8
        self.open[0] = ('E', None)
        m.ram[0x0A], m.ram[0x0B] = 0xF0, 0xFF   # DOSVEC -> trap

    # -------------------------------------------------- CIO
    def field(self, x, off, n=1):
        r = self.m.ram
        return r[0x340 + x + off] if n == 1 else r[0x340 + x + off] | r[0x341 + x + off] << 8
    def setlen(self, x, n):
        self.m.ram[0x348 + x], self.m.ram[0x349 + x] = n & 0xFF, n >> 8
    def name(self, buf):
        s = ''
        while len(s) < 40:
            c = self.m[buf + len(s)]
            if c in (EOL, 0, 0x20): break
            s += chr(c)
        return s
    def cio(self, x):
        cmd = self.field(x, 2); buf = self.field(x, 4, 2); blen = self.field(x, 8, 2)
        if getattr(self, 'log', None) is not None:
            st = self.open.get(x)
            self.log.append((x >> 4, cmd, hex(buf), blen, st[1][2] if st and st[0] == 'D' else None))
        if cmd == 3:
            spec = self.name(buf); ax1 = self.field(x, 10)
            dev = spec[0].upper()
            if dev == 'D':
                fn = spec.split(':', 1)[1].upper()
                path = os.path.join(self.dir, fn)
                if ax1 & 8:
                    self.open[x] = ('D', [path, bytearray(), 0, 'w'])
                elif ax1 & 4:
                    if not os.path.exists(path): return 170
                    self.open[x] = ('D', [path, bytearray(open(path, 'rb').read()), 0, 'r'])
                else:
                    return 146
            else:
                self.open[x] = (dev, None)
            self.m.ram[0x340 + x] = 0
            self.m.ram[0x346 + x], self.m.ram[0x347 + x] = (PUTB - 1) & 0xFF, (PUTB - 1) >> 8
            return 1
        if x not in self.open:
            return 133
        dev, st = self.open[x]
        if cmd == 12:
            if dev == 'D' and st[3] == 'w':
                open(st[0], 'wb').write(bytes(st[1]))
            del self.open[x]; self.m.ram[0x340 + x] = 0xFF
            return 1
        if cmd == 13:
            return 1
        if dev in ('E', 'S', 'P'):
            if cmd in (9, 11):
                if blen == 0:
                    self.screen.append(self.cpu.a); return 1
                data = bytes(self.m[buf + k] for k in range(blen))
                if cmd == 9 and EOL in data: data = data[:data.index(EOL) + 1]
                self.screen += data; return 1
            if cmd in (5, 7):
                if not self.lines: raise Stop('no more input')
                line = self.lines.pop(0).encode() + bytes([EOL])
                self.screen += line                      # echo
                n = min(len(line), blen) if blen else 1
                for k in range(n): self.m[buf + k] = line[k]
                self.setlen(x, n)
                return 1, (line[0] if blen == 0 else None)
        if dev == 'K':
            if cmd == 7:
                if not self.lines: raise Stop('no more keys')
                k = self.lines.pop(0)
                return 1, ord(k[0]) if k else EOL
        if dev == 'D':
            path, data, pos, mode = st
            r = self.m.ram
            if cmd == 38 and self.sparta:       # NOTE, SpartaDOS: 24-bit file position in ICAX3-5
                if mode == 'w': pos = len(data)
                r[0x34C + x], r[0x34D + x], r[0x34E + x] = pos & 0xFF, pos >> 8 & 0xFF, pos >> 16
                return 1
            if cmd == 37 and self.sparta:       # POINT, SpartaDOS
                p = r[0x34C + x] | r[0x34D + x] << 8 | r[0x34E + x] << 16
                if p > len(data): return 166
                st[2] = p
                return 1
            if cmd == 38:                       # NOTE, DOS 2: fake sector = pos//125+4, byte = pos%125
                if mode == 'w': pos = len(data)
                sec = pos // 125 + 4
                r[0x34C + x], r[0x34D + x], r[0x34E + x] = sec & 0xFF, sec >> 8, pos % 125
                return 1
            if cmd == 37:                       # POINT, DOS 2
                sec = r[0x34C + x] | r[0x34D + x] << 8
                st[2] = (sec - 4) * 125 + r[0x34E + x]
                return 1
            if cmd in (7, 5) and mode == 'r':
                if blen == 0:
                    if pos >= len(data): return 136
                    st[2] += 1; return 1, data[pos]
                n = 0
                while n < blen and pos + n < len(data):
                    c = data[pos + n]; self.m[buf + n] = c; n += 1
                    if cmd == 5 and c == EOL: break
                st[2] += n; self.setlen(x, n)
                return 1 if n == blen or (cmd == 5 and n and self.m[buf + n - 1] == EOL) else 136
            if cmd in (11, 9) and mode == 'w':
                if blen == 0:
                    data.append(self.cpu.a); return 1
                data += bytes(self.m[buf + k] for k in range(blen)); return 1
        self.unknown.append(('CIO', hex(x), cmd, dev)); return 132

    # -------------------------------------------------- run
    def rts(self, y=None, a=None):
        c = self.cpu
        lo = self.m[0x100 + ((c.sp + 1) & 0xFF)]; hi = self.m[0x100 + ((c.sp + 2) & 0xFF)]
        c.sp = (c.sp + 2) & 0xFF; c.pc = (hi << 8 | lo) + 1
        if a is not None: c.a = a
        if y is not None:
            c.y = y & 0xFF
            c.p &= ~(c.NEGATIVE | c.ZERO)
            c.p |= c.NEGATIVE if y & 0x80 else 0
            c.p |= c.ZERO if y == 0 else 0
    def step_trap(self):
        c = self.cpu; pc = c.pc
        if pc == CIOV:
            x = c.x
            r = self.cio(x)
            y, a = r if isinstance(r, tuple) else (r, None)
            self.m.ram[0x343 + x] = y
            self.rts(y=y, a=a); c.x = x
            return True
        if pc == PUTB:                          # direct put byte, X = IOCB
            x = c.x
            dev, st = self.open.get(x, ('?', None))
            if dev in ('E', 'S', 'P'):
                self.screen.append(c.a)
            elif dev == 'D' and st[3] == 'w':
                st[1].append(c.a)
            else:
                self.unknown.append(('PUTB', hex(x), dev))
            self.rts(y=1)
            return True
        if pc in fpmod.ENTRY:
            name = fpmod.ENTRY[pc]
            self.fpcalls[name] = self.fpcalls.get(name, 0) + 1
            self.fp.call(name)
            p = c.p; self.rts(); c.p = p
            return True
        if pc >= 0xC000:
            self.unknown.append(('OS', hex(pc)))
            raise Stop(f'unhandled OS address ${pc:04X}')
        return False
    def call(self, addr, steps):
        c = self.cpu
        c.sp = 0xFF
        self.m.ram[0x1FF], self.m.ram[0x1FE] = (RET - 1) >> 8, (RET - 1) & 0xFF
        c.sp = 0xFD; c.pc = addr
        return self.run(steps)
    def run(self, steps):
        c = self.cpu
        for i in range(steps):
            if c.pc == RET: return 'returned'
            if self.step_trap(): continue
            c.step()
        return 'steps'


def screen_text(b):
    return ''.join('\n' if c == EOL else chr(c & 0x7F) if 32 <= (c & 0x7F) < 127 else '.' for c in b)


if __name__ == '__main__':
    car, d, memlo = sys.argv[1], sys.argv[2], int(sys.argv[3], 16)
    rom = open(car, 'rb').read()[16:]
    a = Atari(rom, d, sys.argv[4:], memlo=memlo)
    init = a.m[0xBFFE] | a.m[0xBFFF] << 8
    start = a.m[0xBFFA] | a.m[0xBFFB] << 8
    try:
        print('init:', a.call(init, 200000))
        a.cpu.pc = start
        print('run:', a.run(400_000_000))
    except Stop as e:
        print('stopped:', e)
    print('unknown:', a.unknown[:10])
    print('---- screen ----')
    print(screen_text(a.screen))
