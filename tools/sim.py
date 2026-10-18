#!/usr/bin/env python3
# EFTP_XL - run EFTPXL.COM on an emulated 6502 against a real FTP server
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Run the real EFTPXL.COM on xl's a8sim (xl/tools/a8sim: py65, with the
Atari OS calls stood in for) and EFTP_XL's FujiNet (tools/fujinet.py):

- the program is loaded segment by segment as DOS does (its load check
  first), then run from RUNAD;
- the keyboard: keys come from a script, through CH and K:'s get-byte;
  "\\h" is HELP, "\\!" RESET;
- the screen is read from screen memory (SAVMSC), and drawn as the Atari
  shows it, in the program's own font and colours;
- CIO: E: output is kept; D1:..D8: are folders on this machine, listed
  as SpartaDOS 3 (or DOS 2.5) lists them;
- SIO is a FujiNet: $70 answers Get Adapter Config, $71.. ($71 = N1:,
  $72 = N2:) open real TCP connections for N:TCP:// specs.

    sim.py [--d1 DIR] [--dos sparta|dos2] [--shots PREFIX] [--sio-log] KEYS

KEYS is what to type: "\\n" RETURN, "\\e" ESC, "\\t" TAB, "\\b" BACKSPACE,
"\\u" "\\d" up and down, "\\h" HELP, "\\!" RESET, "^X" Ctrl+X, "\\w" waits
until the program is idle (after a transfer), "\\z" lets one look at the
keyboard go by (a block of a transfer), and "\\s" takes a snapshot of the
screen (printed, and PREFIX-N.png with --shots). The run ends when the
program waits for a key and the script has none left.
"""
import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'xl', 'tools'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import a8sim  # noqa: E402
from a8sim import parse_keys, Stop  # noqa: E402,F401
from a8sim.core import CHBAS, DOSINI, DOSINI_TRAP, RAMTOP, RUNAD  # noqa: E402,F401
from fujinet import FujiNet  # noqa: E402,F401

# EFTP_XL's own characters, as screen_text shows them: the icons the same
# with AERA.FNT ($00 $10 $06 $7B) and with the ROM font ($7F, blank, $1F, $12)
GLYPHS = {0x12: '-', 0x7C: '|', 0x11: '+', 0x05: '+', 0x1A: '+', 0x03: '+',
          0x01: '+', 0x04: '+', 0x17: '+', 0x18: '+', 0x14: '*', 0x60: '#',
          0x1C: '^', 0x1D: 'v', 0x00: '[', 0x10: '.', 0x06: '~', 0x7B: ':',
          0x7F: '[', 0x1F: '~'}


def Disks(drives, dos='sparta'):
    """xl's host-folder disks, with the volume name the tests know"""
    return a8sim.Disks(drives, dos, volume='EFTPTEST')


class Sim:
    """EFTPXL.COM in a8sim, with the key script, D:, E: and the FujiNet"""

    def __init__(self, xex, keys, memlo=0x1D00, fujinet=None, disks=None, shots=None):
        self.m = a8sim.Machine(memlo=memlo, clock='wall')
        self.keys = a8sim.Keys(keys, on_shot=lambda m: self.snapshot())
        self.fujinet = fujinet or FujiNet()
        self.e = a8sim.E()
        self.m.cio = a8sim.CIO(e=self.e, d=disks or Disks({}))
        self.m.sio = a8sim.SIO({d: self.fujinet for d in FujiNet.DEVICES})
        self.xex = xex
        self.shots = shots
        self.nshot = 0

    # what the tests look at
    mem = property(lambda self: self.m.mem)
    to_dos = property(lambda self: self.m.to_dos)
    resets = property(lambda self: self.m.resets)
    eout = property(lambda self: bytes(self.e.out))

    def word(self, addr):
        return self.m.word(addr)

    def run(self):
        """load as DOS does, then run until the keys run out"""
        m = self.m
        try:
            if not m.load(self.xex):
                return              # the load check went back to DOS
            self.keys.install(m)    # after the load: it finds LDX CH
            if m.word(RUNAD):
                m.call(m.word(RUNAD))
        except Stop:
            pass

    def screen_text(self):
        return a8sim.screen_text(self.m, GLYPHS)

    def screen_png(self, path, scale=3):
        a8sim.screen_png(self.m, path, scale)

    def snapshot(self):
        self.nshot += 1
        print(f'--- screen {self.nshot} ---')
        print(self.screen_text())
        if self.shots:
            self.screen_png(f'{self.shots}-{self.nshot}.png')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('keys', help='keys to type (see above)')
    ap.add_argument('--com', '--xex', dest='xex', default=os.path.join(ROOT, 'bin', 'EFTPXL.COM'))
    ap.add_argument('--memlo', type=lambda v: int(v, 0), default=0x1D00)
    ap.add_argument('--d1', help='folder for D1:')
    ap.add_argument('--d2', help='folder for D2:')
    ap.add_argument('--dos', choices=('sparta', 'dos2'), default='sparta')
    ap.add_argument('--shots', help='PNG file prefix for snapshots')
    ap.add_argument('--sio-log', action='store_true', help='log SIO calls')
    args = ap.parse_args()

    drives = {n: d for n, d in ((1, args.d1), (2, args.d2)) if d}
    sim = Sim(args.xex, parse_keys(args.keys), args.memlo,
              FujiNet(log=args.sio_log), Disks(drives, args.dos), args.shots)
    sim.run()
    if sim.eout:
        print('--- E: ---')
        print(sim.eout.replace(b'\x9b', b'\n').decode('latin-1'))
    if sim.to_dos:
        print('--- back to DOS ---')
    else:
        sim.snapshot()


if __name__ == '__main__':
    main()
