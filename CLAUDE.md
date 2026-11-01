# Notes for working on EFTP_XL

- **Releases carry the program.** `bin/` and `dist/` are build output,
  never committed. `VERSION` in `ASM/EFTPXL.M65` holds the last release
  (every build shows `x.y`; there is no -dev label). A release:
  raise `VERSION` and the version in every source file's header,
  commit, push, then run the Release
  workflow on main with the notes; `.github/workflows/release.yml`
  (xl's) runs `make test` and `make dist`, tags vX.Y and publishes
  `EFTPXL.COM`, the disk `EFTPXL.ATR` (the sources and the program, so
  not `-SRC`; always this name), `AERA.FNT` and `EFTPTEST.ATR` (the
  test disk, with docs/TESTPLAN.TXT). Never reuse a number.
- **Talking with Erez.** No progress or in-between messages: write to
  him when he has to decide something, with a short context and the
  decision. Findings: the information, your assessment, what he should
  do. Messages to the hub stay complete, with the evidence.
  **Who decides what** (Erez, 2026-10-31; the guidelines' "Who
  decides what"). Erez's part, put to him before the work as a
  decision with a short context:
  - new programs and ideas, their core capabilities, and how they
    work with the other programs;
  - the user experience: the look, the layout, the way through a
    task, the words, the icons, the defaults;
  - phases: work stays inside the phase he approved; at its end, one
    phase report (what it set out to do, what was done with the
    release links, what is left, the next phase as a proposal), and
    the next phase starts when he says so;
  - priorities and conflicts between programs or sessions (through
    the hub, with its options and recommendation);
  - packages on the Pi and ports.

  How it is made is the team's, without asking: code, structure,
  shared code, tests, measurements, fixes, docs and releases inside
  an approved phase.
- **Push to `main` without asking** (Erez, 2026-10-18), once `make
  test` passes. A change to the docs alone (README, docs/, CLAUDE.md)
  takes the short path: pushed once it reads right, without `make
  test`.
- **Release without asking** (Erez, 2026-10-23; XL guidelines 1.2).
  When work on `main` is ready, release it as soon as its checks pass
  (`make test`, and the atari800 runs the README's Tests describe):
  don't wait for a yes, and don't collect work for a later release.
  After it, give Erez the link in one line, with anything he has to
  do, and send the hub the link. Roll back a bad release the same
  way, without asking. Erez's part ("Who decides what", above) still
  goes to him before the work; the release itself is not part of it. A
  change to the docs alone needs no release of its own: it goes out
  with the next one.
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

## Maintenance mode (Erez, 1 Nov 2026)

EFTP_XL is in maintenance mode while EWeb, EPDF and EPlay go to 1.0 (AERA-Atari, ATARI-XL-GUIDELINES.md, section 10). Until Erez ends it:
- No new features, speed rounds, clean-ups, or catching up with new or changed guidelines.
- No sync of the shared code (`xl/`). Shared code moving is no reason to rebuild or release.
- A release only for:
  - a security or data-loss fault;
  - a crash or breakage Erez reports;
  - something outside that stops it working (a server).

  Such a release takes only that fix (one change from AERA-Atari, not a sync), and its notes say why.
- Work on `main` that isn't released stays unreleased.
- Nothing runs in the background; the session waits for Erez or the hub.
- Only Erez's explicit word ends this mode, for instance that every program is to take the latest shared code and release. The hub passes it on quoting him.
