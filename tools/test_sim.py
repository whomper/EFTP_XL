#!/usr/bin/env python3
# EFTP_XL - end-to-end tests: the real EFTPXL.PRG in tools/sim.py
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Run bin/EFTPXL.PRG on the emulated 6502 against an FTP server started
here (pyftpdlib), with D1: a folder here, and check the screen and the
files: listing both sides, downloads and uploads (binary and text),
the replace question, ESC, new folder, rename and delete, DOS 2.5's
listing.

    pip install py65 pyftpdlib
    tools/test_sim.py [-v]
"""
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim  # noqa: E402


VERBOSE = '-v' in sys.argv
USER, PASSWORD = 'ATARI', 'SECRET'
BIG = bytes((i * 7 + i // 251) & 255 for i in range(30000))
failures = []


def check(name, ok, detail=''):
    print(('ok    ' if ok else 'FAIL  ') + name + ('' if ok else '  ' + detail))
    if not ok:
        failures.append(name)


class Server:
    """pyftpdlib in a process of its own, so it doesn't wait on the
    emulator for Python's lock"""

    def __init__(self, root, port=0):
        sock = socket.socket()
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('127.0.0.1', port))
        self.port = sock.getsockname()[1]
        sock.close()
        self.proc = subprocess.Popen(
            [sys.executable, '-m', 'pyftpdlib', '-i', '127.0.0.1',
             '-p', str(self.port), '-w', '-d', root, '-u', USER, '-P', PASSWORD],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            try:
                socket.create_connection(('127.0.0.1', self.port), 1).close()
                return
            except OSError:
                time.sleep(0.1)

    def close(self):
        self.proc.terminate()
        self.proc.wait()


LAST = None     # the last run's Sim, for what the screen doesn't show


def run(keys, d1, dos='sparta'):
    global LAST
    s = LAST = sim.Sim(XEX, sim.parse_keys(keys), 0x1D00, sim.FujiNet(),
                       sim.Disks({1: d1}, dos))
    shots = []
    s.snapshot = lambda: shots.append(s.screen_text())
    s.run()
    shots.append(s.screen_text())
    if VERBOSE:
        for i, t in enumerate(shots):
            print(f'--- {i}\n{t}')
    return shots


def main():
    tmp = tempfile.mkdtemp()
    srv_root, d1 = os.path.join(tmp, 'srv'), os.path.join(tmp, 'd1')
    os.makedirs(os.path.join(srv_root, 'games'))
    os.makedirs(os.path.join(d1, 'GAMES'))
    open(os.path.join(srv_root, 'Big File.bin'), 'wb').write(BIG)
    open(os.path.join(srv_root, 'readme.txt'), 'wb').write(b'one\ntwo\tx\n')
    open(os.path.join(srv_root, 'games', 'dig.xex'), 'wb').write(b'\xff\xff12')
    open(os.path.join(d1, 'DIGDUG.XEX'), 'wb').write(BIG[:9000])
    open(os.path.join(d1, 'NOTES.TXT'), 'wb').write(b'A\x9bB\x7fC\x9b')
    server = Server(srv_root)

    try:
        site = f'^K^NTest\\n127.0.0.1\\n{server.port}\\n{USER}\\n{PASSWORD}\\n/\\n\\n  \\n'
        # make the site (By type) and connect: both panes
        shots = run(site + '\\n\\w\\s^Q', d1)
        t = shots[0]
        check('site saved', os.path.exists(os.path.join(d1, 'EFTPXL.CFG')))
        check('connected: server pane', 'games' in t and 'readme.txt' in t
              and 'Big File.bin' in t, t)
        check('Atari pane', 'DIGDUG.XEX' in t and 'GAMES' in t, t)
        check('Atari sizes in bytes', 'DIGDUG.XEX     9K' in t, t)
        check('server folder shown', '|/' in t, t)

        # download: binary byte for byte, text with EOL; the summary
        shots = run('^K\\n\\wB\\n\\w\\sr\\n\\w\\s^Q', d1)
        got = open(os.path.join(d1, 'BIGFILE.BIN'), 'rb').read() \
            if os.path.exists(os.path.join(d1, 'BIGFILE.BIN')) else b''
        check('download binary', got == BIG, f'{len(got)} bytes')
        check('download summary', '1 file, 30K' in shots[0], shots[0][:200])
        txt = open(os.path.join(d1, 'README.TXT'), 'rb').read() \
            if os.path.exists(os.path.join(d1, 'README.TXT')) else b''
        check('download text', txt == b'one\x9btwo\x7fx\x9b', repr(txt))

        # upload two marked files: binary, and text as CR LF
        shots = run('^K\\n\\w\\tD N ^T\\w\\s^Q', d1)
        up = os.path.join(srv_root, 'DIGDUG.XEX')
        check('upload binary', os.path.exists(up)
              and open(up, 'rb').read() == BIG[:9000])
        up = os.path.join(srv_root, 'NOTES.TXT')
        check('upload text', os.path.exists(up)
              and open(up, 'rb').read() == b'A\r\nB\tC\r\n')
        check('upload summary', '2 files' in shots[0], shots[0][:200])

        # the replace question, and ESC stopping a download
        shots = run('^K\\n\\wB\\n\\s\\e\\w\\s^Q', d1)
        check('replace asked', 'is there. Replace? Y/N' in shots[0], shots[0][:120])
        shots = run('^K\\n\\wB\\ny\\e\\w\\s^Q', d1)
        check('ESC stops', 'Stopped.' in shots[0], shots[0][:120])
        check('stopped file deleted',
              not os.path.exists(os.path.join(d1, 'BIGFILE.BIN')))

        # new folder, rename, delete on the Atari
        shots = run('^NNEWDIR\\n\\s^E\\b\\b\\b\\b\\b\\bOLDDIR\\n\\s'
                    'R^E\\b\\b\\bDOC\\n\\sO\\xy\\s^Q', d1)
        check('local new folder', 'NEWDIR' in shots[0], shots[0])
        check('local rename folder', 'OLDDIR' in shots[1] and 'NEWDIR' not in shots[1])
        check('local rename file', os.path.exists(os.path.join(d1, 'README.DOC')))
        check('local delete folder', not os.path.exists(os.path.join(d1, 'OLDDIR')))

        # and on the server
        shots = run('^K\\n\\w^Nnewdir\\n\\s^E\\b\\b\\b\\b\\b\\bmoved\\n\\s'
                    '\\xy\\sr\\xy\\s^Q', d1)
        check('server new folder', 'newdir' in shots[0], shots[0])
        check('server rename', os.path.isdir(os.path.join(srv_root, 'moved'))
              or 'moved' in shots[1])
        check('server delete folder', not os.path.exists(os.path.join(srv_root, 'moved')))
        check('server delete file', not os.path.exists(os.path.join(srv_root, 'readme.txt')))

        # into a folder on each side, and back
        shots = run('^K\\n\\wg\\n\\s\\b\\s\\tG\\n\\s^Q', d1)
        check('server folder in', 'dig.xex' in shots[0], shots[0])
        check('server folder out', 'Big File.bin' in shots[1], shots[1])
        check('Atari folder in', 'D1:>GAMES>' in shots[2], shots[2])

        # a folder with all in it: down, two folders deep, and up
        tree = os.path.join(srv_root, 'tree')
        os.makedirs(os.path.join(tree, 'sub', 'deep'))
        open(os.path.join(tree, 'a.txt'), 'wb').write(b'hi\n')
        open(os.path.join(tree, 'sub', 'b.bin'), 'wb').write(BIG[:3000])
        open(os.path.join(tree, 'sub', 'deep', 'c.dat'), 'wb').write(BIG[:700])
        shots = run('^K\\n\\wt^T\\w\\s^Q', d1)
        got = lambda *p: open(os.path.join(d1, *p), 'rb').read() \
            if os.path.exists(os.path.join(d1, *p)) else None
        check('folder down', got('TREE', 'A.TXT') == b'hi\x9b'
              and got('TREE', 'SUB', 'B.BIN') == BIG[:3000]
              and got('TREE', 'SUB', 'DEEP', 'C.DAT') == BIG[:700], str(os.listdir(d1)))
        check('folder down summary', '3 files' in shots[0], shots[0][:200])
        tools = os.path.join(d1, 'TOOLS')
        os.makedirs(os.path.join(tools, 'SUB'))
        open(os.path.join(tools, 'X.COM'), 'wb').write(BIG[:500])
        open(os.path.join(tools, 'SUB', 'Y.DAT'), 'wb').write(BIG[:1500])
        shots = run('^K\\n\\w\\tT^T\\w\\s^Q', d1)
        up = os.path.join(srv_root, 'TOOLS')
        check('folder up', os.path.exists(os.path.join(up, 'SUB', 'Y.DAT'))
              and open(os.path.join(up, 'X.COM'), 'rb').read() == BIG[:500]
              and open(os.path.join(up, 'SUB', 'Y.DAT'), 'rb').read() == BIG[:1500],
              shots[0][:300])
        check('panes back where they were', '|/' in shots[0] and 'D1:   ' in shots[0],
              shots[0][:300])

        # DOS 2.5: its listing, and no folders
        shots = run('^NX\\n\\s^Q', d1, dos='dos2')
        check('DOS 2.5 listing', 'DIGDUG.XEX' in shots[0], shots[0])
        check('DOS 2.5 has no folders', 'this DOS has no folders' in shots[0])
        shots = run('^K\\n\\wt^T\\w\\s^Q', d1, dos='dos2')
        check('DOS 2.5: no folder sent', 'Function not supported' in shots[0],
              shots[0][:200])

        # RESET: back to the main screen, disconnected, N1: and N2:
        # closed; then on as usual, and ^Q still back to DOS
        shots = run('^K\\n\\w\\s\\!\\w\\s\\h\\s\\e^Q', d1)
        s = LAST
        check('RESET: was connected', 'readme.txt' in shots[0] or 'games' in shots[0],
              shots[0][:200])
        check('RESET: main screen again', s.resets == 1 and 'EFTP_XL' in shots[1]
              and 'DIGDUG.XEX' in shots[1] and 'games' not in shots[1], shots[1])
        check('RESET: N1: and N2: closed', not s.fujinet.conn, str(s.fujinet.conn))
        check('RESET: keys work after', 'Keys' in shots[2], shots[2])
        check('RESET: ^Q back to DOS, DOSINI DOS\'s', s.to_dos
              and s.word(sim.DOSINI) == sim.DOSINI_TRAP, hex(s.word(sim.DOSINI)))

        # HELP: the keys, then About
        t = shots[2]
        check('About in HELP', 'EFTP_XL ' in t and 'Erez Yaary' in t
              and 'GPL-2.0-or-later' in t and 'github.com/whomper/EFTP_XL' in t, t)

        # the load check (xl's AXLOAD): MEMLO above $4000, nothing loaded
        s = sim.Sim(XEX, [], 0x4100, sim.FujiNet(), sim.Disks({1: d1}))
        s.run()
        check('load check: DOS too big', s.to_dos and b'MEMLO is above it' in s.eout
              and s.mem[0x4000] == 0, repr(bytes(s.eout)[:80]))

        # EFTPXL.CFG: SSAVE writes the note first; lines that start with
        # ; are skipped when read; 1.2's file (no note) still reads
        cfg = os.path.join(d1, 'EFTPXL.CFG')
        saved = open(cfg, 'rb').read()
        check('CFG: the note on top', saved.startswith(b'; EFTPXL.CFG - ')
              and all(len(x) <= 38 for x in saved.split(b'\x9b')
                      if x.startswith(b';')), repr(saved[:80]))
        site_line = [x for x in saved.split(b'\x9b') if x and not x.startswith(b';')][0]
        open(cfg, 'wb').write(b'; a note\x9b;\x9b' + site_line + b'\x9b; another\x9b')
        shots = run('^K\\s\\e^Q', d1)
        check('CFG: notes skipped', 'Test' in shots[0] and 'note' not in shots[0]
              and 'another' not in shots[0], shots[0])
        open(cfg, 'wb').write(site_line + b'\x9b')               # as 1.2 wrote it
        shots = run('^K\\n\\w\\s^Q', d1)
        check('CFG: 1.2\'s file still read', 'readme.txt' in shots[0] or 'games' in shots[0],
              shots[0][:200])
        open(cfg, 'wb').write(saved)

        # ESC and BREAK cancel every question, prompt and box: nothing
        # written, erased, sent or changed (the 8-bit guidelines, 3.4)
        def atari():
            return sorted(os.listdir(d1))
        cfg = os.path.join(d1, 'EFTPXL.CFG')
        before, cfg_before = atari(), open(cfg, 'rb').read()
        for key, kname in (('\\e', 'ESC'), ('\\k', 'BREAK')):
            shots = run(f'^NXYZ{key}\\s^Q', d1)
            check(f'{kname}: new folder cancelled', atari() == before, str(atari()))
            shots = run(f'D^EZZ{key}\\s^Q', d1)
            check(f'{kname}: rename cancelled', atari() == before, str(atari()))
            shots = run(f'D\\x{key}\\s^Q', d1)
            check(f'{kname}: delete Y/N is no', atari() == before, str(atari()))
            shots = run(f'\\h\\s{key}\\s^Q', d1)
            check(f'{kname}: HELP back', 'sites / disconnect' in shots[0]
                  and 'sites / disconnect' not in shots[1]
                  and 'DIGDUG.XEX' in shots[1], shots[1][:200])
            shots = run(f'^K\\s{key}\\s^Q', d1)
            check(f'{kname}: Sites back', 'Sites' in shots[0] and 'DIGDUG.XEX' in shots[1],
                  shots[1][:200])
            shots = run(f'^K^Enew{key}\\s^Q', d1)
            check(f'{kname}: site edit cancelled', open(cfg, 'rb').read() == cfg_before)
            shots = run(f'^K\\x{key}\\s^Q', d1)
            check(f'{kname}: site delete Y/N is no', open(cfg, 'rb').read() == cfg_before)
            shots = run(f'^K^Nnew{key}\\s^Q', d1)
            check(f'{kname}: new site cancelled', open(cfg, 'rb').read() == cfg_before)
            shots = run(f'^K\\n\\wB\\n{key}\\w\\s^Q', d1)
            check(f'{kname}: replace Y/N is no, the queue stopped',
                  'Stopped' in shots[0] and atari() == before, shots[0][:120])
            os.remove(os.path.join(d1, 'BIGFILE.BIN')) if 'BIGFILE.BIN' not in before \
                and os.path.exists(os.path.join(d1, 'BIGFILE.BIN')) else None
            shots = run(f'^K\\n\\w\\tD\\n\\nD\\nY{key}\\w\\s^Q', d1)
            check(f'{kname}: a transfer stopped', 'Stopped' in shots[0], shots[0][:120])
        # a site without its password: the question, cancelled
        site_line = [x for x in cfg_before.split(b'\x9b') if x and not x.startswith(b';')][0]
        f = site_line.split(b'|')
        open(cfg, 'wb').write(b'|'.join(f[:4] + [b''] + f[5:]) + b'\x9b')
        for key, kname in (('\\e', 'ESC'), ('\\k', 'BREAK')):
            shots = run(f'^K\\n\\s{key}\\w\\s^Q', d1)
            check(f'{kname}: password question cancelled', 'Password for' in shots[0]
                  and 'games' not in shots[1] and not LAST.fujinet.conn, shots[1][:200])
        open(cfg, 'wb').write(cfg_before)

        # the sites kept as their lines: edit one (the others as they
        # were, in order), add one, delete one, and no room
        shots = run('^K^N\\nb.example\\n\\n\\n\\n\\n\\n\\n^K\\d^E\\b\\b\\b\\b\\b\\b\\b\\b\\b'
                    'c.example\\n\\n\\n\\n\\n\\n\\n\\n^Q', d1)
        sites = [x for x in open(cfg, 'rb').read().split(b'\x9b') if x and not x.startswith(b';')]
        check('sites: added and edited, in order', len(sites) == 2 and sites[0] == site_line
              and sites[1].startswith(b'c.example|b.example|21|'), repr(sites))
        shots = run('^K\\d\\xy\\s^Q', d1)
        sites = [x for x in open(cfg, 'rb').read().split(b'\x9b') if x and not x.startswith(b';')]
        check('sites: one deleted', sites == [site_line], repr(sites))
        long = 'L' * 31
        shots = run(f'^K^N\\n{long}\\n\\n\\n\\n{"F" * 39}\\n{"A" * 23}\\n\\n' * 7 + '\\s^Q', d1)
        check('sites: no room for more', 'No room for this site.' in shots[0]
              or 'No room: 8 sites at most.' in shots[0], shots[0][:200])
        sites = [x for x in open(cfg, 'rb').read().split(b'\x9b') if x and not x.startswith(b';')]
        shown = run('^K\\s^Q', d1)[0].count('L' * 15)
        check('sites: what is saved reads back', sites[0] == site_line
              and 1 < len(sites) <= 8 and shown == len(sites) - 1, f'{len(sites)} {shown}')
        open(cfg, 'wb').write(cfg_before)

        # the test disk for real hardware: clean, and what the plan needs
        sys.path.insert(0, os.path.join(sim.ROOT, 'xl', 'tools'))
        import sparta
        td = os.path.join(sim.ROOT, 'bin', 'EFTPTEST.ATR')
        if os.path.exists(td):
            disk = sparta.Disk(td)
            problems, lost = disk.fsck()
            names = {p for p, e, folder in disk.walk()}
            want = {'X32G.DOS', 'EFTPXL.PRG', 'AERA.FNT', 'EFTPXL.CFG', 'TESTPLAN.TXT',
                    'TEXT.TXT', 'BIN.DAT', 'EMPTY.DAT', 'BIG.DAT', 'TREE', 'TREE>A.TXT',
                    'TREE>SUB', 'TREE>SUB>B.DAT'}
            check('test disk: clean, with its files', not problems and not lost
                  and want <= names, f'{problems} {lost} {sorted(names)}')
        else:
            check('test disk: made', False, td)

        # the font: D:AERA.FNT read into the 1K below the screen (xl's
        # AXFONT) and used, set again after RESET without reading it
        # again; without it the ROM font, with the ROM's icons
        def font_run(keys):
            disks = sim.Disks({1: d1})
            opened = []
            real_open = disks.open
            disks.open = lambda spec, a1, a2: (opened.append(spec), real_open(spec, a1, a2))[1]
            s = sim.Sim(XEX, sim.parse_keys(keys), 0x1D00, sim.FujiNet(), disks)
            seen = []
            base = lambda: s.word(0x58)
            s.snapshot = lambda: seen.append((s.mem[sim.CHBAS], bytes(s.mem[base():base() + 960])))
            s.run()
            return s, seen, [x for x in opened if 'AERA.FNT' in x.upper()]
        fnt = bytes((i * 29 + 3) & 255 for i in range(1024))
        open(os.path.join(d1, 'AERA.FNT'), 'wb').write(fnt)
        s, seen, opened = font_run('\\s\\!\\w\\s^Q')
        page = (s.mem[sim.RAMTOP] - 8) & 0xFC
        check('AERA.FNT read below the screen and used',
              bytes(s.mem[page << 8:(page << 8) + 1024]) == fnt and seen[0][0] == page,
              f'{seen[0][0]:02X} {page:02X}')
        check('AERA.FNT: its icons, folder and file', b'\x40' in seen[0][1]
              and b'\x50' in seen[0][1])
        check('RESET: the font set again, not read again',
              len(seen) == 2 and seen[1][0] == page and len(opened) == 1, f'{opened}')
        check('^Q: DOS\'s font back', s.to_dos and s.mem[sim.CHBAS] == 0xE0)
        os.remove(os.path.join(d1, 'AERA.FNT'))
        s, seen, opened = font_run('\\s^Q')
        check('no AERA.FNT: the ROM font, with its icons', seen[0][0] == 0xE0
              and b'\x7F' in seen[0][1] and b'\x40' not in seen[0][1]
              and b'\x50' not in seen[0][1])
        check('no font in the program', len(open(XEX, 'rb').read()) < 15360)

    finally:
        server.close()
        shutil.rmtree(tmp)

    print(f'{len(failures)} failed' if failures else 'all passed')
    return 1 if failures else 0


XEX = os.path.join(sim.ROOT, 'bin', 'EFTPXL.PRG')
BUILTIN = os.path.join(sim.ROOT, 'xl', 'font', 'AERA.FNT')    # make's, the same font

if __name__ == '__main__':
    sys.exit(main())
