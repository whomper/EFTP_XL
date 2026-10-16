#!/usr/bin/env python3
# EFTP_XL - run EFTPXL.XEX on an emulated 6502 against a real FTP server
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Run the real EFTPXL.XEX on py65 with the Atari OS calls it makes
stood in for, the way EDOS's tools/sim.py tests EDOS:

- The XEX is loaded segment by segment as DOS does, running INITAD
  chunks (cc65's memory check) and then RUNAD.
- The keyboard: keys come from a script, through CH and the OS
  keyboard handler as cgetc reads them; "\\h" is the HELP key.
- The screen is read from screen memory (SAVMSC), and drawn as the
  Atari shows it, in the program's own character set and colours.
- CIO: E: output is collected; D1:..D4: are folders on this machine,
  with directories listed the way SpartaDOS 3 (or DOS 2.5) lists them.
- SIO is a FujiNet: device $70 answers Get Adapter Config, devices
  $71.. ($71 = N1:, $72 = N2:) open real TCP connections for
  N:TCP:// specs and answer Open, Status, Read, Write and Close.

    sim.py [--d1 DIR] [--dos sparta|dos2] [--shots PREFIX] [--sio-log] KEYS

KEYS is what to type: "\\n" RETURN, "\\e" ESC, "\\t" TAB, "\\b" BACKSPACE,
"\\u" "\\d" up and down, "\\h" HELP, "^X" Ctrl+X, "\\w" waits until the
program is idle (after a transfer), "\\z" lets one look at the keyboard go
by (a block of a transfer), and "\\s" takes a snapshot of the screen (printed, and PREFIX-N.png with --shots). The run
ends when the program waits for a key and the script has none left.
"""
import argparse
import colorsys
import datetime
import fnmatch
import os
import socket
import sys
import time

from py65.devices.mpu6502 import MPU

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RTCLOK = 0x12
SAVMSC = 0x58
RAMTOP = 0x6A
DCB = 0x300
IOCB = 0x340
INITAD, RUNAD = 0x2E2, 0x2E0
MEMTOP, MEMLO = 0x2E5, 0x2E7
COLOR1, COLOR2, COLOR4 = 0x2C5, 0x2C6, 0x2C8
HELPFG, CHBAS, CH = 0x2DC, 0x2F4, 0x2FC
KEYBDV = 0xE420
SIOV, CIOV = 0xE459, 0xE456
KEY_TRAP = 0xE700           # KEYBDV's get-byte routine points here
DOS_TRAP = 0xE710           # DOSVEC: back to DOS ends the run
DOSVEC = 0x0A
RETURN_TRAP = 0xFFF0        # fake return address ending a call
SCREEN = 0xBC40

EOL = 0x9B
CLOCK_STEPS = 2000          # RTCLOK is set from the wall clock this often
HELP, SHOT, WAIT, SKIP = 'help', 'shot', 'wait', 'skip'
IDLE_GAP = 300             # polls this close together: waiting for a key


class Stop(Exception):
    pass


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


class Disks:
    """D1:..D4: as folders on this machine, through CIO."""

    def __init__(self, drives, dos='sparta'):
        self.drives = drives            # {1: '/path', ...}
        self.dos = dos
        self.open = {}                  # iocb -> dict(data, pos, write, path)

    def _resolve(self, spec):
        dev, _, rest = spec.partition(':')
        n = int(dev[1:]) if len(dev) > 1 else 1
        if n not in self.drives:
            return None, None
        parts = [p for p in rest.replace('\\', '>').split('>') if p]
        name = parts.pop() if parts and not rest.endswith('>') else ''
        return os.path.join(self.drives[n], *parts), name

    def _listing(self, folder, pattern, long=True):
        """the directory as DOS lists it: SpartaDOS's long form (bytes,
        <DIR>) only with aux2 $80; without it, as DOS 2 does, in sectors
        (256 bytes on SpartaDOS's double density) and no folders"""
        names = sorted(os.listdir(folder))
        lines = []
        sparta = self.dos == 'sparta' and long
        secsize = 256 if self.dos == 'sparta' else 125
        if sparta:
            lines += ['', 'Volume:    EFTPTEST', 'Directory: ' +
                      (os.path.basename(folder).upper() or 'MAIN'), '']
        for n in names:
            full = os.path.join(folder, n)
            base, _, ext = n.upper().partition('.')
            if not fnmatch.fnmatch(n.upper(), pattern.upper().replace('*.*', '*')):
                continue
            t = datetime.datetime.fromtimestamp(os.path.getmtime(full))
            when = t.strftime('%d-%m-%y %H:%M')
            if os.path.isdir(full):
                if sparta:
                    lines.append(f'{base[:8]:<8}     <DIR>  {when}')
                continue
            size = os.path.getsize(full)
            if sparta:
                lines.append(f'{base[:8]:<8} {ext[:3]:<3} {size:>7} {when}')
            else:
                lines.append(f'  {base[:8]:<8}{ext[:3]:<3} {(size + secsize - 1) // secsize:03d}')
        lines.append(' 1234 FREE SECTORS' if sparta else '609 FREE SECTORS')
        return ''.join(l + '\x9b' for l in lines).encode('latin-1')

    def cio(self, sim, x):
        m = sim.mem
        cmd = m[IOCB + x + 2]
        buf = m[IOCB + x + 4] | m[IOCB + x + 5] << 8
        n = m[IOCB + x + 8] | m[IOCB + x + 9] << 8
        aux1 = m[IOCB + x + 10]
        f = self.open.get(x)
        if cmd == 3:                                        # OPEN
            spec = bytes(m[buf:buf + n]).split(b'\x9b')[0].decode('latin-1')
            folder, name = self._resolve(spec)
            if folder is None:
                return 130                                  # no such device
            if aux1 == 6:
                if not os.path.isdir(folder):
                    return 150
                self.open[x] = dict(data=self._listing(folder, name or '*.*',
                                                       bool(m[IOCB + x + 11] & 0x80)),
                                    pos=0, write=False)
                return 1
            path = os.path.join(folder, name)
            if aux1 & 8:
                self.open[x] = dict(data=bytearray(), pos=0, write=True, path=path)
                return 1
            if not os.path.isfile(path):
                return 170
            self.open[x] = dict(data=open(path, 'rb').read(), pos=0, write=False)
            return 1
        if cmd in (42, 43):                                 # XIO MKDIR / RMDIR
            if self.dos != 'sparta':
                return 146                                  # not on DOS 2
            spec = bytes(m[buf:buf + n]).split(b'\x9b')[0].decode('latin-1')
            folder, name = self._resolve(spec)
            if folder is None:
                return 130
            path = os.path.join(folder, name)
            try:
                os.mkdir(path) if cmd == 42 else os.rmdir(path)
            except FileExistsError:
                return 151
            except OSError:
                return 167 if cmd == 43 and os.path.isdir(path) else 170
            return 1
        if cmd in (32, 33):                                 # XIO RENAME / DELETE
            spec = bytes(m[buf:buf + n]).split(b'\x9b')[0].decode('latin-1')
            folder, name = self._resolve(spec.split(',')[0])
            if folder is None:
                return 130
            path = os.path.join(folder, name)
            if not os.path.exists(path):
                return 170
            if cmd == 33:
                os.remove(path)
            else:
                os.rename(path, os.path.join(folder, spec.split(',')[1]))
            return 1
        if cmd == 12:                                       # CLOSE
            if f and f['write']:
                open(f['path'], 'wb').write(f['data'])
            self.open.pop(x, None)
            return 1
        if not f:
            return 133                                      # not open
        if cmd in (5, 7):                                   # GET RECORD / CHARS
            d, p = f['data'], f['pos']
            if p >= len(d):
                sim.poke_word(IOCB + x + 8, 0)
                return 136
            end = len(d) if cmd == 7 else (d.find(b'\x9b', p) + 1 or len(d))
            end = min(end, p + n)
            sim.poke(buf, d[p:end])
            sim.poke_word(IOCB + x + 8, end - p)
            f['pos'] = end
            return 1
        if cmd in (9, 11):                                  # PUT RECORD / CHARS
            d = bytes(m[buf:buf + n])
            if cmd == 9 and b'\x9b' in d:
                d = d[:d.index(b'\x9b') + 1]
            f['data'] += d
            return 1
        return 146                                          # not implemented


class Sim:
    def __init__(self, xex, keys, memlo=0x1F00, fujinet=None, disks=None,
                 shots=None):
        self.mem = bytearray(0x10000)
        self.mpu = MPU(memory=self.mem)
        self.keys = list(keys)
        self.fujinet = fujinet or FujiNet()
        self.disks = disks or Disks({})
        self.shots = shots
        self.nshot = 0
        self.eout = bytearray()
        self.steps = 0
        self.t0 = time.monotonic()
        self.polls = 0
        self.last_poll = 0

        self.poke(RAMTOP, [0xC0])
        self.poke_word(SAVMSC, SCREEN)
        self.poke_word(MEMTOP, 0xBC1F)
        self.poke_word(MEMLO, memlo)
        self.poke_word(KEYBDV + 4, KEY_TRAP - 1)
        self.poke_word(DOSVEC, DOS_TRAP)
        self.to_dos = False
        self.poke(COLOR1, [0xCA])
        self.poke(COLOR2, [0x94])
        self.poke(CHBAS, [0xE0])
        self.poke(CH, [0xFF])
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
        if x == 0:
            if self.mem[IOCB + 2] == 0x0B:                  # put to E:
                n = self.word(IOCB + 8)
                if n == 0:
                    self.eout.append(self.mpu.a)
                else:
                    a = self.word(IOCB + 4)
                    self.eout += self.mem[a:a + n]
            return 1
        st = self.disks.cio(self, x)
        self.mem[IOCB + x + 3] = st
        return st

    def _key(self):
        k = self.keys.pop(0)
        self.mem[CH] = 0xFF
        return k

    def _clock(self):
        """RTCLOK runs at 60 Hz of real time, as on an NTSC Atari, so the
        program's timeouts wait as long as they would there."""
        t = int((time.monotonic() - self.t0) * 60)
        self.poke(RTCLOK, [(t >> 16) & 255, (t >> 8) & 255, t & 255])

    def _trap(self):
        pc = self.mpu.pc
        self._clock()
        if pc == SIOV:
            y = self.fujinet.call(self)
            self.mem[DCB + 3] = y
            self._rts(y=y)
        elif pc == CIOV:
            self._rts(y=self._cio())
        elif pc == KEY_TRAP:
            self._rts(a=self._key(), y=1)
        elif pc == DOS_TRAP:
            self.to_dos = True
            raise Stop()
        else:
            raise RuntimeError(f'unhandled OS call at ${pc:04X}')

    def _keyboard(self):
        """Called when the program looks at CH (kbhit)."""
        idle = self.steps - self.last_poll < IDLE_GAP
        self.last_poll = self.steps
        while self.keys and self.keys[0] in (WAIT, SHOT, SKIP):
            if self.keys[0] == SKIP:
                self.keys.pop(0)
                return          # let one more poll (a block of a transfer) go by
            if self.keys[0] == WAIT:
                if not idle:
                    return          # busy (a transfer): hold the keys back
                self.keys.pop(0)
            else:
                self.keys.pop(0)
                self.snapshot()
        if self.keys and self.keys[0] == HELP:
            if not self.mem[HELPFG]:
                self.keys.pop(0)
                self.mem[HELPFG] = 0x11
            return
        if self.keys:
            self.mem[CH] = 0x0C if self.mem[CH] == 0xFF else self.mem[CH]
            self.polls = 0
            return
        self.polls = self.polls + 1 if idle else 0
        if self.polls > 200:
            raise Stop()

    # -- running
    def call(self, addr, max_steps=500_000_000):
        mpu, m = self.mpu, self.mem
        mpu.sp = 0xFF
        ret = RETURN_TRAP - 1
        m[0x1FF], m[0x1FE] = ret >> 8, ret & 255
        mpu.sp = 0xFD
        mpu.pc = addr
        for _ in range(max_steps):
            pc = mpu.pc
            if pc == RETURN_TRAP:
                return
            if pc >= 0xC000:
                self._trap()
                continue
            if m[pc] == 0xAE and m[pc + 1] == 0xFC and m[pc + 2] == 0x02:
                self._keyboard()                            # LDX CH
            mpu.step()
            self.steps += 1
            if self.steps % CLOCK_STEPS == 0:
                self._clock()
        raise RuntimeError(f'no return from ${addr:04X} (pc=${mpu.pc:04X})')

    def run(self):
        """Load the XEX as DOS does, then run it until the keys run out."""
        d, i = self.xex, 0
        self.poke_word(RUNAD, 0)
        try:
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
        except Stop:
            pass

    # -- the screen
    def screen_text(self):
        base = self.word(SAVMSC)
        rows = []
        for r in range(24):
            row = ''
            for c in range(40):
                ch = self.mem[base + r * 40 + c] & 0x7F
                a = ch + 0x20 if ch < 0x40 else ch - 0x40 if ch < 0x60 else ch
                row += chr(a) if 0x20 <= a < 0x7B else {
                    0x12: '-', 0x7C: '|', 0x11: '+', 0x05: '+', 0x1A: '+',
                    0x03: '+', 0x01: '+', 0x04: '+', 0x17: '+', 0x18: '+',
                    0x14: '*', 0x60: '#', 0x1C: '^', 0x1D: 'v', 0x00: '[',
                    0x10: '.', 0x06: '~', 0x7B: ':'}.get(a, '?')
            rows.append(row.rstrip())
        return '\n'.join(rows)

    def screen_png(self, path, scale=3):
        from PIL import Image
        font = self.mem[self.mem[CHBAS] << 8:(self.mem[CHBAS] << 8) + 1024]
        bg_c = self.mem[COLOR2]
        bg = atari_rgb(bg_c)
        fg = atari_rgb((bg_c & 0xF0) | (self.mem[COLOR1] & 0x0F))
        border = atari_rgb(self.mem[COLOR4])
        bx, by = 16, 12
        w, h = 40 * 8 + 2 * bx, 24 * 8 + 2 * by
        img = Image.new('RGB', (w, h), border)
        px = img.load()
        base = self.word(SAVMSC)
        for r in range(24):
            for c in range(40):
                ch = self.mem[base + r * 40 + c]
                for y in range(8):
                    bits = font[(ch & 0x7F) * 8 + y]
                    for x in range(8):
                        on = bool(bits & (0x80 >> x)) ^ bool(ch & 0x80)
                        px[bx + c * 8 + x, by + r * 8 + y] = fg if on else bg
        img.resize((w * scale, h * scale), Image.NEAREST).save(path)

    def snapshot(self):
        self.nshot += 1
        print(f'--- screen {self.nshot} ---')
        print(self.screen_text())
        if self.shots:
            self.screen_png(f'{self.shots}-{self.nshot}.png')


def atari_rgb(colour):
    """approximate NTSC palette entry (as EDOS's tools/screenshot.py)"""
    hue, lum = colour >> 4, (colour & 0x0F) / 15
    if hue == 0:
        v = int(lum * 255)
        return (v, v, v)
    angle = (45 - (hue - 1) * 24) % 360
    r, g, b = colorsys.hls_to_rgb(angle / 360, 0.10 + lum * 0.75, 0.70)
    return (int(r * 255), int(g * 255), int(b * 255))


def parse_keys(s):
    out, i = [], 0
    named = {'n': 0x9B, 'e': 0x1B, 't': 0x7F, 'b': 0x7E, 'u': 0x1C,
             'd': 0x1D, 'l': 0x1E, 'r': 0x1F, 'x': 0x9C}
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s):
            k = s[i + 1]
            out.append(HELP if k == 'h' else SHOT if k == 's' else WAIT if k == 'w'
                       else SKIP if k == 'z' else named.get(k, ord(k)))
            i += 2
        elif c == '^' and i + 1 < len(s):
            out.append(ord(s[i + 1].upper()) & 0x1F)
            i += 2
        else:
            out.append(ord(c))
            i += 1
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('keys', help='keys to type (see above)')
    ap.add_argument('--xex', default=os.path.join(ROOT, 'bin', 'EFTPXL.XEX'))
    ap.add_argument('--memlo', type=lambda v: int(v, 0), default=0x1F00)
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
        print(bytes(sim.eout).replace(b'\x9b', b'\n').decode('latin-1'))
    if sim.to_dos:
        print('--- back to DOS ---')
    else:
        sim.snapshot()


if __name__ == '__main__':
    main()
