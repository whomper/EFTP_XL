#!/usr/bin/env python3
# AERA-Atari xl/tests - the shared tools
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""xl/tools: the assembler, the tokeniser, the source disk and the font.

    python3 xl/tests/test_tools.py
"""
import hashlib
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
XL = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(XL, 'tools'))
import atari_src  # noqa: E402
import font  # noqa: E402
import mac65  # noqa: E402
import mac65tok  # noqa: E402
import sparta  # noqa: E402


def assemble(files, main='MAIN.M65'):
    """{name: text} assembled from a scratch folder; (Assembler, binary)"""
    tmp = tempfile.mkdtemp()
    try:
        for name, text in files.items():
            with open(os.path.join(tmp, name), 'w', encoding='utf-8') as f:
                f.write(text)
        asm = mac65.Assembler()
        asm.assemble(os.path.join(tmp, main))
        return asm, asm.binary()[0]
    finally:
        shutil.rmtree(tmp)


class TestAssembler(unittest.TestCase):
    def test_brackets(self):
        _, b = assemble({'MAIN.M65': ' *= $2000\nL LDA #<[L+$102]\n LDA #>[L+$102]\n'
                                     ' .BYTE [2+3]*4\n'})
        self.assertEqual(b[6:], bytes([0xA9, 0x02, 0xA9, 0x21, 20]))

    def test_numbered_and_not_the_same(self):
        text = ' *= $2000\nSTART LDA #1 ; one\n STA $80\n RTS\n'
        num = ''.join(f'{(n + 1) * 10} {x}\n' for n, x in enumerate(text.split('\n')[:-1]))
        self.assertEqual(assemble({'MAIN.M65': text})[1], assemble({'MAIN.M65': num})[1])

    def test_zero_page_defined_later(self):
        with self.assertRaisesRegex(mac65.AsmError, 'phase error'):
            assemble({'MAIN.M65': ' *= $2000\n LDA PTR\nPTR = $80\n'})
        _, b = assemble({'MAIN.M65': 'PTR = $80\n *= $2000\n LDA PTR\n'})
        self.assertEqual(b[6:], bytes([0xA5, 0x80]))
        _, b = assemble({'MAIN.M65': ' *= $2000\n JSR SUB\nSUB RTS\n'})   # absolute: fine
        self.assertEqual(b[6:9], bytes([0x20, 0x03, 0x20]))

    def test_equate_from_a_later_symbol(self):
        # MAC/65 1.01 takes it (EFTP_XL tried the cartridge): A9 34 A9 12 60
        _, b = assemble({'MAIN.M65': ' *= $4000\nXA = YB\n LDA #<XA\n LDA #>XA\n RTS\n'
                                     'YB = $1234\n'})
        self.assertEqual(b[6:], bytes([0xA9, 0x34, 0xA9, 0x12, 0x60]))
        _, b = assemble({'MAIN.M65': 'AXHIGH = BSSEND\n *= $2000\n .WORD AXHIGH\nBSSEND *= *+2\n'})
        self.assertEqual(b[6:], bytes([0x02, 0x20]))
        with self.assertRaisesRegex(mac65.AsmError, 'phase error'):   # zero page: not safe
            assemble({'MAIN.M65': 'XA = YB\n *= $2000\n LDA XA\nYB = $80\n'})
        with self.assertRaisesRegex(mac65.AsmError, r'\.IF'):
            assemble({'MAIN.M65': 'XA = YB\n .IF XA\n .ENDIF\nYB = 1\n'})

    def test_if_on_a_later_symbol(self):
        with self.assertRaisesRegex(mac65.AsmError, r'\.IF'):
            assemble({'MAIN.M65': ' *= $2000\n .IF LATER\n NOP\n .ENDIF\nLATER = 1\n'})

    def test_nested_include(self):
        with self.assertRaisesRegex(mac65.AsmError, 'NESTED INCLUDE'):
            assemble({'MAIN.M65': ' .INCLUDE #D:A.M65\n', 'A.M65': ' .INCLUDE #D:B.M65\n',
                      'B.M65': ' NOP\n'})

    def test_shared_files_assemble(self):
        files = {n: open(os.path.join(XL, 'src', n), encoding='utf-8').read()
                 for n in os.listdir(os.path.join(XL, 'src'))}
        files['MAIN.M65'] = (' .INCLUDE #D:AXEQU.M65\nAXPTR = $80\nAXERRS = 2\nAXLOW = $2000\n'
                             'AXHIGH = $3000\nAXWARM = $2000\nAXFMIN = $80\nAXFCOPY = 1\n *= $2F00\nAXLOWM .BYTE EOL\n'
                             'AXROOMM .BYTE EOL\n .INCLUDE #D:AXLOAD.M65\n *= $2000\n'
                             ' .INCLUDE #D:AXRESET.M65\n .INCLUDE #D:AXFONT.M65\n'
                             ' .INCLUDE #D:AXERR.M65\n')
        asm, _ = assemble(files)
        self.assertEqual(asm.warnings, [])


class TestTokens(unittest.TestCase):
    def test_known_encodings(self):
        # byte for byte as MAC/65 1.01 SAVEd them (EDOS's checks)
        cases = {
            "RTN   =   $7B     ;RTN KEY": b'\x83RTN\x1e\x06\x7b\x3b;RTN KEY',
            "    LDA FILPOS+1": b'\x51\x86FILPOS\x12\x08\x01',
            "    STA (INDPTR),Y": b'\x50\x40\x86INDPTR\x37',
            "    LDA # >START": b'\x51\x3e\x35\x85START',
            "    ASL A": b'\x54\x3f',
            "CS.128 .BYTE \"Key Abort\",EOL": b'\x86CS.128\x0b\x41\x89Key Abort\x41\x3d\x83EOL',
            "     @FILLMEM  FILE,$28,$20": b'\x07\x89@FILLMEM \x84FILE\x3d\x06\x28\x3d\x06\x20',
            "      .IF %0>3": b'\x01\x0c\x08\x00\x1c\x08\x03',
            "VDSLST = $0200": b'\x86VDSLST\x1e\x05\x00\x02',
            "    .INCLUDE #D:MACROS.M65": b'\x11\x3e\x8cD:MACROS.M65',
            "    .MACRO @CPYMEM": b'\x04\x88@CPYMEM ',
            "*=RUNAD": b'\x58*=RUNAD',
            "; COMMENT": b'\x58; COMMENT',
            "START_PROG": b'\x8aSTART_PROG',
        }
        for text, want in cases.items():
            self.assertEqual(mac65tok.tokenize_line(text), want, text)

    def test_eftp_xl_tokens(self):
        # [ ] grouping, / and * multiply (EFTP_XL's, from MAC/65 1.01's SAVE)
        for line in ('         LDA #<[LLINE+2]', '         .BYTE [A-B]/2', '         .WORD A*3'):
            tok = mac65tok.tokenize_line(atari_src.squeeze(line))
            self.assertTrue({0x1F, 0x20, 0x15, 0x14} & set(tok), line)
            back = mac65tok.detokenize(mac65tok.tokenize(f'10 {atari_src.squeeze(line)}\n'))
            self.assertEqual(mac65tok.tokenize_line(back.split(' ', 1)[1].strip('\n')), tok)

    def test_rejects_unknown(self):
        with self.assertRaises(mac65tok.TokError):
            mac65tok.tokenize_line("    FOO BAR")


SAMPLE = """;
; MAIN.M65 - TEST 1.0
; A test
; Copyright (C) 2026 AERA | Erez Yaary
;
         *=  $2000
START    LDA #<[MSG+1]      ; the low byte
         LDY #>MSG
LOOP     LDA MSG,X          ; next
         BNE LOOP
         RTS
MSG      .BYTE "Hi; there",$9B
"""


class TestSourceDisk(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_round_trip(self):
        disk = atari_src.to_disk(SAMPLE, 'MAIN.M65', 'TEST', '1.0')
        self.assertEqual(disk[:2], b'\xfe\xfe')
        lines = atari_src.from_atari(disk)
        self.assertEqual(atari_src.merge(lines, SAMPLE), SAMPLE)

    def test_numbers_rise(self):
        nums = [int(x.split()[0]) for x in atari_src.numbered(SAMPLE).split('\n') if x]
        self.assertEqual(nums, list(range(10, 10 * len(nums) + 1, 10)))

    def test_an_atari_edit_comes_home(self):
        lines = atari_src.from_atari(atari_src.to_disk(SAMPLE, 'MAIN.M65', 'TEST', '1.0'))
        lines.insert(9, ' INX ;on')                    # typed on the Atari
        lines[10] = lines[10].replace('LOOP', '  LOOP')  # its spacing: no change
        got = atari_src.merge(lines, SAMPLE).split('\n')
        self.assertEqual(got[9], '         INX                ;on')
        self.assertEqual(got[10], '         BNE LOOP')
        self.assertEqual(got[:9] + got[10:], SAMPLE.split('\n'))

    def test_list_text_comes_home(self):
        listed = atari_src.numbered(SAMPLE).encode('ascii').replace(b'\n', b'\x9b')
        self.assertEqual(atari_src.merge(atari_src.from_atari(listed), SAMPLE), SAMPLE)

    def test_header(self):
        with self.assertRaisesRegex(atari_src.SrcError, 'TEST 1.1'):
            atari_src.to_disk(SAMPLE, 'MAIN.M65', 'TEST', '1.1')
        with self.assertRaisesRegex(atari_src.SrcError, 'OTHER.M65'):
            atari_src.to_disk(SAMPLE, 'OTHER.M65', 'TEST', '1.0')

    def test_no_numbers_in_git(self):
        with self.assertRaisesRegex(atari_src.SrcError, 'number'):
            atari_src.numbered('10 START RTS\n')

    def test_too_big(self):
        big = SAMPLE + ''.join(f'L{n}      LDA #{n & 255}       ; a long line {n}\n'
                               for n in range(1200))
        with self.assertRaisesRegex(atari_src.SrcError, 'split it'):
            atari_src.to_disk(big, 'MAIN.M65', 'TEST', '1.0')

    def test_disk(self):
        src = os.path.join(self.tmp, 'MAIN.M65')
        with open(src, 'w') as f:
            f.write(SAMPLE)
        prg = os.path.join(self.tmp, 'TEST.PRG')
        with open(prg, 'wb') as f:
            f.write(b'\xff\xff\x00\x20\x00\x20\x60')
        atr = os.path.join(self.tmp, 'TEST.ATR')
        a = type('A', (), dict(atr=atr, files=[src, prg], program='TEST', version='1.0',
                               volume=None, base=None, tree=None))
        atari_src.cmd_disk(a)
        problems, lost = sparta.Disk(atr).fsck()
        self.assertFalse(problems or lost)
        files = atari_src.files_of(atr)
        self.assertEqual(sorted(files), ['MAIN.M65', 'TEST.PRG', 'X32G.DOS'])
        self.assertEqual(files['TEST.PRG'], open(prg, 'rb').read())
        back = os.path.join(self.tmp, 'back')
        os.mkdir(back)
        shutil.copy(src, back)
        atari_src.cmd_check(type('A', (), dict(atr=atr, to=back)))
        self.assertEqual(open(os.path.join(back, 'MAIN.M65')).read(), SAMPLE)

    def test_layout(self):
        path = os.path.join(self.tmp, 'OLD.M65')
        with open(path, 'w') as f:
            f.write('10 ;OLD\n20 START LDA #1 ;ONE\n30     STA $80\n40 LOOP\n')
        atari_src.cmd_layout(type('A', (), dict(files=[path])))
        self.assertEqual(open(path).read(), ';OLD\nSTART    LDA #1             ;ONE\n'
                                            '         STA $80\nLOOP\n')

    def test_empty_file(self):
        # an empty file owns its sector map, so nothing is lost (EDOS found it)
        atr = os.path.join(self.tmp, 'E.ATR')
        d = atari_src.new_disk(atr, 'EMPTY')
        d.add('EMPTY.TXT', b'')
        d.save()
        d = sparta.Disk(atr)
        problems, lost = d.fsck()
        self.assertFalse(problems or lost, (problems, lost))
        self.assertEqual(atari_src.files_of(atr)['EMPTY.TXT'], b'')
        d.remove('EMPTY.TXT')
        d.save()
        problems, lost = sparta.Disk(atr).fsck()
        self.assertFalse(problems or lost, (problems, lost))

    def test_folders(self):
        # as SpartaDOS 3.2's MD makes them (checked in atari800): the parent's
        # entry $28 with length 0; the folder's entry 0 the parent's map and its length
        atr = os.path.join(self.tmp, 'F.ATR')
        d = atari_src.new_disk(atr, 'FOLDERS')
        tree = os.path.join(self.tmp, 'tree')
        os.makedirs(os.path.join(tree, 'sub'))
        with open(os.path.join(tree, 'a.txt'), 'wb') as f:
            f.write(b'A' * 300)
        with open(os.path.join(tree, 'sub', 'c.txt'), 'wb') as f:
            f.write(b'IN SUB')
        d.mkdir('DOCS')
        d.add('DOCS>NOTE.TXT', b'NOTE')
        atari_src.add_tree(d, tree, 'DOCS>')
        d.save()
        d = sparta.Disk(atr)
        self.assertFalse(any(d.fsck()), d.fsck())
        self.assertEqual([(p, f) for p, e, f in d.walk() if p != 'X32G.DOS'],
                         [('DOCS', True), ('DOCS>NOTE.TXT', False), ('DOCS>A.TXT', False),
                          ('DOCS>SUB', True), ('DOCS>SUB>C.TXT', False)])
        i, e = d.find('DOCS')
        self.assertEqual((e[0], e[3:6]), (0x28, bytes(3)))
        h = d.dir_bytes(d.w(e, 1))
        self.assertEqual((h[0], d.w(h, 1), h[3], h[6:14]), (0, d.root(), len(h), b'DOCS    '))
        self.assertEqual(len(h), 4 * 23)
        i, e = d.find('DOCS>SUB>C.TXT')
        self.assertEqual(d.read_file(d.w(e, 1), 6), b'IN SUB')
        self.assertEqual(d.w(d.dir_bytes(d.folder(['DOCS', 'SUB'])), 1), d.folder(['DOCS']))
        d.remove('DOCS>A.TXT')
        d.add('docs>sub>c.txt', b'NEW')                 # replaced
        d.save()
        d = sparta.Disk(atr)
        self.assertFalse(any(d.fsck()), d.fsck())
        self.assertIsNone(d.find('DOCS>A.TXT'))
        i, e = d.find('DOCS>SUB>C.TXT')
        self.assertEqual(d.read_file(d.w(e, 1), e[3]), b'NEW')
        with self.assertRaises(sparta.SpartaError):
            d.add('NONE>X.TXT', b'')
        with self.assertRaises(sparta.SpartaError):
            d.mkdir('DOCS')
        with self.assertRaises(sparta.SpartaError):
            d.remove('DOCS>SUB')

    def test_shared_files_round_trip(self):
        for name in os.listdir(os.path.join(XL, 'src')):
            text = open(os.path.join(XL, 'src', name), encoding='utf-8').read()
            disk = atari_src.to_disk(text, name, 'ANY', '9.9')
            self.assertEqual(atari_src.merge(atari_src.from_atari(disk), text), text, name)

    def test_shared_files_follow_the_rules(self):
        for name in os.listdir(os.path.join(XL, 'src')):
            text = open(os.path.join(XL, 'src', name), encoding='utf-8').read()
            code = [x for x in text.split('\n') if not x.startswith(';')]
            self.assertNotIn('.INCLUDE', '\n'.join(code).upper(), name)
            for line in text.split('\n'):
                if line.startswith(';'):
                    self.assertLessEqual(len(line), 38, f'{name}: {line}')
                label = line.split(' ', 1)[0]
                if label and not line.startswith(';'):
                    self.assertTrue(label.startswith('AX') or name == 'AXEQU.M65', label)
                    self.assertLessEqual(len(label), 8, label)


class TestFont(unittest.TestCase):
    def test_aera_font(self):
        f = font.aera_font()
        self.assertEqual(len(f), 1024)
        # EDOS's font with EFTP_XL's four glyphs (fonts/EFTPXL.FNT, 1.1)
        self.assertEqual(hashlib.sha256(f).hexdigest(),
                         'f6da49bbf4c49a08a41f7f5f7e1e30544987fc19b7564b29254d109483990b77')
        self.assertEqual(f[font.internal(0x7B) * 8], 0b10101010)

    def test_kept_font_up_to_date(self):
        # xl/font/AERA.FNT, which programs carry, is the font built here
        with open(font.AERA, 'rb') as f:
            self.assertEqual(f.read(), font.aera_font())
        self.assertEqual(font.ICONS, tuple(font.internal(a) for a in (0x00, 0x06, 0x10, 0x7B)))


if __name__ == '__main__':
    unittest.main()
