#!/usr/bin/env python3
# EFTP_XL - run EFTPXL.XEX on an emulated 6502 against a real FTP server
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Run the real EFTPXL.XEX on py65 with the Atari OS calls it makes
stood in for, the way EDOS's tools/sim.py tests EDOS:

- The XEX is loaded segment by segment as DOS does, running INITAD
  chunks (cc65's memory check) and then RUNAD.
- CIO on IOCB 0 (E:) is the screen: output is collected as text.
- The OS keyboard handler (KEYBDV get) takes keys from a script.
- SIO is a FujiNet: device $70 answers Get Adapter Config, devices
  $71.. ($71 = N1:, $72 = N2:) open real TCP connections for
  N:TCP:// specs and answer Open, Status, Read, Write and Close.

So the program's own FTP client talks to a real server through the
same SIO calls it makes on an Atari.

    sim.py [--xex bin/EFTPXL.XEX] [--memlo 0x1F00] [--sio-log] KEYS

KEYS is what to type; "\\n" is RETURN, "\\e" is ESC. For example
    sim.py '127.0.0.1\\n21\\nATARI\\nSECRET\\n/\\n\\e'
prints the screen output, ATASCII turned into text.
"""
import argparse
import os
import socket
import sys

from py65.devices.mpu6502 import MPU

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RTCLOK = 0x12
SAVMSC = 0x58
RAMTOP = 0x6A
DCB = 0x300
IOCB = 0x340
INITAD, RUNAD = 0x2E2, 0x2E0
MEMTOP, MEMLO = 0x2E5, 0x2E7
KEYBDV = 0xE420
SIOV, CIOV = 0xE459, 0xE456
KEY_TRAP = 0xE700           # KEYBDV's get-byte routine points here
RETURN_TRAP = 0xFFF0        # fake return address ending a call

EOL, ESC = 0x9B, 0x1B
STEPS_PER_TICK = 10000      # RTCLOK advances every this many instructions


class FujiNet:
    """SIO devices $70 (FujiNet) and $71.. (N1:..) over real sockets."""

    def __init__(self, version='1.3.0 (sim)', log=False):
        self.version = version
        self.log = log
        self.conn = {}          # unit -> dict(sock, rx, eof)

    def _say(self, msg):
        if self.log:
            print(f'  [SIO {msg}]', file=sys.stderr)

    def call(self, sim):
        m = sim.mem
        dev, cmd = m[DCB], m[DCB + 2]
        buf = m[DCB + 4] | m[DCB + 5] << 8
        size = m[DCB + 8] | m[DCB + 9] << 8
        aux1, aux2 = m[DCB + 10], m[DCB + 11]

        if dev == 0x70 and cmd == 0xE8:
            return self._adapter_config(sim, buf, size)
        if 0x71 <= dev <= 0x78:
            unit = dev - 0x70
            if cmd == 0x4F:
                return self._open(sim, unit, buf, size)
            if cmd == 0x53:
                return self._status(sim, unit, buf)
            if cmd == 0x52:
                return self._read(sim, unit, buf, aux1 | aux2 << 8)
            if cmd == 0x57:
                return self._write(sim, unit, buf, aux1 | aux2 << 8)
            if cmd == 0x43:
                return self._close(unit)
        self._say(f'device ${dev:02X} command ${cmd:02X}: not emulated')
        return 138      # timeout, as when no device answers

    def _adapter_config(self, sim, buf, size):
        cfg = bytearray(size)
        cfg[0:6] = b'SIMNET'                        # ssid[33]
        cfg[33:39] = b'SIMHOST'                     # hostname[64]
        cfg[97:101] = bytes([127, 0, 0, 1])         # localIP
        v = self.version.encode()[:14]
        cfg[size - 15:size - 15 + len(v)] = v       # fn_version[15]
        sim.poke(buf, cfg)
        return 1

    def _open(self, sim, unit, buf, size):
        spec = bytes(sim.mem[buf + i] for i in range(size)).split(b'\0')[0].decode()
        self._close(unit)
        rest = spec.split(':', 1)[1]
        if not rest.upper().startswith('TCP://'):
            self._say(f'N{unit}: open {spec}: only TCP is emulated')
            return 165
        host, port = rest[6:].rstrip('/').rsplit(':', 1)
        try:
            s = socket.create_connection((host, int(port)), timeout=5)
        except OSError as e:
            self._say(f'N{unit}: open {host}:{port} failed: {e}')
            return 200
        s.setblocking(False)
        self.conn[unit] = dict(sock=s, rx=bytearray(), eof=False)
        self._say(f'N{unit}: open TCP {host}:{port}')
        return 1

    def _pump(self, c):
        while not c['eof']:
            try:
                d = c['sock'].recv(4096)
            except BlockingIOError:
                return
            except OSError:
                d = b''
            if not d:
                c['eof'] = True
            c['rx'] += d

    def _status(self, sim, unit, buf):
        c = self.conn.get(unit)
        if c:
            self._pump(c)
            avail = min(len(c['rx']), 65535)
            connected = 0 if c['eof'] else 1
        else:
            avail, connected = 0, 0
        err = 1 if connected else 136
        sim.poke(buf, bytes([avail & 255, avail >> 8, connected, err]))
        return 1

    def _read(self, sim, unit, buf, n):
        c = self.conn.get(unit)
        if not c or len(c['rx']) < n:
            return 136
        sim.poke(buf, c['rx'][:n])
        del c['rx'][:n]
        return 1

    def _write(self, sim, unit, buf, n):
        c = self.conn.get(unit)
        if not c:
            return 133      # not open
        data = bytes(sim.mem[buf + i] for i in range(n))
        shown = 'PASS ****' if data.startswith(b'PASS') else data.decode('latin-1').strip()
        self._say(f'N{unit}: send {shown}')
        c['sock'].setblocking(True)
        c['sock'].sendall(data)
        c['sock'].setblocking(False)
        return 1

    def _close(self, unit):
        c = self.conn.pop(unit, None)
        if c:
            c['sock'].close()
            self._say(f'N{unit}: close')
        return 1


class Sim:
    def __init__(self, xex, keys=b'', memlo=0x1F00, fujinet=None):
        self.mem = bytearray(0x10000)
        self.mpu = MPU(memory=self.mem)
        self.keys = bytearray(keys)
        self.fujinet = fujinet or FujiNet()
        self.screen = bytearray()
        self.steps = 0

        self.poke(RAMTOP, [0xC0])
        self.poke(SAVMSC, [0x40, 0xBC])
        self.poke_word(MEMTOP, 0xBC1F)
        self.poke_word(MEMLO, memlo)
        self.poke_word(KEYBDV + 4, KEY_TRAP - 1)
        self.xex = open(xex, 'rb').read()

    def poke(self, addr, data):
        for i, v in enumerate(data):
            self.mem[addr + i] = v

    def poke_word(self, addr, v):
        self.poke(addr, [v & 255, v >> 8])

    def word(self, addr):
        return self.mem[addr] | self.mem[addr + 1] << 8

    # -- OS stand-ins
    def _rts(self, a=None, y=None):
        mpu = self.mpu
        lo = self.mem[0x100 + ((mpu.sp + 1) & 255)]
        hi = self.mem[0x100 + ((mpu.sp + 2) & 255)]
        mpu.sp = (mpu.sp + 2) & 255
        mpu.pc = ((hi << 8) | lo) + 1
        if a is not None:
            mpu.a = a & 255
        if y is not None:
            mpu.y = y & 255
            mpu.p &= ~(mpu.NEGATIVE | mpu.ZERO)
            mpu.p |= (mpu.NEGATIVE if y & 0x80 else 0) | (mpu.ZERO if y == 0 else 0)

    def _cio(self):
        x = self.mpu.x
        cmd = self.mem[IOCB + x + 2]
        if cmd == 0x0B and x == 0:                      # put to E:
            n = self.word(IOCB + x + 8)
            if n == 0:
                self.screen.append(self.mpu.a)
            else:
                a = self.word(IOCB + x + 4)
                self.screen += self.mem[a:a + n]
                self.poke_word(IOCB + x + 8, n)
        return 1

    def _key(self):
        if not self.keys:
            raise RuntimeError('program waits for a key; the script has none left')
        return self.keys.pop(0)

    def _trap(self):
        pc = self.mpu.pc
        if pc == SIOV:
            y = self.fujinet.call(self)
            self.mem[DCB + 3] = y
            self._rts(y=y)
        elif pc == CIOV:
            self._rts(y=self._cio())
        elif pc == KEY_TRAP:
            self._rts(a=self._key(), y=1)
        else:
            raise RuntimeError(f'unhandled OS call at ${pc:04X}')

    # -- running
    def call(self, addr, max_steps=200_000_000):
        mpu = self.mpu
        mpu.sp = 0xFF
        ret = RETURN_TRAP - 1
        mpu.memory[0x1FF], mpu.memory[0x1FE] = ret >> 8, ret & 255
        mpu.sp = 0xFD
        mpu.pc = addr
        for _ in range(max_steps):
            if mpu.pc == RETURN_TRAP:
                return
            if mpu.pc >= 0xC000:
                self._trap()
                continue
            mpu.step()
            self.steps += 1
            if self.steps % STEPS_PER_TICK == 0:
                t = (self.mem[RTCLOK] << 16 | self.mem[RTCLOK + 1] << 8
                     | self.mem[RTCLOK + 2]) + 1
                self.poke(RTCLOK, [(t >> 16) & 255, (t >> 8) & 255, t & 255])
        raise RuntimeError(f'no return from ${addr:04X} (pc=${mpu.pc:04X})')

    def run(self):
        """Load the XEX as DOS does, then run it."""
        d, i = self.xex, 0
        self.poke_word(RUNAD, 0)
        while i < len(d):
            if d[i:i + 2] == b'\xff\xff':
                i += 2
            start, end = d[i] | d[i + 1] << 8, d[i + 2] | d[i + 3] << 8
            i += 4
            self.poke_word(INITAD, 0)
            self.poke(start, d[i:i + end - start + 1])
            i += end - start + 1
            if self.word(INITAD):
                self.call(self.word(INITAD))
        self.call(self.word(RUNAD))

    def text(self):
        out = []
        for b in self.screen:
            if b == EOL:
                out.append('\n')
            elif b == 0x7D:
                out.append('[CLEAR]\n')
            elif b == 0x7E:
                if out and out[-1] != '\n':
                    out.pop()
            elif 0x20 <= b < 0x7B:
                out.append(chr(b))
        return ''.join(out)


def keys_from(arg):
    return arg.replace('\\n', '\x9b').replace('\\e', '\x1b').encode('latin-1')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('keys', help='keys to type ("\\n" RETURN, "\\e" ESC)')
    ap.add_argument('--xex', default=os.path.join(ROOT, 'bin', 'EFTPXL.XEX'))
    ap.add_argument('--memlo', type=lambda v: int(v, 0), default=0x1F00)
    ap.add_argument('--sio-log', action='store_true', help='log SIO calls')
    args = ap.parse_args()

    sim = Sim(args.xex, keys_from(args.keys), args.memlo,
              FujiNet(log=args.sio_log))
    try:
        sim.run()
    finally:
        print(sim.text())


if __name__ == '__main__':
    main()
