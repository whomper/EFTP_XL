#!/usr/bin/env python3
# AERA-Atari xl/tests - a8sim, the shared 6502 simulator
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""xl/tools/a8sim with SIMTEST.M65 (built by mac65.py): E:, K:, a D: file,
both directory listings, a CIO error's text, RESET through AXRESET and
the load check; calls by symbol; the 130XE's banks; SIO's dispatch.

    python3 xl/tests/test_sim.py
"""
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
XL = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(XL, 'tools'))
import mac65  # noqa: E402
from a8sim import (Machine, CIO, E, K, Disks, SIO, Keys, Stop, parse_keys,  # noqa: E402
                   screen_text, strict_length, install_fp)


def build():
    tmp = tempfile.mkdtemp()
    for f in os.listdir(os.path.join(XL, 'src')):
        shutil.copy(os.path.join(XL, 'src', f), tmp)
    shutil.copy(os.path.join(HERE, 'SIMTEST.M65'), tmp)
    asm = mac65.Assembler()
    asm.assemble(os.path.join(tmp, 'SIMTEST.M65'))
    data, _ = asm.binary()
    prg = os.path.join(tmp, 'SIMTEST.PRG')
    with open(prg, 'wb') as f:
        f.write(data)
    sym = os.path.join(tmp, 'SIMTEST.SYM')
    with open(sym, 'w') as f:
        for k, v in sorted(asm.syms.items()):
            f.write(f'{k} ${v:04X}\n')
    return tmp, prg, sym


class TestSimTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp, cls.prg, cls.sym = build()
        cls.disk = os.path.join(cls.tmp, 'disk')
        os.mkdir(cls.disk)
        with open(os.path.join(cls.disk, 'HELLO.TXT'), 'wb') as f:
            f.write(b'HELLO FROM D1:\x9bMORE\x9b')

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp)

    def run_it(self, keys, dos='sparta', memlo=0x1F00):
        m = Machine(memlo=memlo, clock='steps')
        k = Keys(parse_keys(keys))
        e = E()
        m.cio = CIO(e=e, k=K(k), d=Disks({1: self.disk}, dos=dos))
        k.install(m, scan=False)
        if m.load(self.prg):
            k.watch_ch(m)                   # the program's LDX CH, now it is in
            try:
                m.call(m.word(0x2E0), max_steps=5_000_000)
            except Stop:
                pass
        return m, e.text().split('\n')

    def test_the_run(self):
        m, out = self.run_it('A')
        self.assertEqual(out[:3], ['HI', 'KEY A', 'HELLO FROM D1:'])
        self.assertEqual(out[3:5], ['', 'Volume:    AERATEST'])   # SpartaDOS's long listing
        self.assertEqual(out[5], 'File not found')
        self.assertFalse(m.to_dos)                               # it waits: no keys left
        self.assertEqual(m.cio.open.keys(), {0})                 # all closed but E:

    def test_dos2_listing(self):
        m, out = self.run_it('A', dos='dos2')
        self.assertEqual(out[3:5], ['  HELLO   TXT 001', '609 FREE SECTORS'])

    def test_reset(self):
        m, out = self.run_it('A\\!')
        self.assertEqual(out[-2], 'WARM')                        # AXWARM, after DOS's init
        self.assertTrue(m.to_dos)
        self.assertEqual(m.resets, 1)

    def test_load_check(self):
        m, out = self.run_it('A', memlo=0x3100)
        self.assertEqual(out[0], 'SIMTEST: DOS too big')
        self.assertTrue(m.to_dos)

    def test_call_by_symbol(self):
        m = Machine(clock='steps')
        m.load(self.prg, init=False)
        m.load_symbols(self.sym)
        mpu = m.call('AXERRT', y=170)
        self.assertFalse(mpu.p & 1)
        p = mpu.a | mpu.y << 8
        self.assertEqual(bytes(m.mem[p:p + 14]), b'File not found')

    def test_name_ends_at_eol_not_icbll(self):
        m, out = self.run_it('A')                                # STOPEN leaves ICBLL as it was
        self.assertIn('HELLO FROM D1:', out)


class TestParts(unittest.TestCase):
    def test_banks(self):
        m = Machine(banks=0x6C)
        m.poke(0x4000, [1])
        m.poke(0xD301, [0xE3])          # bank 0 at $4000
        self.assertEqual(m.peek(0x4000), 0)
        m.poke(0x4000, [2])
        m.poke(0xD301, [0xE7])          # bank 1
        m.poke(0x4000, [3])
        m.poke(0xD301, [0xE3])
        self.assertEqual(m.peek(0x4000), 2)
        m.poke(0xD301, [0xFF])          # main memory again
        self.assertEqual(m.peek(0x4000), 1)

    def test_sio(self):
        m = Machine()
        seen = []
        m.sio = SIO({0x31: lambda m, d: seen.append(d['sector']) or 1})
        m.poke(0x300, [0x31, 1, 0x52, 0, 0, 0x40, 7, 0, 128, 0, 0x68, 1])
        m.poke(0x2000, [0x20, 0x59, 0xE4, 0x60])          # JSR SIOV, RTS
        mpu = m.call(0x2000)
        self.assertEqual((seen, mpu.y), ([0x168], 1))
        m.poke(0x300, [0x71])
        self.assertEqual(m.call(0x2000).y, 138)           # nobody there
        self.assertEqual(strict_length(257, 256), 143)
        self.assertIsNone(strict_length(256, 256))

    def test_fp(self):
        m = Machine()
        install_fp(m)
        m.poke(0xD4, [0x39, 0x30])                        # 12345
        m.poke(0x2000, [0x20, 0xAA, 0xD9, 0x20, 0xE6, 0xD8, 0x60])   # IFP, FASC
        m.call(0x2000)
        self.assertEqual(bytes(m.mem[0x580:0x585]), b'1234\xb5')

    def test_status_flags(self):
        # an error comes back with N set, as programs test it (BMI)
        m = Machine()
        m.cio = CIO(e=E())
        m.poke(0x2100, b'Z:\x9b')
        m.poke(0x2000, [0xA2, 0x10, 0xA9, 0x03, 0x9D, 0x42, 0x03, 0xA9, 0x00, 0x9D, 0x44, 0x03,
                        0xA9, 0x21, 0x9D, 0x45, 0x03, 0x20, 0x56, 0xE4,      # OPEN #1,"Z:"
                        0x30, 0x03, 0xA9, 0x00, 0x60, 0xA9, 0x01, 0x60])     # BMI: A=1
        mpu = m.call(0x2000)
        self.assertEqual((mpu.y, mpu.a, mpu.x), (130, 1, 0x10))
        self.assertEqual(m.peek(0x353), 130)                # ICSTA too

    def test_keys(self):
        self.assertEqual(parse_keys('^K\\nA\\s\\!'), [11, 0x9B, 65, 'shot', 'reset'])

    def test_screen_text(self):
        m = Machine()
        base = m.word(0x58)
        m.poke(base, [0x28, 0x29, 0x52, 0x40])             # "HI", ^R (a line), ^@
        self.assertEqual(screen_text(m, {0x12: '-'}).split('\n')[0], 'HI-?')


if __name__ == '__main__':
    unittest.main()
