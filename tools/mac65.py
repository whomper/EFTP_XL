#!/usr/bin/env python3
# AERA-Atari xl/tools - MAC/65 cross assembler (from EDOS's tools/mac65.py)
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""MAC/65-compatible cross assembler for the AERA 8-bit sources.

Assembles MAC/65 sources as text, with or without line numbers (git keeps
them without; the disk gets them numbered, xl/tools/atari_src.py), into an
Atari DOS binary load file, byte for byte what MAC/65 1.01 makes. It covers
the subset of MAC/65 that EDOS and EFTP_XL use:

  * line numbers (optional, per file), labels in column 1, ';' comments
    (and '*' in column 1)
  * all NMOS 6502 opcodes and addressing modes, 'A' accumulator form
  * label = expr, *= expr, label *= *+n (reserve), .BYTE, .WORD, .OPT
  * .INCLUDE #D:FILE (resolved next to the including file; only in the
    main file, as MAC/65 has no nested includes)
  * .MACRO/.ENDM with %0 (argument count) and %1..%9, macro-local labels
  * .IF/.ELSE/.ENDIF, .ERROR "text" (fails the build)
  * expressions: $hex, decimal, 'c, symbols, * (PC), + - * / & ! ^,
    comparisons = <> < > <= >=, unary - and leading < (low) / > (high),
    [ ] grouping

Text files may hold ATASCII bytes $80-$FF (and control codes) as Unicode
private-use characters U+E000+byte, which is how the repository stores the
inverse-video strings.

Zero-page addressing is chosen when the operand's value is below $100 and
every symbol in it is already defined at that point of the current pass.
MAC/65 sizes such an operand as absolute in pass 1 and as zero page in
pass 2, so its labels move: a zero-page symbol used before it is defined is
an error here too, as is a symbol in .IF that is not yet defined (MAC/65
decides .IF in pass 1). Any address that moves between passes is reported
as a phase error.

Usage: mac65.py SOURCE.M65 -o OUT.COM [-l LISTING.LST] [-s SYMBOLS.TXT]
"""
import argparse
import os
import re
import sys

# ---------------------------------------------------------------- opcodes
# mode keys: imp acc imm zp zpx zpy abs absx absy ind indx indy rel
OPS = {}
def _op(name, **modes):
    OPS[name] = modes
_op('ADC', imm=0x69, zp=0x65, zpx=0x75, abs=0x6D, absx=0x7D, absy=0x79, indx=0x61, indy=0x71)
_op('AND', imm=0x29, zp=0x25, zpx=0x35, abs=0x2D, absx=0x3D, absy=0x39, indx=0x21, indy=0x31)
_op('ASL', acc=0x0A, zp=0x06, zpx=0x16, abs=0x0E, absx=0x1E)
_op('BIT', zp=0x24, abs=0x2C)
_op('BRK', imp=0x00)
_op('CMP', imm=0xC9, zp=0xC5, zpx=0xD5, abs=0xCD, absx=0xDD, absy=0xD9, indx=0xC1, indy=0xD1)
_op('CPX', imm=0xE0, zp=0xE4, abs=0xEC)
_op('CPY', imm=0xC0, zp=0xC4, abs=0xCC)
_op('DEC', zp=0xC6, zpx=0xD6, abs=0xCE, absx=0xDE)
_op('EOR', imm=0x49, zp=0x45, zpx=0x55, abs=0x4D, absx=0x5D, absy=0x59, indx=0x41, indy=0x51)
_op('INC', zp=0xE6, zpx=0xF6, abs=0xEE, absx=0xFE)
_op('JMP', abs=0x4C, ind=0x6C)
_op('JSR', abs=0x20)
_op('LDA', imm=0xA9, zp=0xA5, zpx=0xB5, abs=0xAD, absx=0xBD, absy=0xB9, indx=0xA1, indy=0xB1)
_op('LDX', imm=0xA2, zp=0xA6, zpy=0xB6, abs=0xAE, absy=0xBE)
_op('LDY', imm=0xA0, zp=0xA4, zpx=0xB4, abs=0xAC, absx=0xBC)
_op('LSR', acc=0x4A, zp=0x46, zpx=0x56, abs=0x4E, absx=0x5E)
_op('ORA', imm=0x09, zp=0x05, zpx=0x15, abs=0x0D, absx=0x1D, absy=0x19, indx=0x01, indy=0x11)
_op('ROL', acc=0x2A, zp=0x26, zpx=0x36, abs=0x2E, absx=0x3E)
_op('ROR', acc=0x6A, zp=0x66, zpx=0x76, abs=0x6E, absx=0x7E)
_op('SBC', imm=0xE9, zp=0xE5, zpx=0xF5, abs=0xED, absx=0xFD, absy=0xF9, indx=0xE1, indy=0xF1)
_op('STA', zp=0x85, zpx=0x95, abs=0x8D, absx=0x9D, absy=0x99, indx=0x81, indy=0x91)
_op('STX', zp=0x86, zpy=0x96, abs=0x8E)
_op('STY', zp=0x84, zpx=0x94, abs=0x8C)
for _n, _c in dict(BCC=0x90, BCS=0xB0, BEQ=0xF0, BMI=0x30, BNE=0xD0, BPL=0x10,
                   BVC=0x50, BVS=0x70).items():
    _op(_n, rel=_c)
for _n, _c in dict(CLC=0x18, CLD=0xD8, CLI=0x58, CLV=0xB8, DEX=0xCA, DEY=0x88,
                   INX=0xE8, INY=0xC8, NOP=0xEA, PHA=0x48, PHP=0x08, PLA=0x68,
                   PLP=0x28, RTI=0x40, RTS=0x60, SEC=0x38, SED=0xF8, SEI=0x78,
                   TAX=0xAA, TAY=0xA8, TSX=0xBA, TXA=0x8A, TXS=0x9A, TYA=0x98).items():
    _op(_n, imp=_c)


class AsmError(Exception):
    pass


def atascii(ch):
    o = ord(ch)
    if 0xE000 <= o <= 0xE0FF:
        return o - 0xE000
    if o < 0x80:
        return o
    raise AsmError(f"character {ch!r} (U+{o:04X}) has no ATASCII mapping")


LABEL_CH = r'A-Z0-9_.@?'


def split_args(s):
    """split on commas outside "strings" and 'c char constants"""
    out, cur, i = [], '', 0
    while i < len(s):
        c = s[i]
        if c == '"':
            j = s.index('"', i + 1) if '"' in s[i + 1:] else len(s) - 1
            cur += s[i:j + 1]; i = j + 1; continue
        if c == "'" and i + 1 < len(s):
            cur += s[i:i + 2]; i += 2; continue
        if c == ',':
            out.append(cur.strip()); cur = ''; i += 1; continue
        cur += c; i += 1
    out.append(cur.strip())
    return out


def strip_comment(s):
    i, q = 0, False
    while i < len(s):
        c = s[i]
        if c == '"':
            q = not q
        elif c == "'" and not q:
            i += 2; continue
        elif c == ';' and not q:
            return s[:i]
        i += 1
    return s


class Assembler:
    def __init__(self):
        self.pass1_syms = {}

    # ------------------------------------------------------------ expressions
    def eval(self, text, where):
        """return (value or None, known_so_far)"""
        self._t = re.findall(r"\$[0-9A-Fa-f]+|\d+|'.|<>|<=|>=|[A-Za-z_][A-Za-z0-9_.?]*|\S", text.strip())
        self._i = 0
        self._known = True
        self._where = where
        if not self._t:
            raise AsmError(f"missing expression")
        v = self._unary_lohi()
        if self._i != len(self._t):
            raise AsmError(f"bad expression {text!r}")
        return v, self._known

    def _peek(self):
        return self._t[self._i] if self._i < len(self._t) else None

    def _next(self):
        t = self._peek(); self._i += 1; return t

    def _unary_lohi(self):
        t = self._peek()
        if t in ('<', '>'):
            self._next()
            v = self._cmp()
            return v & 0xFF if t == '<' else (v >> 8) & 0xFF
        return self._cmp()

    def _cmp(self):
        a = self._sum()
        t = self._peek()
        if t in ('=', '<>', '<', '>', '<=', '>='):
            self._next(); b = self._sum()
            r = {'=': a == b, '<>': a != b, '<': a < b, '>': a > b, '<=': a <= b, '>=': a >= b}[t]
            return 1 if r else 0
        return a

    def _sum(self):
        v = self._term()
        while self._peek() in ('+', '-', '&', '!', '^'):
            op = self._next(); b = self._term()
            v = {'+': v + b, '-': v - b, '&': v & b, '!': v | b, '^': v ^ b}[op]
        return v & 0xFFFF

    def _term(self):
        v = self._factor()
        while self._peek() in ('*', '/'):
            op = self._next(); b = self._factor()
            v = v * b if op == '*' else (v // b if b else 0)
        return v

    def _factor(self):
        t = self._next()
        if t is None:
            raise AsmError("unexpected end of expression")
        if t == '-':
            return -self._factor() & 0xFFFF
        if t == '*':
            return self.pc
        if t == '[':
            v = self._unary_lohi()
            if self._next() != ']':
                raise AsmError("[ without ]")
            return v
        if t.startswith('$'):
            return int(t[1:], 16)
        if t.isdigit():
            return int(t)
        if t.startswith("'"):
            return atascii(t[1])
        if re.match(r'[A-Za-z_]', t):
            name = t.upper()
            if name in self.syms:
                return self.syms[name]
            self._known = False
            if name in self.pass1_syms:
                return self.pass1_syms[name]
            if self.pass_no == 2:
                raise AsmError(f"undefined symbol {name}")
            return 0xFFFF          # unknown in pass 1: assume absolute
        raise AsmError(f"unexpected {t!r} in expression")

    # ------------------------------------------------------------ output
    def emit(self, data, src):
        if self.pass_no == 2:
            for k, b in enumerate(data):
                a = (self.pc + k) & 0xFFFF
                if a in self.mem:
                    self.warn(f"address ${a:04X} written twice")
                self.mem[a] = b & 0xFF
                self.order.append(a)
            self.listing.append((self.pc, bytes(data), src))
        self.pc = (self.pc + len(data)) & 0xFFFF

    def warn(self, msg):
        if self.pass_no == 2:
            self.warnings.append(f"{self.where}: warning: {msg}")

    def define(self, name, value):
        name = name.upper()
        if name in self.syms and self.syms[name] != value:
            raise AsmError(f"symbol {name} redefined")
        if self.pass_no == 2 and name in self.pass1_syms and self.pass1_syms[name] != value:
            raise AsmError(f"phase error: {name} was ${self.pass1_syms[name]:04X} in pass 1, "
                           f"${value:04X} in pass 2")
        self.syms[name] = value

    # ------------------------------------------------------------ source
    def read_file(self, path):
        with open(path, encoding='utf-8') as f:
            raw = f.read().split('\n')
        out = []
        for n, l in enumerate(raw, 1):
            l = l.rstrip('\r')
            if not l.strip():
                continue
            m = re.match(r'(\d+) ?(.*)$', l)
            if m:
                out.append((f"{os.path.basename(path)}:{m.group(1)}", m.group(2)))
            else:
                out.append((f"{os.path.basename(path)}:{n}", l))
        return out

    def resolve_include(self, spec, base):
        name = re.sub(r'^#?D\d?:', '', spec.strip(), flags=re.I)
        d = os.path.dirname(base)
        for f in os.listdir(d or '.'):
            if f.upper() == name.upper():
                return os.path.join(d, f)
        raise AsmError(f"include file {name} not found next to {base}")

    def run_pass(self, path):
        self.syms = {}
        self.pc = 0
        self.macros = {}
        self.mem = {}
        self.order = []
        self.listing = []
        self.warnings = []
        self.cond = []
        self.mac_count = 0
        self.including = False
        self.process_lines(self.read_file(path), path, None)
        if self.cond:
            raise AsmError("missing .ENDIF at end of source")

    def active(self):
        return all(c[0] for c in self.cond)

    def process_lines(self, lines, path, macro_ctx):
        i = 0
        while i < len(lines):
            where, text = lines[i]
            self.where = where
            i += 1
            # macro definition capture
            body = strip_comment(text)
            m = re.match(r'\s+\.MACRO\s+(\S+)', body, re.I)
            if m and self.active():
                name = m.group(1).upper()
                mbody = []
                while True:
                    if i >= len(lines):
                        raise AsmError(f"{where}: .MACRO {name} without .ENDM")
                    w2, t2 = lines[i]; i += 1
                    if re.match(r'\s+\.ENDM\b', strip_comment(t2), re.I):
                        break
                    mbody.append((w2, t2))
                local = set()
                for _, t2 in mbody:
                    lm = re.match(r'([A-Za-z_][A-Za-z0-9_.]*)', t2)
                    if lm:
                        local.add(lm.group(1).upper())
                self.macros[name] = (mbody, local)
                continue
            try:
                self.statement(text, path, macro_ctx)
            except AsmError as e:
                raise AsmError(f"{where}: {e}") from None

    def statement(self, text, path, macro_ctx):
        src = text
        body = strip_comment(text).rstrip()
        if not body.strip():
            return
        if body.startswith('*'):                 # column-1 '*' is a comment in MAC/65
            return
        label = None
        if not body[0].isspace():
            parts = body.split(None, 1)
            label = parts[0].upper()
            rest = parts[1] if len(parts) > 1 else ''
        else:
            rest = body.strip()
        # split op / operand
        if rest.startswith('*='):
            op, operand = '*=', rest[2:].strip()
        elif rest.startswith('='):
            op, operand = '=', rest[1:].strip()
        else:
            p = rest.split(None, 1)
            op = p[0].upper() if p else ''
            operand = p[1].strip() if len(p) > 1 else ''

        # conditionals are processed even when inactive
        if op == '.IF':
            if self.active():
                v, known = self.eval(operand, self.where)
                if not known:
                    raise AsmError(f".IF {operand.strip()}: a symbol in it is not defined yet "
                                   "(MAC/65 decides .IF in pass 1)")
                self.cond.append([v != 0, False])
            else:
                self.cond.append([False, True])     # skip whole block
            return
        if op == '.ELSE':
            if not self.cond:
                raise AsmError(".ELSE without .IF")
            c = self.cond[-1]
            if not c[1]:
                c[0] = not c[0]
            return
        if op == '.ENDIF':
            if not self.cond:
                raise AsmError(".ENDIF without .IF")
            self.cond.pop()
            return
        if not self.active():
            return

        if op == '=':
            v, _ = self.eval(operand, self.where)
            if not label:
                raise AsmError("'=' needs a label")
            self.define(label, v)
            if self.pass_no == 2:
                self.listing.append((None, b'', src))
            return
        if op == '*=':
            if label:
                self.define(label, self.pc)
            v, _ = self.eval(operand, self.where)
            self.pc = v
            if self.pass_no == 2:
                self.listing.append((None, b'', src))
            return
        if label:
            self.define(label, self.pc)
        if not op:
            if self.pass_no == 2:
                self.listing.append((self.pc, b'', src))
            return
        if op == '.ERROR':
            raise AsmError(f".ERROR {operand}")
        if op == '.OPT' or op == '.TITLE' or op == '.PAGE':
            return
        if op == '.INCLUDE':
            if self.including:
                raise AsmError("an included file includes another: MAC/65 stops with "
                               "NESTED INCLUDE; only the main file has .INCLUDE lines")
            inc = self.resolve_include(operand, path)
            self.including = True
            try:
                self.process_lines(self.read_file(inc), inc, macro_ctx)
            finally:
                self.including = False
            return
        if op == '.BYTE':
            data = []
            for item in split_args(operand):
                if item.startswith('"'):
                    if not item.endswith('"') or len(item) < 2:
                        raise AsmError(f"unterminated string {item!r}")
                    data += [atascii(c) for c in item[1:-1]]
                else:
                    v, _ = self.eval(item, self.where)
                    if v > 0xFF:
                        self.warn(f".BYTE value ${v:04X} truncated")
                    data.append(v & 0xFF)
            self.emit(data, src)
            return
        if op == '.WORD':
            data = []
            for item in split_args(operand):
                v, _ = self.eval(item, self.where)
                data += [v & 0xFF, (v >> 8) & 0xFF]
            self.emit(data, src)
            return
        if op.startswith('@'):
            self.expand_macro(op, operand, path, src)
            return
        if op in OPS:
            self.emit(self.encode(op, operand), src)
            return
        raise AsmError(f"unknown instruction or directive {op!r}")

    def expand_macro(self, name, operand, path, src):
        if name not in self.macros:
            raise AsmError(f"undefined macro {name}")
        mbody, local = self.macros[name]
        args = [a for a in split_args(operand)] if operand.strip() else []
        self.mac_count += 1
        tag = f"?{self.mac_count}"
        if self.pass_no == 2:
            self.listing.append((None, b'', src))

        def subst(t):
            def rep(m):
                n = int(m.group(1))
                if n == 0:
                    return str(len(args))
                return args[n - 1] if n <= len(args) else ''
            t = re.sub(r'%(\d)', rep, t)
            for lab in local:
                t = re.sub(rf'(?<![{LABEL_CH}]){re.escape(lab)}(?![{LABEL_CH}])', lab + tag, t, flags=re.I)
            return t
        depth = len(self.cond)
        self.process_lines([(w, subst(t)) for w, t in mbody], path, name)
        if len(self.cond) != depth:
            raise AsmError(f"unbalanced .IF/.ENDIF in macro {name}")

    def encode(self, op, operand):
        modes = OPS[op]
        o = operand.strip()
        if not o or (o.upper() == 'A' and 'acc' in modes):
            if 'imp' in modes:
                return [modes['imp']]
            if 'acc' in modes:
                return [modes['acc']]
            raise AsmError(f"{op} needs an operand")
        if 'rel' in modes:
            v, _ = self.eval(o, self.where)
            off = v - (self.pc + 2)
            if self.pass_no == 2 and not -128 <= off <= 127:
                raise AsmError(f"branch out of range ({off:+d} bytes)")
            return [modes['rel'], off & 0xFF]
        if o.startswith('#'):
            if 'imm' not in modes:
                raise AsmError(f"{op} has no immediate mode")
            v, _ = self.eval(o[1:], self.where)
            if v > 0xFF:
                self.warn(f"immediate value ${v:04X} truncated to ${v & 0xFF:02X}")
            return [modes['imm'], v & 0xFF]
        m = re.match(r'\((.*)\)\s*,\s*Y$', o, re.I)
        if m:
            v, _ = self.eval(m.group(1), self.where)
            return self._zp_only(op, 'indy', v)
        m = re.match(r'\((.*),\s*X\)$', o, re.I)
        if m:
            v, _ = self.eval(m.group(1), self.where)
            return self._zp_only(op, 'indx', v)
        m = re.match(r'\((.*)\)$', o)
        if m:
            if 'ind' not in modes:
                raise AsmError(f"{op} has no indirect mode")
            v, _ = self.eval(m.group(1), self.where)
            if self.pass_no == 2 and (v & 0xFF) == 0xFF:
                self.warn(f"JMP (${v:04X}) hits the 6502 page-wrap bug")
            return [modes['ind'], v & 0xFF, v >> 8]
        idx = None
        m = re.match(r'(.*),\s*([XY])$', o, re.I)
        if m:
            o, idx = m.group(1), m.group(2).upper()
        v, known = self.eval(o, self.where)
        zpk, absk = ('zp', 'abs') if idx is None else ('zp' + idx.lower(), 'abs' + idx.lower())
        if known and v < 0x100 and zpk in modes:
            return [modes[zpk], v]
        if not known and self.pass_no == 2 and v < 0x100 and zpk in modes:
            raise AsmError(f"{o.strip()} is zero page but defined later: MAC/65 would make it "
                           "absolute in pass 1 and zero page in pass 2 (a phase error); "
                           "define it before its first use")
        if absk in modes:
            return [modes[absk], v & 0xFF, v >> 8]
        if zpk in modes:
            if v >= 0x100:
                raise AsmError(f"{op} {zpk} operand ${v:04X} is not zero page")
            return [modes[zpk], v]
        raise AsmError(f"addressing mode not valid for {op}")

    def _zp_only(self, op, mode, v):
        if mode not in OPS[op]:
            raise AsmError(f"{op} has no {mode} mode")
        if v > 0xFF:
            raise AsmError(f"indirect operand ${v:04X} is not zero page")
        return [OPS[op][mode], v]

    # ------------------------------------------------------------ driver
    def assemble(self, path):
        self.pass_no = 1
        self.run_pass(path)
        self.pass1_syms = dict(self.syms)
        self.pass_no = 2
        self.run_pass(path)

    def binary(self):
        """Atari binary load file: $FFFF, then one segment per contiguous run"""
        out = bytearray(b'\xff\xff')
        segs, start, prev = [], None, None
        for a in self.order:
            if start is None:
                start = prev = a
            elif a == prev + 1:
                prev = a
            else:
                segs.append((start, prev)); start = prev = a
        if start is not None:
            segs.append((start, prev))
        for s, e in segs:
            out += bytes([s & 0xFF, s >> 8, e & 0xFF, e >> 8])
            out += bytes(self.mem[a] for a in range(s, e + 1))
        return bytes(out), segs


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('source')
    ap.add_argument('-o', '--output', required=True)
    ap.add_argument('-l', '--listing')
    ap.add_argument('-s', '--symbols')
    a = ap.parse_args()
    asm = Assembler()
    try:
        asm.assemble(a.source)
    except AsmError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    for w in asm.warnings:
        print(w, file=sys.stderr)
    data, segs = asm.binary()
    with open(a.output, 'wb') as f:
        f.write(data)
    if a.listing:
        with open(a.listing, 'w') as f:
            for pc, b, src in asm.listing:
                addr = f"{pc:04X}" if pc is not None else '    '
                hx = ' '.join(f"{x:02X}" for x in b[:4]) + (' +' if len(b) > 4 else '')
                f.write(f"{addr}  {hx:<14} {src}\n")
    if a.symbols:
        with open(a.symbols, 'w') as f:
            for k in sorted(asm.syms):
                if '?' not in k:
                    f.write(f"{k:<20} ${asm.syms[k]:04X}\n")
    lo = min(s for s, _ in segs); hi = max(e for _, e in segs)
    print(f"{a.output}: {len(data)} bytes, {len(segs)} segments, ${lo:04X}-${hi:04X}"
          + (f", {len(asm.warnings)} warning(s)" if asm.warnings else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
