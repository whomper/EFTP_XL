# AERA-Atari xl/tools/a8sim - the machine
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""A 6502 with 64K (or 130XE banks), the OS calls a program makes stood in
for, a binary load as DOS does it, RESET as the OS's warm start."""
import time

from py65.devices.mpu6502 import MPU

RTCLOK, DOSVEC, DOSINI = 0x12, 0x0A, 0x0C
SAVMSC, RAMTOP = 0x58, 0x6A
DCB, IOCB = 0x300, 0x340
RUNAD, INITAD, MEMTOP, MEMLO = 0x2E0, 0x2E2, 0x2E5, 0x2E7
COLOR1, COLOR2, COLOR4 = 0x2C5, 0x2C6, 0x2C8
CHBAS, CH, PORTB = 0x2F4, 0x2FC, 0xD301
CIOV, SIOV, DSKINV = 0xE456, 0xE459, 0xE453
DOS_TRAP = 0xE710           # DOSVEC: back to DOS ends the run
DOSINI_TRAP = 0xE720        # DOSINI: DOS's own init, an RTS
RETURN_TRAP = 0xFFF0        # the return address that ends a call
SCREEN = 0xBC40             # GRAPHICS 0's screen with MEMTOP $BC1F
CLOCK_STEPS = 2000          # how often RTCLOK moves


class Stop(Exception):
    """ends a run: back to DOS, or the key script is done"""


class BankedMemory:
    """64K, and the 130XE's banks at $4000-$7FFF: PORTB bit 4 clear gives
    the CPU the bank its bits 2,3,5,6 ($6C: 16 banks, 256K) or 1,2,3,5,6
    ($6E: 32 banks, 512K) name (EDOS's)."""

    def __init__(self, bank_bits=0x6C):
        self.bank_bits = bank_bits
        self.main = bytearray(0x10000)
        self.banks = {}
        self.main[PORTB] = 0xFF

    def _bank(self, addr):
        pb = self.main[PORTB]
        if 0x4000 <= addr < 0x8000 and not pb & 0x10:
            return self.banks.setdefault(pb & self.bank_bits, bytearray(0x4000))
        return None

    def __getitem__(self, addr):
        if isinstance(addr, slice):
            return bytes(self[a] for a in range(*addr.indices(0x10000)))
        b = self._bank(addr)
        return b[addr - 0x4000] if b is not None else self.main[addr]

    def __setitem__(self, addr, val):
        if isinstance(addr, slice):
            for a, v in zip(range(*addr.indices(0x10000)), val):
                self[a] = v
            return
        b = self._bank(addr)
        if b is not None:
            b[addr - 0x4000] = val & 0xFF
        else:
            self.main[addr] = val & 0xFF

    def __len__(self):
        return 0x10000


class Machine:
    """mem, mpu; cio and sio are the CIO and SIO stand-ins (cio.py,
    sio.py); traps {addr: f(m)} for other OS addresses at $C000 up (f
    does the work and m.rts()); watch {pc: f(m)} runs before the
    instruction at pc. clock: 'wall' (RTCLOK at 60 Hz of real time, for
    real servers' timeouts) or 'steps' (one jiffy every CLOCK_STEPS
    instructions, the same every run)."""

    def __init__(self, memory=None, banks=None, memlo=0x1F00, memtop=0xBC1F, clock='wall'):
        self.mem = memory if memory is not None else (
            BankedMemory(banks) if banks else bytearray(0x10000))
        self.mpu = MPU(memory=self.mem)
        self.cio = None
        self.sio = None
        self.traps = {}
        self.watch = {}
        self.syms = {}
        self.clock = clock
        self.steps = 0
        self.t0 = time.monotonic()
        self.to_dos = False
        self.reset_pending = False
        self.resets = 0
        self.on_reset = []          # f(m) at RESET: devices close their files
        self.unknown = 'raise'      # or 'run': an OS address no trap knows runs on
        self.poke(RAMTOP, [0xC0])
        self.poke_word(SAVMSC, SCREEN)
        self.poke_word(MEMTOP, memtop)
        self.poke_word(MEMLO, memlo)
        self.poke_word(DOSVEC, DOS_TRAP)
        self.poke_word(DOSINI, DOSINI_TRAP)
        self.os_colours()
        self.poke(CH, [0xFF])
        self.poke(0x11, [0x80])             # BRKKEY: BREAK not pressed

    # -- memory
    def peek(self, addr):
        return self.mem[addr]

    def poke(self, addr, data):
        for i, v in enumerate(data):
            self.mem[addr + i] = v

    def word(self, addr):
        return self.mem[addr] | self.mem[addr + 1] << 8

    def poke_word(self, addr, v):
        self.poke(addr, [v & 255, v >> 8 & 255])

    def os_colours(self):
        """the OS's GRAPHICS 0: ROM font, light blue text on blue"""
        self.poke(CHBAS, [0xE0])
        self.poke(COLOR1, [0xCA])
        self.poke(COLOR2, [0x94])
        self.poke(COLOR4, [0x00])

    def load_symbols(self, path):
        """mac65.py's -s file: NAME $XXXX a line"""
        with open(path) as f:
            for line in f:
                p = line.split()
                if len(p) == 2 and p[1].startswith('$'):
                    self.syms[p[0].upper()] = int(p[1][1:], 16)
        return self.syms

    def __getitem__(self, name):
        return self.syms[name.upper()]

    # -- the OS's ways back
    def rts(self, a=None, y=None):
        """return from a trapped JSR; Y sets N and Z as CIO's status does"""
        mpu, m = self.mpu, self.mem
        lo = m[0x100 + ((mpu.sp + 1) & 255)]
        hi = m[0x100 + ((mpu.sp + 2) & 255)]
        mpu.sp = (mpu.sp + 2) & 255
        mpu.pc = ((hi << 8) | lo) + 1 & 0xFFFF
        if a is not None:
            mpu.a = a & 255
        if y is not None:
            mpu.y = y & 255
            mpu.p &= ~(mpu.NEGATIVE | mpu.ZERO)
            mpu.p |= (mpu.NEGATIVE if y & 0x80 else 0) | (mpu.ZERO if y & 255 == 0 else 0)

    def _tick(self):
        if self.clock == 'wall':
            t = int((time.monotonic() - self.t0) * 60)
        else:
            t = self.steps // CLOCK_STEPS
        self.poke(RTCLOK, [(t >> 16) & 255, (t >> 8) & 255, t & 255])

    def _trap(self, pc):
        if self.clock == 'wall':
            self._tick()
        if pc in self.traps:
            self.traps[pc](self)
        elif pc == CIOV and self.cio:
            x = self.mpu.x
            y, a = self.cio.call(self, x)
            self.mem[IOCB + x + 3] = y
            self.rts(a=a, y=y)
            self.mpu.x = x
        elif pc in (SIOV, DSKINV) and self.sio:
            y = self.sio.call(self, dskinv=pc == DSKINV)
            self.mem[DCB + 3] = y
            self.rts(y=y)
        elif pc == DOS_TRAP:
            self.to_dos = True
            raise Stop('back to DOS')
        elif pc == DOSINI_TRAP:
            self.rts()
        elif self.unknown == 'run':
            return False
        else:
            raise RuntimeError(f'unhandled OS call at ${pc:04X}')
        return True

    def reset(self):
        """press RESET: done once the current instruction ends"""
        self.reset_pending = True

    def _warm_start(self):
        """the OS's warm start: files closed, the ROM font and colours
        back, a fresh stack, JSR (DOSINI); if that returns, JMP (DOSVEC).
        Memory is kept."""
        self.reset_pending = False
        self.resets += 1
        if self.cio and hasattr(self.cio, 'reset'):
            self.cio.reset()
        for f in self.on_reset:
            f(self)
        self.os_colours()
        m, mpu = self.mem, self.mpu
        ret = DOS_TRAP - 1
        m[0x1FF], m[0x1FE] = ret >> 8, ret & 255
        mpu.sp = 0xFD
        mpu.pc = self.word(DOSINI)

    # -- running
    def call(self, target, a=0, x=0, y=0, max_steps=500_000_000):
        """JSR to an address or a symbol; run until it returns. Returns
        the MPU (its registers and flags)."""
        addr = self.syms[target.upper()] if isinstance(target, str) else target
        mpu, m = self.mpu, self.mem
        ret = RETURN_TRAP - 1
        m[0x1FF], m[0x1FE] = ret >> 8, ret & 255
        mpu.sp = 0xFD
        mpu.a, mpu.x, mpu.y, mpu.pc = a, x, y, addr
        watch, step = self.watch, mpu.step
        for _ in range(max_steps):
            pc = mpu.pc
            if pc == RETURN_TRAP:
                return mpu
            if pc >= 0xC000 and self._trap(pc):
                continue
            if pc in watch:
                watch[pc](self)
                if self.reset_pending:
                    self._warm_start()
                    continue
            step()
            self.steps += 1
            if self.steps % CLOCK_STEPS == 0:
                self._tick()
            if self.reset_pending:
                self._warm_start()
        raise RuntimeError(f'no return from {target!r} (pc=${mpu.pc:04X})')

    @staticmethod
    def segments(data):
        """[(start, bytes)] of a binary load file"""
        out, i = [], 0
        while i < len(data):
            if data[i:i + 2] == b'\xff\xff':
                i += 2
            start, end = data[i] | data[i + 1] << 8, data[i + 2] | data[i + 3] << 8
            i += 4
            out.append((start, data[i:i + end - start + 1]))
            i += end - start + 1
        return out

    def load(self, prg, init=True):
        """a binary load file, segment by segment as DOS loads it: each
        INITAD set by a segment is called before the next one comes.
        Returns False when an init went back to DOS."""
        if isinstance(prg, str):
            with open(prg, 'rb') as f:
                data = f.read()
        else:
            data = prg
        self.poke_word(RUNAD, 0)
        for start, chunk in self.segments(data):
            self.poke_word(INITAD, 0)
            self.poke(start, chunk)
            if init and self.word(INITAD):
                try:
                    self.call(self.word(INITAD))
                except Stop:
                    return False
        return True

    def run(self, prg, max_steps=500_000_000):
        """load, then run from RUNAD until it goes back to DOS or the key
        script ends (Stop)"""
        try:
            if self.load(prg) and self.word(RUNAD):
                self.call(self.word(RUNAD), max_steps=max_steps)
        except Stop:
            pass
