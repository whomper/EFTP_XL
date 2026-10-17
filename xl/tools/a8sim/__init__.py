# AERA-Atari xl/tools/a8sim - an Atari 8-bit on py65, for the programs' tests
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""The real program on an emulated 6502 (the 8-bit guidelines, 8, level 1),
from EFTP_XL's tools/sim.py and EDOS's.

    from a8sim import Machine, CIO, E, K, Disks, SIO, Keys, screen_text

    m = Machine(memlo=0x1F00)                 # 64K; banks=0x6C: 130XE banks
    keys = Keys(parse_keys('^K\\nTEST\\n'))
    m.cio = CIO(e=E(), k=K(keys), d=Disks({1: 'disk'}))
    m.sio = SIO({0x70: fujinet})              # the program's own devices
    keys.install(m)
    m.run('bin/EFTPXL.PRG')                   # load as DOS does, then RUNAD
    print(screen_text(m))

    m.load('build/EDOS.COM'); m.load_symbols('build/EDOS.SYM')
    m.call('BIN2DEC', a=0x80, y=0x05)         # a routine by its name
"""
from .core import Machine, BankedMemory, Stop
from .cio import CIO, E, K, Disks, cio_name
from .sio import SIO, strict_length
from .keys import Keys, parse_keys, HELP, SHOT, WAIT, SKIP, RESET, BREAK
from .screen import screen_text, screen_png, atari_rgb, raw2png
from .fp import install_fp

__all__ = ['Machine', 'BankedMemory', 'Stop', 'CIO', 'E', 'K', 'Disks', 'cio_name', 'SIO',
           'strict_length', 'Keys', 'parse_keys', 'HELP', 'SHOT', 'WAIT', 'SKIP', 'RESET', 'BREAK',
           'screen_text', 'screen_png', 'atari_rgb', 'raw2png', 'install_fp']
