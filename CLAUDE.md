# Notes for working on EFTP_XL

- **Releases carry the program.** `bin/` and `dist/` are build output,
  never committed. `VERSION` in `ASM/EFTPXL.ASM` holds the last release
  (every build shows `x.y`; there is no -dev label). A release:
  raise `VERSION`, commit, push, then run the Release workflow on main
  with the notes; `.github/workflows/release.yml` builds ATasm at
  `ATASM_REV` and the program, tags vX.Y and publishes `EFTPXL.XEX` and
  the source disks. Never reuse a number.
- **Only formal releases leave the build machine.** Erez gets vX.Y
  releases made by the Release workflow from `main`, nothing else: no
  test builds, no CI artifacts, no builds from a branch. Work lands on
  `main`; to try a fix on real hardware, release it. If a release
  doesn't work, roll back with a release: revert on `main`, release the
  next number, and say in the bad release's notes that it is withdrawn
  and which one to use.
- **The program is Mac/65 source** in `ASM/`, built here with ATasm
  (`-mac65`) and on the Atari with Mac/65. Keep to what both take:
  labels of letters and digits only, unique across all files (no
  `.LOCAL`, no `?` labels); `*=*+n` for room, never `.DS`; no `.INCBIN`,
  `.REPT`, `%%`, `<<`; `[ ]` around an expression after `<` or `>`;
  only `EFTPXL.ASM` has `.INCLUDE #D:NAME.M65` lines; no TAB or `{ } ~ \``
  (not ATASCII); a file stays under about 14K as `tools/atari_src.py`
  writes it, so Mac/65 can ENTER it. `make atr` checks the disks give
  the same program. The C version in `C/` is kept for reference only.
- **Test** with `make test` (tools/test_sim.py, the real XEX on py65
  against pyftpdlib): all 26 checks pass before a push.
- **The name** reads "AERA | Erez Yaary" wherever it is given: copyright
  lines (`Copyright (C) 2026 AERA | Erez Yaary`), the docs, and as the
  author of every commit:
  `git commit --author="AERA | Erez Yaary <yaary@me.com>"`, with Claude as
  the signing committer (AERA-Atari, `standards/GITHUB-IDENTITY.md`).
