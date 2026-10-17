# AERA-Atari xl/tools/mac65real - from EDOS (tools/run65), as EDOS sent it
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Assemble with the real MAC/65 cartridge on py65 (pip install py65).

    asm.py CAR SRCDIR RUNDIR MEMLO 'COMMAND' ['COMMAND' ...]

CAR is Erez's MAC/65 1.01 image (MAC_65_1.01_with_DDT.car, CAR type 15,
16,400 bytes); it never goes in git. SRCDIR holds the D: files (MAC/65
tokenized sources, as atari_src.py puts them on the disk); it is copied to
RUNDIR, where MAC/65 reads and writes. MEMLO is hex (DOS's MEMLO, e.g.
17A2). Each COMMAND is one line typed at MAC/65's Edit prompt. Set SPARTA=1
for SpartaDOS NOTE/POINT (24-bit position in ICAX3-5); otherwise DOS 2 style
(sector/byte). Prints the screen and the files left in RUNDIR. MAC/65 writes
~252-byte segments, so compare memory images (xl/tools/atari800/a8check.py's
same_load), not files.

    SPARTA=1 python3 asm.py CAR SRCDIR RUNDIR 17A2 'LOAD #D:EDOS.M65' 'ASM ,,#D:EDOS.COM'

An OS address it doesn't handle stops the run; xl/tools/atari800 is the
fuller check."""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run65

car, src, rd, memlo, cmds = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4], 16), sys.argv[5:]
shutil.rmtree(rd, ignore_errors=True)
shutil.copytree(src, rd)
rom = open(car, 'rb').read()[16:]                 # skip the 16-byte CAR header
a = run65.Atari(rom, rd, cmds, memlo=memlo)
init = a.m[0xBFFE] | a.m[0xBFFF] << 8
start = a.m[0xBFFA] | a.m[0xBFFB] << 8
t, n = time.time(), 0
a.call(init, 200000)
a.cpu.pc = start
try:
    c = a.cpu
    while n < 2_000_000_000:
        if c.pc < 0x100:
            raise run65.Stop('jump to zero page')
        n += 1
        if a.step_trap():
            continue
        c.step()
except run65.Stop as e:
    print('stopped:', e)                          # 'no more input' = all commands done
print('instructions %d, %.0fs, fp %s, unknown %s' % (n, time.time() - t, a.fpcalls, a.unknown[:5]))
print(run65.screen_text(a.screen))
for f in sorted(os.listdir(rd)):
    print(f, os.path.getsize(os.path.join(rd, f)))
