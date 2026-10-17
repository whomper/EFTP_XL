# Notes for working on EFTP_XL

- **Releases carry the program.** `bin/` and `dist/` are build output,
  never committed. `VERSION` in `ASM/EFTPXL.M65` holds the last release
  (every build shows `x.y`; there is no -dev label). A release:
  raise `VERSION` and the version in every source file's header,
  commit, push, then run the Release
  workflow on main with the notes; `.github/workflows/release.yml`
  (xl's) runs `make test` and `make dist`, tags vX.Y and publishes
  `EFTPXL.PRG`, the disk `EFTPXL.ATR` (the sources and the program, so
  not `-SRC`; always this name), `AERA.FNT` and `EFTPTEST.ATR` (the
  test disk, with docs/TESTPLAN.TXT). Never reuse a number.
- **Only formal releases leave the build machine.** Erez gets vX.Y
  releases made by the Release workflow from `main`, nothing else: no
  test builds, no CI artifacts, no builds from a branch. Work lands on
  `main`; to try a fix on real hardware, release it. If a release
  doesn't work, roll back with a release: revert on `main`, release the
  next number, and run the Withdraw workflow
  (`.github/workflows/withdraw.yml`) on the bad ones: it puts a
  "Withdrawn: use vX.Y" notice at the top of their notes.
- **xl/ is the AERA 8-bit shared code and tools** (AERA-Atari, the
  `xl` branch; the rules are AERA-Atari's
  `standards/ATARI-XL-GUIDELINES.md`). It is read-only here: change it
  in AERA-Atari and bring it in with `tools/sync-xl.sh` (commit as
  AERA, as always). Something in xl/ that doesn't fit: tell the hub,
  don't change the copy.
- **The program is Mac/65 source** in `ASM/` (NAME.M65, no line
  numbers in git), built here with `xl/tools/mac65.py` and on the
  Atari with MAC/65 1.01; both give the same bytes. The main file
  `EFTPXL.M65` is the only one with `.INCLUDE #D:NAME.M65` lines, its
  own files and xl's `AX*.M65` (AXEQU first). Labels of letters and
  digits, unique across all files; `*=*+n` for room; `[ ]` around an
  expression after `<` or `>`; a zero-page name defined before it is
  used; no TAB or `{ } ~ \`` (not ATASCII). `make atr` makes the disk
  (`xl/tools/atari_src.py`: numbered and tokenized, headers and sizes
  checked) and checks it gives the same program.
- **Comments** in the sources are short, in the usual Atari way: each
  file starts with the header `; NAME.M65 - EFTP_XL x.y`, a line on
  what is in it and the copyright line (`make atr` checks the name and
  version); each routine has a few lines on what it does, its inputs
  and `Exit:`; short end-of-line comments where the code doesn't say it
  itself. Comment lines fit 38 columns.
- **Test** with `make test` (xl's tests, then tools/test_sim.py: the real program on py65
  against pyftpdlib): all its checks pass before a push.
- **The README's pictures** are the real program in tools/sim.py:
  `tools/screenshots.py` takes them again (docs/screens); take them
  again when the screens change. 8 and 9 are from atari800.
- **The name** reads "AERA | Erez Yaary" wherever it is given: copyright
  lines (`Copyright (C) 2026 AERA | Erez Yaary`), the docs, and as the
  author of every commit:
  `git commit --author="AERA | Erez Yaary <yaary@me.com>"`, with Claude as
  the signing committer (AERA-Atari, `standards/GITHUB-IDENTITY.md`).
