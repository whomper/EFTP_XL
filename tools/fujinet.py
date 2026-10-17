#!/usr/bin/env python3
# EFTP_XL - a FujiNet for xl's a8sim, over real sockets
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""SIO devices $70 (the FujiNet: Get Adapter Config) and $71-$78 (N1:-N8:)
for xl/tools/a8sim: N:TCP://host:port specs open real TCP connections, and
Open, Status, Read, Write and Close work on them. Each command takes only
the frame length a real FujiNet reads, as the 257-byte N2: open showed.

    m.sio = SIO({dev: fujinet for dev in range(0x70, 0x79)})
"""
import os
import socket
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                'xl', 'tools'))
from a8sim import strict_length  # noqa: E402


class FujiNet:
    """conn: {unit: dict(sock, rx, eof)}; log prints each command"""

    DEVICES = range(0x70, 0x79)

    def __init__(self, version='1.3.0 (sim)', log=False):
        self.version = version
        self.log = log
        self.conn = {}

    def _say(self, msg):
        if self.log:
            print(f'  [SIO {msg}]', file=sys.stderr)

    def call(self, m, d):
        dev, cmd, buf, size = d['dev'], d['cmd'], d['buf'], d['size']
        n = d['aux1'] | d['aux2'] << 8
        if dev == 0x70 and cmd == 0xE8:
            return self._adapter_config(m, buf, size)
        if 0x71 <= dev <= 0x78:
            unit = dev - 0x70
            want = {0x4F: 256, 0x53: 4, 0x52: n, 0x57: n}.get(cmd)
            bad = strict_length(size, want)
            if bad:
                self._say(f'N{unit}: command ${cmd:02X} with {size} bytes, not {want}')
                return bad
            if cmd == 0x4F:
                return self._open(m, unit, buf, size)
            if cmd == 0x53:
                return self._status(m, unit, buf)
            if cmd == 0x52:
                return self._read(m, unit, buf, n)
            if cmd == 0x57:
                return self._write(m, unit, buf, n)
            if cmd == 0x43:
                return self._close(unit)
        self._say(f'device ${dev:02X} command ${cmd:02X}: not emulated')
        return 138      # timeout, as when no device answers

    def _adapter_config(self, m, buf, size):
        cfg = bytearray(size)
        cfg[0:6] = b'SIMNET'                        # ssid[33]
        cfg[33:39] = b'SIMHOST'                     # hostname[64]
        cfg[97:101] = bytes([127, 0, 0, 1])         # localIP
        v = self.version.encode()[:14]
        cfg[size - 15:size - 15 + len(v)] = v       # fn_version[15]
        m.poke(buf, cfg)
        return 1

    def _open(self, m, unit, buf, size):
        spec = bytes(m.mem[buf + i] for i in range(size)).split(b'\0')[0].decode()
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

    def _status(self, m, unit, buf):
        c = self.conn.get(unit)
        if c:
            self._pump(c)
            avail = min(len(c['rx']), 65535)
            connected = 0 if c['eof'] else 1
        else:
            avail, connected = 0, 0
        err = 1 if connected else 136
        m.poke(buf, bytes([avail & 255, avail >> 8, connected, err]))
        return 1

    def _read(self, m, unit, buf, n):
        c = self.conn.get(unit)
        if not c or len(c['rx']) < n:
            return 136
        m.poke(buf, c['rx'][:n])
        del c['rx'][:n]
        return 1

    def _write(self, m, unit, buf, n):
        c = self.conn.get(unit)
        if not c:
            return 133      # not open
        data = bytes(m.mem[buf + i] for i in range(n))
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
