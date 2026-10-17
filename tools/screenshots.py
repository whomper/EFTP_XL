#!/usr/bin/env python3
# EFTP_XL - the README's pictures
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Take the README's screenshots: bin/EFTPXL.PRG run in tools/sim.py
against an FTP server started here (pyftpdlib), with a made-up Atari
disk and server folder, the screens drawn as the Atari shows them.

    pip install py65 pyftpdlib pillow
    tools/screenshots.py [DIR]          (docs/screens by default)
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim  # noqa: E402
from test_sim import Server, USER, PASSWORD  # noqa: E402

BLOB = bytes((i * 13 + i // 97) & 255 for i in range(260_000))


def files(root, spec):
    for path, size in spec.items():
        full = os.path.join(root, *path.split('/'))
        os.makedirs(os.path.dirname(full), exist_ok=True)
        if size is not None:
            open(full, 'wb').write(BLOB[:size])


def shots(keys, d1, out, names):
    s = sim.Sim(sim.ROOT + '/bin/EFTPXL.PRG', sim.parse_keys(keys), 0x1D00,
                sim.FujiNet(), sim.Disks({1: d1}))
    taken = []

    def snap():
        name = names[len(taken)]
        s.screen_png(os.path.join(out, name + '.png'), scale=2)
        taken.append(name)
    s.snapshot = snap
    s.run()
    assert len(taken) == len(names), f'{len(taken)} of {names}'


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(sim.ROOT, 'docs', 'screens')
    os.makedirs(out, exist_ok=True)
    tmp = tempfile.mkdtemp()
    srv, d1 = os.path.join(tmp, 'AtariShare'), os.path.join(tmp, 'd1')
    files(srv, {'games/Star Raiders.xex': 8200, 'games/Dig Dug.xex': 16100,
                'games/Boulder Dash.xex': 12300, 'music/demos/Sweet.sap': 4100,
                'music/demos/Lasermania.sap': 6800, 'music/Komodo.sap': 5300,
                'STinG 1.26.zip': 249_856, 'Mac Cheats.txt': 2300,
                'readme.txt': 900, 'EDOS30.atr': 92_176})
    files(d1, {'GAMES/RIVRAID.XEX': 8192, 'DOWNLOAD/X': None, 'EDOS.COM': 11_900,
               'EDOS.FNT': 1024, 'DIGDUG.XEX': 16_100, 'NOTES.TXT': 610,
               'AUTORUN.SYS': 1800})
    # the family font, as on a real disk: without it the simulator's
    # (empty) ROM font would draw nothing but the icons
    shutil.copy(os.path.join(sim.ROOT, 'xl', 'font', 'AERA.FNT'), d1)
    server = Server(srv, 2121)
    try:
        site = (f'^K^NMac\\n127.0.0.1\\n{server.port}\\n{USER}\\n{PASSWORD}\\n/\\n'
                'D1:>DOWNLOAD>\\n  \\n')
        # the sites, and connected
        shots(site + '\\s\\n\\w\\s^Q', d1, out, ['2-sites', '1-main'])
        # a file going down (a third of it), and the sums after
        shots('^K\\n\\wS\\n' + '\\z' * 160 + '\\s\\w\\s^Q', d1, out,
              ['3-sending', '4-sent'])
        # a folder with folders in it going down
        shots('^K\\n\\wm^T' + '\\z' * 3 + '\\s\\w\\s^Q', d1, out,
              ['5-folder', '6-folder-sent'])
        # the keys
        shots('\\h\\s^Q', d1, out, ['7-keys'])
    finally:
        server.close()
        shutil.rmtree(tmp)
    print('\n'.join(sorted(os.listdir(out))))


if __name__ == '__main__':
    main()
