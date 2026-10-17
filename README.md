# xl: the AERA 8-bit shared code and tools

What the Atari 400/800/XL/XE programs share: EDOS, EFTP_XL and those after them. It is to
them what `common/` is to the ST apps. The rules it serves are in
[`standards/ATARI-XL-GUIDELINES.md`](../standards/ATARI-XL-GUIDELINES.md).

- **Where it lives:** here, in AERA-Atari, published as the `xl` branch on every push to main
  (`.github/workflows/publish-xl.yml`, after the tests pass).
- **How a program carries it:** as `xl/`, read-only. Change it here, never in a program's copy.
- **Taking it in:** copy [`sync-xl.sh`](sync-xl.sh) to the program's `tools/`. The first time:

  ```sh
  git subtree add --prefix=xl https://github.com/whomper/AERA-Atari xl --squash
  ```

  After that, `tools/sync-xl.sh`. It also copies the release and withdraw workflows to
  `.github/workflows/`.

## The shared includes (`src/`)

MAC/65 has no linker, so a program includes only the files it uses, after its own equates. The
main file lists them (`.INCLUDE #D:AXLOAD.M65`), and the program's disk carries them next to its
own files.

All shared labels start with `AX` and are at most 8 characters long. A shared file has no zero
page of its own: the program lends it some by name (`AXPTR = PTR`), defined before the include,
as MAC/65's two passes need. No shared file includes another.

| File | What it does | Before the include | Bytes |
|---|---|---|---|
| `AXEQU.M65` | The OS's addresses under the Atari's own names (DOSINI, ICCOM, CIOV ...), CIO's commands and modes as `AXOPEN`, `AXGETCHR`, `AXOPNIN` ..., the family's colours. Include it first. | | 0 |
| `AXLOAD.M65` | The load check (4.2): an init segment that refuses to load over DOS or past MEMTOP, says why on E: and goes back to DOS | `AXLOW`, `AXHIGH`, `*=` where it goes, the messages `AXLOWM` and `AXROOMM` | 64, used once |
| `AXRESET.M65` | RESET back into the program (3.3): `AXSTART` at the start, `AXQUIT` before every way out; RESET runs DOS's init, then `AXWARM` | `AXWARM` | 48 |
| `AXFONT.M65` | `AXFONT`: D:AERA.FNT to the page in A, through the IOCB in X; C=0 when read | | 70 |
| `AXERR.M65` | `AXERRT`: the text of CIO error Y, at A/Y; C=1 when there is none | `AXPTR`; `AXERRS` 1 (CIO's 128-147) or 2 (and DOS's 160-171) | 53 + texts |

## The tools (`tools/`)

| Tool | What it does |
|---|---|
| `mac65.py` | The cross assembler. It makes the same program as MAC/65 1.01, byte for byte: EDOS 3.2 and EFTP_XL 1.1 build as released. It takes files with and without line numbers, and `[ ]`. It fails where MAC/65 would: a zero-page name used before it is defined, a `.IF` on a later name, a nested include. |
| `mac65tok.py` | MAC/65's tokenised SAVE format, both ways, checked against files MAC/65 1.01 saved |
| `atari_src.py` | The sources between git and the Atari (2.1). `disk` makes the bootable SpartaDOS disk: numbered, tokenised, the headers and sizes checked. `check --to` and `import` bring an Atari file back without its numbers, with the layout of every unchanged line kept. `layout` puts numbered sources into git's form once, for a program moving over. |
| `sparta.py`, `atr.py` | SpartaDOS and DOS 2 / MyDOS disk images: list, add, remove, check |
| `font.py` | `AERA.FNT`, from Erez's `font/EREZ.FNT`: as a file, or as `.BYTE` lines for a program that carries it |
| `disk/` | SpartaDOS 3.2's boot sectors and `X32G.DOS`, for the bootable disks |
| `atari800/` | The release checks in atari800 with its own OS ROM (guidelines 8, level 2), from EFTP_XL's build machine. `build.sh DIR` builds `a8run`, which drives libatari800 from a script. `a8check.py start` checks that the disk boots and the program starts. `a8check.py mac65` checks that MAC/65 on the Atari assembles the disk's sources to the same program; it needs Erez's MAC/65 cartridge image, which never goes in git. |
| `mac65real/` | The real MAC/65 1.01 cartridge on py65, no OS ROM needed (EDOS's): `asm.py CAR SRCDIR RUNDIR MEMLO 'LOAD #D:MAIN.M65' 'ASM ,,#D:OUT'`, with the 091M banking, a small CIO (E:, K:, D: as a folder) and the OS floating point MAC/65 calls (`fp.py`). Lighter than atari800; the same cartridge image, never in git. |
| `a8sim/` | The real program on an emulated 6502 (py65), from EFTP_XL's and EDOS's simulators. `Machine` has 64K or 130XE banks, a binary load with INITAD, `call('LABEL')` by mac65.py's symbols, traps and watchers, and RESET as the OS's warm start. `CIO` follows CIO's rules, with `E`, `K` and `Disks` (host folders, both DOS listings, XIO). `SIO` dispatches by DDEVIC to the program's own devices. `Keys` runs the key script; `screen_text`, `screen_png` and `raw2png` draw in the README palette; `install_fp` gives the FP ROM for whole numbers. |

## The workflows (`workflows/`)

`release.yml` and `withdraw.yml`, the same for every 8-bit program. `tools/sync-xl.sh` copies them
into place. The release asks the program's Makefile for three targets:
- `make version`: the version, x.y;
- `make test`;
- `make dist`: the files go in `dist/`.

## Tests

```sh
pip install -r xl/requirements.txt
python3 xl/tests/test_tools.py    # the assembler, the tokeniser, the disk, the font
python3 xl/tests/test_ax.py       # the AX includes on py65, with CIO and DOS stood in
python3 xl/tests/test_sim.py      # a8sim: SIMTEST.M65 through E:, K:, D:, both listings,
                                  # a CIO error, RESET, the load check; symbols, banks, SIO
xl/tests/test_atari800.sh DIR     # end to end in atari800: HELLO.M65 boots and runs on
                                  # SpartaDOS 3.2; built too low, AXLOAD refuses it
```

Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see [COPYING](../COPYING). SpartaDOS 3.2
(`tools/disk/`) is the work of its authors, carried as EDOS and EFTP_XL carry it.
