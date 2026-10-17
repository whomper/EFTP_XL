#!/usr/bin/env python3
# From EDOS (github.com/whomper/EDOS, tools/mac65tok.py at 6061ed6), with
# the tokens EFTP_XL uses as well: [ ] (grouping), / and * (multiply),
# read from files MAC/65 1.01 saved.
"""MAC/65 tokenized SAVE format: text <-> tokens.

  mac65tok.py tok   SOURCE.M65 OUT.M65   text (as in this repo) -> tokens
  mac65tok.py detok TOKENS.M65 OUT.TXT   tokens -> text

The tokenized form is what MAC/65 writes with SAVE and reads with LOAD:
$FE $FE, a 2-byte length, then per line a 2-byte line number, a length
byte (whole line) and the tokenized body:

  label        $80+len, name
  statement    opcode/directive token, operand tokens
  comment      $58 + text (comment line), $1A + text (after a label),
               $3B + text (after an operand); text keeps its ';'
  operands     $06 nn hex byte, $05 nnnn hex word, $08 nn / $07 nnnn
               decimal, $0A c char, $41 $80+len text $41 string, names
               as $80+len + chars, and single-byte operator tokens

ATASCII bytes $80-$FF and control codes are kept in the text files as
Unicode U+E000+byte.
"""
import re
import sys

DIRECTIVES = {'.IF': 0x01, '.ELSE': 0x02, '.ENDIF': 0x03, '.MACRO': 0x04, '.ENDM': 0x05,
              '.WORD': 0x09, '.BYTE': 0x0B, '.OPT': 0x0F, '.INCLUDE': 0x11,
              '*=': 0x1D, '=': 0x1E}
MNEMONICS = ('JSR JMP DEC INC LDX LDY STX STY CPX CPY BIT BRK CLC CLD CLI CLV DEX DEY INX INY '
             'NOP PHA PHP PLA PLP RTI RTS SEC SED SEI TAX TAY TSX TXA TXS TYA BCC BCS BEQ BMI '
             'BNE BPL BVC BVS ORA AND EOR ADC STA LDA CMP SBC ASL ROL LSR ROR').split()
OPS = dict(DIRECTIVES, **{m: 0x20 + k for k, m in enumerate(MNEMONICS)})
MACRO_CALL, NO_OP, COMMENT_OP, COMMENT = 0x07, 0x58, 0x1A, 0x3B
OPT_WORDS = {'OBJ': 0x46, 'NO': 0x45, 'LIST': 0x49}
SIMPLE = {'+': 0x12, '-': 0x13, '*': 0x0D, '/': 0x15, '=': 0x18, '#': 0x3E, '(': 0x40,
          '[': 0x1F, ']': 0x20}
VALUE = {0x80, 0x06, 0x08, 0x0A, 0x20}          # after these, * multiplies ($14)
UNARY_AFTER = {None, 0x3E, 0x40, 0x3D, 0x12, 0x13, 0x0D, 0x18, 0x1C, 0x1D, 0x34, 0x35,
               0x1F, 0x14, 0x15}


class TokError(Exception):
    pass


def to_bytes(s):
    out = bytearray()
    for ch in s:
        o = ord(ch)
        if 0xE000 <= o <= 0xE0FF:
            out.append(o - 0xE000)
        elif o < 0x80:
            out.append(o)
        else:
            raise TokError(f"character {ch!r} has no ATASCII code")
    return bytes(out)


def from_bytes(b):
    return ''.join(chr(c) if 0x20 <= c < 0x7F else chr(0xE000 + c) for c in b)


def split_comment(s):
    q = False
    i = 0
    while i < len(s):
        c = s[i]
        if c == '"':
            q = not q
        elif c == "'" and not q:
            i += 2
            continue
        elif c == ';' and not q:
            return s[:i].rstrip(), s[i:]
        i += 1
    return s.rstrip(), None


def name_tok(name):
    b = to_bytes(name)
    if not 1 <= len(b) <= 127:
        raise TokError(f"bad name {name!r}")
    return bytes([0x80 | len(b)]) + b


def operand(s, op):
    out = bytearray()
    i, last = 0, None
    s = s.strip()
    if op == '.MACRO':                               # name stored with a space
        return name_tok(s + ' ')
    if op == '.INCLUDE':                             # #D:FILE.EXT is one name
        return bytes([0x3E]) + name_tok(s.lstrip('#').strip())
    if s.upper() == 'A' and op in OPS and OPS[op] >= 0x20:
        return bytes([0x3F])
    while i < len(s):
        c = s[i]
        if c.isspace():
            i += 1
            continue
        if c == '"':
            j = s.index('"', i + 1)
            body = to_bytes(s[i + 1:j])
            out += bytes([0x41, 0x80 | len(body)]) + body + bytes([0x41])
            i, last = j + 1, 0x41
            continue
        if c == "'":
            out += bytes([0x0A]) + to_bytes(s[i + 1])
            i, last = i + 2, 0x0A
            continue
        if c == '$':
            m = re.match(r'\$([0-9A-Fa-f]+)', s[i:])
            v = int(m.group(1), 16)
            out += bytes([0x06, v]) if len(m.group(1)) <= 2 else bytes([0x05, v & 0xFF, v >> 8])
            i, last = i + len(m.group(0)), 0x06
            continue
        if c.isdigit():
            m = re.match(r'\d+', s[i:])
            v = int(m.group(0))
            out += bytes([0x08, v]) if v <= 0xFF else bytes([0x07, v & 0xFF, v >> 8])
            i, last = i + len(m.group(0)), 0x08
            continue
        if c == '%':
            m = re.match(r'%(\d)', s[i:])
            out += bytes([0x0C, 0x08, int(m.group(1))])
            i, last = i + 2, 0x08
            continue
        if s[i:i + 3].upper() == '),Y':
            out.append(0x37); i += 3; last = 0x37; continue
        if s[i:i + 2].upper() == ',Y':
            out.append(0x38); i += 2; last = 0x38; continue
        if s[i:i + 2].upper() == ',X' and not re.match(r',X[A-Z0-9_.]', s[i:].upper()):
            out.append(0x39); i += 2; last = 0x39; continue
        if c == ',':
            out.append(0x3D); i += 1; last = 0x3D; continue
        if c == ')':
            out.append(0x3A); i += 1; last = 0x3A; continue
        if c in '<>':
            unary = last in UNARY_AFTER
            t = (0x34 if c == '<' else 0x35) if unary else (0x1D if c == '<' else 0x1C)
            out.append(t); i += 1; last = t; continue
        if c == '*' and last in VALUE:
            out.append(0x14); i += 1; last = 0x14; continue
        if c in SIMPLE:
            out.append(SIMPLE[c]); i += 1; last = SIMPLE[c]; continue
        m = re.match(r'[A-Za-z_@][A-Za-z0-9_.@]*', s[i:])
        if m:
            w = m.group(0)
            if op == '.OPT' and w.upper() in OPT_WORDS:
                out.append(OPT_WORDS[w.upper()])
            else:
                out += name_tok(w)
            i, last = i + len(w), 0x80
            continue
        raise TokError(f"cannot tokenize {s[i:]!r} in operand {s!r}")
    return bytes(out)


def tokenize_line(body):
    if not body.strip():
        return b''
    if body.startswith(';') or body.startswith('*'):     # comment lines
        return bytes([NO_OP]) + to_bytes(body)
    out = bytearray()
    rest = body
    if not body[0].isspace():
        label, _, rest = body.partition(' ')
        out += name_tok(label)
        rest = rest.strip()
        if not rest:
            return bytes(out)
        if rest.startswith(';'):
            return bytes(out) + bytes([COMMENT_OP]) + to_bytes(rest)
    else:
        rest = rest.strip()
        if rest.startswith(';'):
            return bytes([NO_OP]) + to_bytes(rest)
    stmt, comment = split_comment(rest)
    if stmt.startswith('*='):
        op, opnd = '*=', stmt[2:]
    elif stmt.startswith('='):
        op, opnd = '=', stmt[1:]
    else:
        op, _, opnd = stmt.partition(' ')
        op = op.upper()
    if op.startswith('@'):
        out += bytes([MACRO_CALL]) + name_tok(op + ' ')
    elif op in OPS:
        out.append(OPS[op])
    else:
        raise TokError(f"unknown instruction {op!r}")
    out += operand(opnd, op)
    if comment is not None:
        out += bytes([COMMENT]) + to_bytes(comment)
    return bytes(out)


def tokenize(text):
    body = bytearray()
    for n, line in enumerate(text.split('\n'), 1):
        line = line.rstrip('\r')
        if not line.strip():
            continue
        m = re.match(r'(\d+) ?(.*)$', line)
        if not m:
            raise TokError(f"line {n}: no line number")
        try:
            t = tokenize_line(m.group(2))
        except TokError as e:
            raise TokError(f"line {m.group(1)}: {e}") from None
        num = int(m.group(1))
        if len(t) + 3 > 255:
            raise TokError(f"line {num}: too long")
        body += bytes([num & 0xFF, num >> 8, len(t) + 3]) + t
    return b'\xfe\xfe' + bytes([len(body) & 0xFF, len(body) >> 8]) + bytes(body)


NAMES = {v: k for k, v in OPS.items()}
OPERAND_TEXT = {0x12: '+', 0x13: '-', 0x0D: '*', 0x14: '*', 0x15: '/', 0x1F: '[', 0x20: ']',
                0x0C: '%', 0x18: '=', 0x1D: '<', 0x1C: '>',
                0x3E: '#', 0x40: '(', 0x37: '),Y', 0x38: ',Y', 0x39: ',X', 0x3D: ',',
                0x34: ' <', 0x35: ' >', 0x3A: ')', 0x3F: 'A', 0x46: 'OBJ', 0x45: 'NO ',
                0x49: 'LIST'}


def _operand_text(b):
    s, i = '', 0
    while i < len(b):
        c = b[i]
        if c == COMMENT:
            return s, from_bytes(b[i + 1:])
        if c & 0x80:
            n = c & 0x7F
            s += from_bytes(b[i + 1:i + 1 + n]); i += 1 + n
        elif c == 0x06:
            s += f"${b[i + 1]:02X}"; i += 2
        elif c == 0x05:
            s += f"${b[i + 1] | b[i + 2] << 8:04X}"; i += 3
        elif c == 0x08:
            s += str(b[i + 1]); i += 2
        elif c == 0x07:
            s += str(b[i + 1] | b[i + 2] << 8); i += 3
        elif c == 0x0A:
            s += "'" + from_bytes(b[i + 1:i + 2]); i += 2
        elif c == 0x41:
            n = b[i + 1] & 0x7F
            s += '"' + from_bytes(b[i + 2:i + 2 + n]) + '"'; i += 3 + n
        elif c in OPERAND_TEXT:
            s += OPERAND_TEXT[c]; i += 1
        else:
            raise TokError(f"unknown operand token ${c:02X}")
    return s, None


def _num(n):
    return str(n) if n < 100 else (f"{n:04d}" if n < 10000 else f"{n:06d}")


def detokenize(data):
    """tokenized SAVE file -> text in this repository's style"""
    if data[:2] != b'\xfe\xfe':
        raise TokError("not a MAC/65 tokenized file")
    out, i = [], 4
    while i < len(data):
        num, ln = data[i] | data[i + 1] << 8, data[i + 2]
        b, i = data[i + 3:i + ln], i + ln
        pre, k, label = _num(num), 0, ''
        if b and b[0] & 0x80:
            n = b[0] & 0x7F
            label, k = from_bytes(b[1:1 + n]), 1 + n
        if k >= len(b):
            out.append(f"{pre} {label}".rstrip())
            continue
        t, rest = b[k], b[k + 1:]
        if t == NO_OP:
            out.append(f"{pre} {from_bytes(rest)}")
            continue
        if t == COMMENT_OP:
            out.append(f"{pre} {label} {from_bytes(rest)}")
            continue
        if t == MACRO_CALL:
            n = rest[0] & 0x7F
            op, rest = from_bytes(rest[1:1 + n]).rstrip(), rest[1 + n:]
        elif t in NAMES:
            op = NAMES[t]
        else:
            raise TokError(f"line {num}: unknown token ${t:02X}")
        if op == '.MACRO':
            opnd, comment = from_bytes(rest[1:1 + (rest[0] & 0x7F)]).rstrip(), None
        else:
            opnd, comment = _operand_text(rest)
        if op == '.INCLUDE':
            opnd = opnd.replace('# ', '#')
        stmt = f"{op} {opnd}".rstrip() if op not in ('=', '*=') else f"{op} {opnd}"
        if op.startswith('@'):
            stmt = f"{op}  {opnd}".rstrip()
        line = f"{pre} {label} {stmt}" if label else f"{pre}{' ' * (9 - len(pre))}{stmt}"
        if comment is not None:
            line += ' ' + comment
        out.append(line)
    return '\n'.join(out) + '\n'


def main():
    a = sys.argv[1:]
    if len(a) != 3 or a[0] not in ('tok', 'detok'):
        print(__doc__)
        return 1
    if a[0] == 'tok':
        with open(a[1], encoding='utf-8') as f:
            data = tokenize(f.read())
        with open(a[2], 'wb') as f:
            f.write(data)
    else:
        with open(a[1], 'rb') as f:
            text = detokenize(f.read())
        with open(a[2], 'w', encoding='utf-8') as f:
            f.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
