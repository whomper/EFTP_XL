# AERA-Atari xl/tools/mac65real - from EDOS (tools/run65), as EDOS sent it
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Atari OS floating point (6-byte BCD) for the entry points MAC/65 uses."""
from decimal import Decimal, getcontext
getcontext().prec = 30
FR0, FR1, CIX, INBUFF, LBUFF, FLPTR = 0xD4, 0xE0, 0xF2, 0xF3, 0x580, 0xFC
ENTRY = {0xD800: 'AFP', 0xD8E6: 'FASC', 0xD9AA: 'IFP', 0xD9D2: 'FPI', 0xDA44: 'ZFR0',
         0xDA46: 'ZF1', 0xDBA1: 'SKPSPC', 0xDBAF: 'ISDIGT', 0xDA51: 'LDBUFA', 0xDA60: 'FSUB', 0xDA66: 'FADD', 0xDADB: 'FMUL',
         0xDB28: 'FDIV', 0xDD89: 'FLD0R', 0xDD8D: 'FLD0P', 0xDD98: 'FLD1R', 0xDD9C: 'FLD1P',
         0xDDA7: 'FST0R', 0xDDAB: 'FST0P', 0xDDB6: 'FMOVE'}


def encode(v):
    v = Decimal(v)
    if v == 0:
        return bytes(6)
    neg = v < 0; v = abs(v)
    e = 0
    while v >= 100: v /= 100; e += 1
    while v < 1: v *= 100; e -= 1
    digits = int((v * Decimal(10) ** 8).to_integral_value())
    if digits >= 10 ** 10:
        digits //= 100; e += 1
    s = f'{digits:010d}'
    mant = bytes(int(s[i]) << 4 | int(s[i + 1]) for i in range(0, 10, 2))
    return bytes([(e + 64) | (0x80 if neg else 0)]) + mant


def decode(b):
    if b[0] & 0x7F == 0 and not any(b[1:]):
        return Decimal(0)
    digits = int(''.join(f'{x >> 4}{x & 15}' for x in b[1:6]))
    e = (b[0] & 0x7F) - 64
    v = Decimal(digits) / Decimal(10) ** 8 * Decimal(100) ** e
    return -v if b[0] & 0x80 else v


def fmt(v):
    if v == v.to_integral_value() and abs(v) < Decimal(10) ** 10:
        return str(int(v))
    s = format(v.normalize(), 'f')
    return s


class FP:
    def __init__(self, atari):
        self.a = atari
    def rd(self, addr, n=6):
        return bytes(self.a.m[addr + i] for i in range(n))
    def wr(self, addr, data):
        for i, c in enumerate(data): self.a.m[addr + i] = c
    def setnz(self, v):
        c = self.a.cpu
        c.p &= ~(c.NEGATIVE | c.ZERO)
        if v & 0x80: c.p |= c.NEGATIVE
        if v == 0: c.p |= c.ZERO
    def call(self, name):
        a, m, c = self.a, self.a.m, self.a.cpu
        carry = False
        if name == 'IFP':
            self.wr(FR0, encode(m[FR0] | m[FR0 + 1] << 8))
        elif name == 'FPI':
            v = decode(self.rd(FR0)).to_integral_value()
            if v < 0 or v > 65535: carry = True
            else: self.wr(FR0, bytes([int(v) & 0xFF, int(v) >> 8]))
        elif name == 'ZFR0':
            self.wr(FR0, bytes(6))
        elif name == 'ZF1':
            self.wr(c.x, bytes(6))
        elif name == 'LDBUFA':
            m[INBUFF], m[INBUFF + 1] = LBUFF & 0xFF, LBUFF >> 8
        elif name == 'AFP':
            p = m[INBUFF] | m[INBUFF + 1] << 8
            i = m[CIX]
            while chr(m[p + i]) == ' ': i += 1
            s = ''; j = i
            if chr(m[p + j]) in '+-': s += chr(m[p + j]); j += 1
            nd = 0
            while chr(m[p + j]).isdigit(): s += chr(m[p + j]); j += 1; nd += 1
            if chr(m[p + j]) == '.':
                s += '.'; j += 1
                while chr(m[p + j]).isdigit(): s += chr(m[p + j]); j += 1; nd += 1
            if nd == 0:
                carry = True
            else:
                if chr(m[p + j]) == 'E':
                    k = j + 1; es = ''
                    if chr(m[p + k]) in '+-': es += chr(m[p + k]); k += 1
                    while chr(m[p + k]).isdigit(): es += chr(m[p + k]); k += 1
                    if es.strip('+-'): s += 'E' + es; j = k
                self.wr(FR0, encode(Decimal(s)))
                m[CIX] = j
        elif name == 'FASC':
            t = fmt(decode(self.rd(FR0))).encode()
            t = t[:-1] + bytes([t[-1] | 0x80])
            self.wr(LBUFF, t)
            m[INBUFF], m[INBUFF + 1] = LBUFF & 0xFF, LBUFF >> 8
        elif name in ('FADD', 'FSUB', 'FMUL', 'FDIV'):
            x, y = decode(self.rd(FR0)), decode(self.rd(FR1))
            try:
                r = {'FADD': x + y, 'FSUB': x - y, 'FMUL': x * y, 'FDIV': x / y}[name]
                self.wr(FR0, encode(r))
            except Exception:
                carry = True
        elif name in ('FLD0R', 'FLD1R', 'FST0R'):
            addr = c.x | c.y << 8
            if name == 'FST0R': self.wr(addr, self.rd(FR0))
            else: self.wr(FR0 if name == 'FLD0R' else FR1, self.rd(addr))
        elif name in ('FLD0P', 'FLD1P', 'FST0P'):
            addr = m[FLPTR] | m[FLPTR + 1] << 8
            if name == 'FST0P': self.wr(addr, self.rd(FR0))
            else: self.wr(FR0 if name == 'FLD0P' else FR1, self.rd(addr))
        elif name == 'SKPSPC':
            p = m[INBUFF] | m[INBUFF + 1] << 8
            y = m[CIX]
            while m[p + y] == 0x20 and y < 255: y += 1
            m[CIX] = y; c.y = y; c.a = 0x20
            carry = m[p + y] <= 0x20
            self.setnz(1)
            if carry: c.p |= c.CARRY
            else: c.p &= ~c.CARRY
            return
        elif name == 'ISDIGT':
            p = m[INBUFF] | m[INBUFF + 1] << 8
            y = m[CIX]; c.y = y
            v = m[p + y] - 0x30
            if v < 0: carry = True; c.a = v & 0xFF
            else: c.a = v; carry = v >= 10
            self.setnz(c.a)
        elif name == 'FMOVE':
            self.wr(FR1, self.rd(FR0))
        if carry: c.p |= c.CARRY
        else: c.p &= ~c.CARRY
