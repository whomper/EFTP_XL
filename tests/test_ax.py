#!/usr/bin/env python3
# AERA-Atari xl/tests - the AX includes on an emulated 6502
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""xl/src/AX*.M65, assembled by xl/tools/mac65.py into a small test
program and run on py65 (pip install py65) with a stand-in for CIO (E:
and D: files) and DOS (its init, its start, the INITAD calls of a
binary load).

    python3 xl/tests/test_ax.py
"""
import os
import shutil
import sys
import tempfile
import unittest

from py65.devices.mpu6502 import MPU

HERE = os.path.dirname(os.path.abspath(__file__))
XL = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(XL, 'tools'))
import mac65  # noqa: E402

CIOV, DOSINIT, DOSSTART = 0xE456, 0x0700, 0x0710
WARM = 0x2E00
EOL = 0x9B

TEST = """
         .INCLUDE #D:AXEQU.M65
AXPTR    =   $80
AXERRS   =   {errs}
AXLOW    =   $2000
AXHIGH   =   $3000
AXWARM   =   ${warm:04X}
         *=  $2F00
AXLOWM   .BYTE "low",EOL
AXROOMM  .BYTE "room",EOL
         .INCLUDE #D:AXLOAD.M65
         *=  $2000
         .INCLUDE #D:AXRESET.M65
         .INCLUDE #D:AXFONT.M65
         .INCLUDE #D:AXERR.M65
"""


class Atari:
    """a 6502 with 64K, CIO for E: and D:, and DOS's two vectors"""

    def __init__(self, program, files=None):
        self.mpu = MPU()
        self.mem = self.mpu.memory
        self.files = dict(files or {})
        self.screen = []
        self.iocb = {}
        self.dos_inits = 0
        self.syms = program.syms
        self.segments = program.segments
        self.w16(0x0A, DOSSTART)
        self.w16(0x0C, DOSINIT)
        self.w16(0x02E7, 0x1F00)       # MEMLO
        self.w16(0x02E5, 0x9C1F)       # MEMTOP

    def w16(self, a, v):
        self.mem[a], self.mem[a + 1] = v & 255, v >> 8

    def r16(self, a):
        return self.mem[a] | self.mem[a + 1] << 8

    def sym(self, name):
        return self.syms[name.upper()]

    def load(self):
        """a binary load: each segment in, then JSR (INITAD) if it was set.
        Returns 'dos' when an init went to DOSVEC, else None."""
        for start, data in self.segments:
            self.w16(0x02E2, 0)
            for k, b in enumerate(data):
                self.mem[start + k] = b
            init = self.r16(0x02E2)
            if init and self.call(init) == 'dos':
                return 'dos'
        return None

    def call(self, addr, a=0, x=0, y=0, limit=200000):
        """JSR addr; returns 'rts', 'dos', 'warm' or 'init' (where it ended)"""
        m = self.mpu
        m.a, m.x, m.y = a, x, y
        m.sp = 0xFF
        self.mem[0x01FF], self.mem[0x01FE] = 0xFF, 0xFE   # returns to $FFFF
        m.sp = 0xFD
        m.pc = addr
        for _ in range(limit):
            if m.pc == 0xFFFF:
                return 'rts'
            if m.pc == CIOV:
                self.cio()
                self.rts()
                continue
            if m.pc == DOSSTART:
                return 'dos'
            if m.pc == DOSINIT:
                self.dos_inits += 1
                self.rts()
                continue
            if m.pc == WARM:
                return 'warm'
            m.step()
        raise AssertionError(f'still running at ${m.pc:04X}')

    def rts(self):
        m = self.mpu
        lo = self.mem[0x100 + ((m.sp + 1) & 255)]
        hi = self.mem[0x100 + ((m.sp + 2) & 255)]
        m.sp = (m.sp + 2) & 255
        m.pc = ((hi << 8 | lo) + 1) & 0xFFFF

    def flag_c(self):
        return self.mpu.p & 1

    def cio(self):
        m = self.mpu
        x = m.x
        base = 0x0340 + x
        cmd = self.mem[base + 2]
        buf = self.r16(base + 4)
        length = self.r16(base + 8)
        status = 1
        if cmd == 0x03:                                   # OPEN
            name = bytearray()
            while self.mem[buf + len(name)] != EOL:
                name.append(self.mem[buf + len(name)])
            name = name.decode('ascii')
            if x in self.iocb:
                status = 129
            elif name.startswith('D:') and name[2:] in self.files:
                self.iocb[x] = [name[2:], 0]
            else:
                status = 170
        elif cmd == 0x07:                                 # GET bytes
            if x not in self.iocb:
                status = 133
            else:
                data = self.files[self.iocb[x][0]]
                pos = self.iocb[x][1]
                got = data[pos:pos + length]
                for k, b in enumerate(got):
                    self.mem[buf + k] = b
                self.iocb[x][1] = pos + len(got)
                if len(got) < length:
                    status = 136
                self.w16(base + 8, len(got))
        elif cmd == 0x09:                                 # PUT a line
            if x != 0:
                status = 135
            else:
                line = bytearray()
                while len(line) < length and self.mem[buf + len(line)] != EOL:
                    line.append(self.mem[buf + len(line)])
                self.screen.append(line.decode('ascii'))
        elif cmd == 0x0C:                                 # CLOSE
            self.iocb.pop(x, None)
        else:
            status = 132
        self.mem[base + 3] = status
        m.y = status
        m.p = (m.p & ~0x82) | (0x80 if status & 0x80 else 0) | (0 if status else 2)


class Program:
    def __init__(self, errs=2):
        tmp = tempfile.mkdtemp()
        try:
            for f in os.listdir(os.path.join(XL, 'src')):
                shutil.copy(os.path.join(XL, 'src', f), tmp)
            main = os.path.join(tmp, 'TEST.M65')
            with open(main, "w") as f:
                f.write(TEST.format(errs=errs, warm=WARM))
            asm = mac65.Assembler()
            asm.assemble(main)
        finally:
            shutil.rmtree(tmp)
        self.syms = asm.syms
        data, segs = asm.binary()
        self.segments = [(s, bytes(asm.mem[a] for a in range(s, e + 1))) for s, e in segs]


PROGRAM = Program()


class TestLoad(unittest.TestCase):
    def test_room(self):
        a = Atari(PROGRAM)
        self.assertIsNone(a.load())
        self.assertEqual(a.screen, [])

    def test_memlo_at_the_load_address(self):
        a = Atari(PROGRAM)
        a.w16(0x02E7, 0x2000)
        self.assertIsNone(a.load())

    def test_dos_too_big(self):
        a = Atari(PROGRAM)
        a.w16(0x02E7, 0x2001)
        self.assertEqual(a.load(), 'dos')
        self.assertEqual(a.screen, ['low'])

    def test_memory_too_small(self):
        a = Atari(PROGRAM)
        a.w16(0x02E5, 0x2FFF)
        self.assertEqual(a.load(), 'dos')
        self.assertEqual(a.screen, ['room'])
        a = Atari(PROGRAM)
        a.w16(0x02E5, 0x3000)
        self.assertIsNone(a.load())


class TestReset(unittest.TestCase):
    def setUp(self):
        self.a = Atari(PROGRAM)
        self.a.load()

    def test_chain(self):
        a = self.a
        self.assertEqual(a.call(a.sym('AXSTART')), 'rts')
        self.assertEqual(a.r16(0x0C), a.sym('AXINIT'))
        self.assertEqual(a.r16(a.sym('AXDOSI')), DOSINIT)
        # RESET: the OS calls DOSINI; DOS sets itself up, then our warm start
        self.assertEqual(a.call(a.r16(0x0C)), 'warm')
        self.assertEqual(a.dos_inits, 1)

    def test_second_start_keeps_dos(self):
        a = self.a
        a.call(a.sym('AXSTART'))
        a.call(a.sym('AXSTART'))           # run again, DOSINI ours already
        self.assertEqual(a.r16(a.sym('AXDOSI')), DOSINIT)
        self.assertEqual(a.call(a.r16(0x0C)), 'warm')
        self.assertEqual(a.dos_inits, 1)

    def test_quit(self):
        a = self.a
        a.call(a.sym('AXSTART'))
        a.call(a.sym('AXQUIT'))
        self.assertEqual(a.r16(0x0C), DOSINIT)

    def test_untouched_before_start(self):
        a = self.a                          # AXINIT before AXSTART: harmless
        self.assertEqual(a.call(a.sym('AXINIT')), 'warm')
        self.assertEqual(a.dos_inits, 0)


class TestFont(unittest.TestCase):
    FONT = bytes(range(256)) * 4

    def test_read(self):
        a = Atari(PROGRAM, {'AERA.FNT': self.FONT})
        a.load()
        self.assertEqual(a.call(a.sym('AXFONT'), a=0x80, x=0x50), 'rts')
        self.assertEqual(a.flag_c(), 0)
        self.assertEqual(bytes(a.mem[0x8000:0x8400]), self.FONT)
        self.assertEqual(a.iocb, {})                     # closed
        self.assertEqual(a.mpu.x, 0x50)

    def test_missing(self):
        a = Atari(PROGRAM)
        a.load()
        self.assertEqual(a.call(a.sym('AXFONT'), a=0x80, x=0x50), 'rts')
        self.assertEqual(a.flag_c(), 1)
        self.assertEqual(a.mpu.y, 170)
        self.assertEqual(bytes(a.mem[0x8000:0x8400]), bytes(1024))
        self.assertEqual(a.iocb, {})

    def test_short(self):
        a = Atari(PROGRAM, {'AERA.FNT': self.FONT[:100]})
        a.load()
        a.call(a.sym('AXFONT'), a=0x80, x=0x10)
        self.assertEqual(a.flag_c(), 1)
        self.assertEqual(a.mpu.y, 136)
        self.assertEqual(a.iocb, {})


class TestErrors(unittest.TestCase):
    def text(self, a, code):
        a.call(a.sym('AXERRT'), y=code)
        if a.flag_c():
            return None
        p = a.mpu.a | a.mpu.y << 8
        out = bytearray()
        while a.mem[p + len(out)] != EOL:
            out.append(a.mem[p + len(out)])
        return out.decode('ascii')

    def test_texts(self):
        a = Atari(PROGRAM)
        a.load()
        self.assertEqual(self.text(a, 128), 'BREAK key')
        self.assertEqual(self.text(a, 136), 'End of file')
        self.assertEqual(self.text(a, 146), 'Function not supported')
        self.assertEqual(self.text(a, 170), 'File not found')
        self.assertEqual(self.text(a, 171), 'Invalid POINT')
        self.assertIsNone(self.text(a, 150))
        self.assertIsNone(self.text(a, 200))
        self.assertIsNone(self.text(a, 1))

    def test_every_code_once(self):
        a = Atari(PROGRAM)
        a.load()
        codes = list(range(128, 148)) + list(range(160, 172))
        for c in codes:
            self.assertTrue(self.text(a, c), c)

    def test_cio_group_only(self):
        a = Atari(Program(errs=1))
        a.load()
        self.assertEqual(self.text(a, 147), 'Not enough memory')
        self.assertIsNone(self.text(a, 170))


if __name__ == '__main__':
    unittest.main()
