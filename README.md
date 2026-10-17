# EFTP_XL

File transfer for 8-bit Atari computers (400/800/XL/XE) over
[FujiNet](https://fujinet.online), written in 6502 assembly for Mac/65,
so it can be built on the Atari as well. Connects to any FTP server (a
Mac, a NAS, a Linux box) and moves files between it and your Atari
drives.

## Highlights

The full-screen program, after EFTP on the ST, in the AERA font and
colours: the Atari on the left, the server on the right, the
transfers below.

| | |
|---|---|
| ![Connected: the Atari's folder and the server's](docs/screens/1-main.png) | ![A file coming down](docs/screens/3-sending.png) |
| Connected: the Atari's folder and the server's | A file coming down: the bar, the speed |
| ![A folder going, with all in it](docs/screens/5-folder.png) | ![The sites](docs/screens/2-sites.png) |
| A folder coming down with all in it, one file after the other | The sites, saved in `EFTPXL.CFG` |

- Log in to any FTP server with your user and password, over FujiNet
- Two panes: the Atari (D1:-D8:, SpartaDOS folders) and the server
- Files both ways, marked ones one after the other, with progress,
  speed, ESC to stop, and text line ends changed when you want
- Folders both ways, with everything in them
- New folder, rename, delete, on both sides
- Sites, saved on the disk
- RESET comes back to the main screen (disconnected), never to DOS
- Works with DOS 2.5 and SpartaDOS 3.x; all file access goes through
  CIO, so any CIO-compatible DOS should work

The pictures are of the real program, run by `tools/sim.py` (see
[Tests](#tests)); `tools/screenshots.py` takes them again. The first
design is in [docs/design](docs/design).

## Getting started

1. Get `EFTPXL.PRG` and `AERA.FNT` from the
   [latest release](https://github.com/whomper/EFTP_XL/releases) onto a
   disk the Atari can read, e.g. an ATR on the FujiNet SD card or a TNFS
   share. `EFTPXL.ATR`, also in the release, is a bootable SpartaDOS 3.2
   disk with both on it (and the sources).
2. Load it: `L` from the DOS 2.5 menu, or type `EFTPXL.PRG` at the
   SpartaDOS prompt.
3. Press ^K for the sites, ^N to add one: a name, the server (IP address
   or name), port (21 unless your server uses another), user and
   password, the folder on the server to start in, and the folder on the
   Atari (e.g. `D1:>DOWNLOAD>`). RETURN on a site connects.

**The font.** `AERA.FNT` is the font the AERA 8-bit programs share. It
isn't in the program: when it is on the drive (and SpartaDOS folder)
you start EFTP_XL from, EFTP_XL reads it into the 1K just below the
screen, as EDOS does, and uses its icons: a folder, a file, the "..."
of a name cut short and the empty part of a progress bar. Without it
EFTP_XL runs in the Atari's own font, with characters of that font for
the icons: a folder is `▶`, the "..." is `→`, a file has none and the
bar is drawn with `─`.

The screen, after EFTP: the Atari on the left, the server on the right,
the folder you are in above each, and the pane with the keyboard has its
header in inverse. Under the panes is the full name, size and date of the
file under the cursor, then the transfers.

| Key            | Does                                    |
|----------------|-----------------------------------------|
| ^K / ^D        | the sites (connect) / disconnect        |
| RETURN         | open the folder, send the file          |
| ^T             | send the marked files and folders, or the one under the cursor |
| ESC (or BREAK) | stop the transfer; cancel any question, typed name or box, as "no": nothing is changed |
| BACKSPACE      | the folder up                           |
| TAB            | the other pane                          |
| ↑ ↓ (or - =)   | move; ← → (or + \*) a page              |
| A-Z            | the next name starting with the letter  |
| SPACE / ^A     | mark and move on / mark all the files   |
| 1-8            | drive D1:-D8: (in the Atari pane)       |
| ^N             | new folder                              |
| ^E             | rename                                  |
| DEL            | delete (the marked ones, or the one under the cursor) |
| ^R             | read both lists again                   |
| HELP (or ?)    | the keys, and what EFTP_XL is           |
| RESET          | back to the main screen, disconnected   |
| ^Q             | quit to DOS                             |

The keys are EFTP's; HELP shows them:

![The keys](docs/screens/7-keys.png)

**New folder, rename, delete.** ^N asks for a folder's name, ^E for a
new name (the old one to change), and DEL deletes the marked files and
folders, or the one under the cursor, after "Delete ...? Y/N". On the
server they are FTP's MKD, RNFR/RNTO, DELE and RMD; on the Atari the
DOS's XIO: rename (32) and delete (33) on any DOS, new folder (42) and
removing one (43) on SpartaDOS; DOS 2.5 has no folders, and EFTP_XL says
so. A folder has to be empty to be deleted, as DOS and FTP want. DEL is
Shift+Delete (or Ctrl+Delete).

**Sending files.** RETURN on a file sends it to the other side; mark
several with SPACE (or ^A for all) and ^T sends them, one after the
other. The transfers area shows them (Done, Waiting, a progress bar for
the one going), the info line the speed, and at the end "3 files, 260K
in 0:42 (6K/s)". ESC stops; a file stopped on its way to the Atari is
deleted rather than left half there.

![After: how many, how much, how fast](docs/screens/4-sent.png)

**Sending folders.** Mark a folder with SPACE (or put the cursor on it)
and ^T sends it with everything in it, folders in folders too (8 deep
at most). It is made on the other side, or gone into when it is there
already; files already there are asked about, as at the top. Going to
the Atari, a folder gets an 8.3 name as files do, which needs
SpartaDOS: DOS 2.5 has no folders. The summary counts the files.

![A folder sent: MUSIC and the folder in it, 3 files](docs/screens/6-folder-sent.png)

- A file coming to the Atari gets a name DOS takes: up to 8 letters and
  digits and 3 for the extension, in capitals (`STinG 1.26.zip` becomes
  `STING126.ZIP`). Atari names go to the server as they are.
- When the file is already there, EFTP_XL asks before replacing it.
- The site's **Files** setting: *Binary* sends every byte as it is;
  *Text* changes the line ends (CR LF on the server, EOL on the Atari,
  and the TAB character); *By type* does that for EFTP's text types (TXT,
  ASC, DOC, ME, NFO, DIZ, HTM, HTML, INF) and LST, and sends the rest as
  binary.
- On DOS 2.5 a file's size is counted in sectors, so the size shown for
  an Atari file (and its progress) is close, not exact. SpartaDOS gives
  the size in bytes, and its folders.

Notes:

- `EFTPXL.CFG` is on the drive (and SpartaDOS folder) you run EFTP_XL
  from, one line per site. A password saved there is plain text: leave it
  blank and EFTP_XL asks for it each time you connect.
- Usernames, passwords and paths are case-sensitive. The Atari keyboard
  starts in uppercase; press **CAPS** to switch to lowercase.
- A blank user logs in as `anonymous`.
- On an error the info line says what went wrong: the server's own
  reply (`530 Login incorrect`), or the Atari's own error with its text
  (`NOTES.TXT: Disk full`).
- The program takes `$4000`-`$94A6` (the program and its variables),
  and the font the 1K just below the screen (`$9800` with BASIC on):
  above EDOS and the MEMLO of DOS 2.5 and SpartaDOS 3, so BASIC can
  stay on. If a DOS's MEMLO is above `$4000`, or there isn't room for
  both, the program says so and goes back to DOS before loading itself.
- `EFTPXL.CFG` starts with a note on what it is; lines that start with
  `;` are notes, and EFTP_XL skips them. It holds up to 8 sites, as
  long as their lines fit in 640 bytes (about 80 each).

## How it reaches the servers

EFTP_XL has its own FTP client. It talks to the server over plain FujiNet
TCP connections (`N1:` for commands, `N2:` for data in passive mode), so it
works on FujiNet firmware 1.3 and later and logs in with your username and
password. FujiNet's built-in FTP protocol is not used: up to firmware 1.6.1
it always logs in as `anonymous` on port 21.

Any standard FTP server with passive mode works; tested with pure-ftpd and
pyftpdlib. On a Mac, pure-ftpd from Homebrew is a good choice. For a quick
test, pyftpdlib:

```sh
python3 -m venv ~/eftp-venv
~/eftp-venv/bin/pip install pyftpdlib
mkdir -p ~/AtariShare
~/eftp-venv/bin/python -m pyftpdlib -p 2121 -w -d ~/AtariShare -u ATARI -P SECRET
```

FTP is unencrypted: the user, the password and the files go across in
plain text, so only use it on your home network.

## Building

The program is 6502 assembly in Mac/65's form, in [ASM](ASM):
`EFTPXL.M65` is the main file and includes the others. It is 14.6K (the
font is `AERA.FNT`, read when it is there); the first version, in C with
cc65, was 27K (it is in the git history, up to v0.2).

**On another computer** with Python 3. The cross-assembler is
`xl/tools/mac65.py`, from the AERA 8-bit shared tools (`xl/`, below),
which makes the same program as Mac/65 1.01, byte for byte:

```sh
git clone https://github.com/whomper/EFTP_XL
cd EFTP_XL
pip install -r xl/requirements.txt -r requirements.txt
make            # bin/EFTPXL.PRG
make atr        # bin/EFTPXL.ATR: the disk, with the sources for the Atari
make test       # all the checks (Tests, below)
make dist       # a release's files in dist/
```

`bin/` and `dist/` are what make builds; they are never committed.

**On the Atari** with Mac/65. `EFTPXL.ATR` is a SpartaDOS double density
disk that boots SpartaDOS 3.2 and holds the program, `AERA.FNT` and the
sources in Mac/65's own tokenized form, with line numbers (`.M65`, as
its SAVE writes them), ready to LOAD: EFTP_XL's own files and the
shared `AX*.M65` it includes. A release has this disk.

1. Boot the disk in D1: with the Mac/65 cartridge in (`EFTPXL.PRG` at
   the SpartaDOS prompt runs the program; `CAR` goes to Mac/65). Mac/65's
   `D:` is D1:; to work from another disk, copy the files to D1:'s
   current folder.
2. In Mac/65:

   ```
   LOAD #D:EFTPXL.M65
   ASM ,,#D:EFTPXL.PRG
   ```

   This makes `EFTPXL.PRG`, the program, over the one on the disk: the
   same bytes as the release's, in Mac/65's smaller segments.
   `EFTPXL.M65` is the main file; Mac/65 reads the parts it includes
   from `D:` as it assembles. Load the main file first and give no
   source to `ASM`: on SpartaDOS, Mac/65 1.01 can't assemble a main
   file read from disk (as EDOS found). With SpartaDOS 3.2 it reports
   `ASSEMBLY ERRORS: 0` with about 14K free. Write the program over
   `EFTPXL.PRG` (or to another disk): the disk has no room for a second
   copy.

| | |
|---|---|
| ![The source disk, booted](docs/screens/8-spartados.png) | ![MAC/65 1.01 building EFTP_XL](docs/screens/9-mac65.png) |
| The source disk booted: SpartaDOS 3.2, the sources, the program | MAC/65 1.01 building EFTP_XL from it |

These two are from the atari800 emulator, running SpartaDOS 3.2 from
the disk and the MAC/65 1.01 cartridge.

Each `.M65` can be LOADed to read or change it, and SAVEd back;
`xl/tools/atari_src.py import` brings a file saved on the Atari back
into git's form, without the line numbers. `make atr` writes the disk
with `xl/tools/atari_src.py`: the files are the same, byte for byte, as
Mac/65 1.01 saves after ENTERing the text, and `make atr` checks that
the sources on the disk give the same program. That was also checked by
running the cartridge in the atari800 emulator; the cartridge isn't in
this repository.

## Source

```
ASM/        the program: EFTPXL.M65, the main file, and its parts
xl/         the AERA 8-bit shared code and tools, from AERA-Atari
            (read-only here; tools/sync-xl.sh brings it up to date)
  src/      AX*.M65: the OS's names, RESET, AERA.FNT, CIO's error texts
  tools/    mac65.py (the assembler), atari_src.py (the disk), font.py,
            a8sim (the simulator), atari800/ (the checks in atari800)
  workflows/ release.yml and withdraw.yml, copied to .github/workflows
tools/      sim.py (the program on xl's a8sim), fujinet.py (its FujiNet),
            test_sim.py, screenshots.py, sync-xl.sh
docs/       the pictures, the first design
```

The source keeps to what Mac/65 1.01 takes: labels of letters and
digits, `*=*+n` for room (no `.DS`), no `.INCBIN`, `[ ]` around
expressions, one level of `.INCLUDE`, and a zero-page name defined
before it is used. Each file starts with a header naming it and the
version; each routine has a few lines on what it
does, what it takes and what it gives back.

## Tests

**The program on an emulated 6502.** `tools/sim.py` runs the real
`bin/EFTPXL.PRG` on xl's `a8sim` (`xl/tools/a8sim`, on
[py65](https://github.com/mnaberez/py65)), the simulator EDOS's tests
use too, with EFTP_XL's FujiNet (`tools/fujinet.py`). It stands in for
the OS calls the program makes: the
screen (read from screen memory), the keyboard (typed from a script),
RESET, the disks (D1:, D2: are folders here, through CIO, listed as
SpartaDOS 3 or DOS 2.5 list them) and SIO as a FujiNet whose `N1:`/`N2:`
TCP connections are real sockets, taking only the frame lengths a real
FujiNet takes. So the program's FTP client talks to a real server:

```sh
make && tools/sim.py --d1 disk --shots shot '^K^NTest\n192.168.1.20\n21\nATARI\nSECRET\n/\n\n\n\n\s'
```

The keys are what you would type (`\n` RETURN, `\e` ESC, `\t` TAB, `\b`
BACKSPACE, `\u` `\d` up and down, `\h` HELP, `\!` RESET, `^K` Ctrl+K);
`\s` takes a snapshot (the screen as text, and `shot-N.png` as the Atari
shows it), `\w` waits for a transfer to end and `\z` lets one block of
it go by. `--dos dos2` lists D1: as DOS 2.5 does, and `--sio-log` shows
every FTP command sent.

**The checks.** `make test` runs xl's own tests, then
`tools/test_sim.py`: the program that way against an FTP server it
starts, looking at the screen, at memory and at the files on both
sides, 75 checks:

| | |
|---|---|
| Sites | a site made and saved in `EFTPXL.CFG`, the note on top, notes skipped, 1.2's file read; edited, added, deleted in order; no room; connecting |
| Panes | both lists, sizes in bytes, the server's folder, into and out of folders on both sides |
| Files | down and up byte for byte, binary and text (line ends changed), the sums; the replace question; ESC stops and leaves no half file |
| Folders | a server folder two folders deep down to the Atari, an Atari folder with one in it up to the server, both panes back where they were |
| New, rename, delete | folders and files on the Atari and on the server |
| DOS 2.5 | its listing; no folders made, none sent, and the error's text |
| RESET | back to the main screen, disconnected, `N1:` and `N2:` closed, the keys working; ^Q still back to DOS |
| HELP, the font | the About lines; `AERA.FNT` read below the screen and its icons used, set again after RESET without reading it again, DOS's font back on quit; without it the ROM font and its icons; no font in the program |
| ESC and BREAK | each cancels as "no": new folder, rename, delete, HELP, the Sites screen, a site's edit, delete and new, the replace question, the password question; each stops a transfer |
| The test disk | `EFTPTEST.ATR` clean, with the files the test plan needs |
| Loading | the load check refuses a DOS whose MEMLO is above $4000, says so and goes back to DOS |

CI (`.github/workflows/ci.yml`) builds the program and the disk
(checking the disk gives the same program) and runs these on every
push.

**With the Atari's own software.** Before a release the program also
runs in the [atari800](https://atari800.github.io) emulator (its
library, driven by a script), with the Atari's own OS and DOS instead
of stand-ins: SpartaDOS 3.2 booted from `EFTPXL.ATR`, EFTP_XL run
from its prompt and RESET pressed, and the MAC/65 1.01 cartridge
assembling the disk's sources. That is how the SpartaDOS directory fixed
in 0.6 was found. The cartridge isn't in this repository, so this isn't
part of CI.

**On real hardware.** `EFTPTEST.ATR`, in each release, is a bootable
SpartaDOS 3.2 disk with the program, `AERA.FNT`, a site to fill in
(`PI_IP`), the files to send (text, binary, empty, 64K, a folder with a
folder in it) and `TESTPLAN.TXT`, the test plan in 38 columns: `TYPE
TESTPLAN.TXT` on the Atari. Its source is
[docs/TESTPLAN.TXT](docs/TESTPLAN.TXT). Each release says whether it has
been tried.

## Releases

`VERSION` in `ASM/EFTPXL.M65` holds the last release, and every build
shows it at startup (there is no `-dev` label); every source file's
header repeats it. Only releases leave the build machine. To release:
raise the version, commit and push, then run the Release workflow
(Actions > Release > Run workflow, on main) with what is new:
[`.github/workflows/release.yml`](.github/workflows/release.yml) (the
AERA 8-bit one, from `xl/`) runs `make test` and `make dist`, tags the
commit `vX.Y` and publishes `EFTPXL.PRG`, `EFTPXL.ATR`, `AERA.FNT` and
`EFTPTEST.ATR` as
a GitHub Release, marked Latest. Pushing a tag made with `git tag -a`
does the same, with the tag's message as the notes. A release that must
not be used is marked with the Withdraw workflow
([`.github/workflows/withdraw.yml`](.github/workflows/withdraw.yml)):
a notice at the top of its notes names the release to use instead.

## Licence

EFTP_XL is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation, either version 2 of the License, or (at your option)
any later version. It is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [COPYING](COPYING).

Copyright (C) 2026 AERA | Erez Yaary.

`EFTPXL.ATR` carries SpartaDOS 3.2 and its boot sectors
(`xl/tools/disk/`), as EDOS's disks do; they stay under their own
terms.

---

Part of **AERA** for Atari: [ECal](https://github.com/whomper/ECal) · [EContact](https://github.com/whomper/EContact) · [EMail](https://github.com/whomper/EMail) · [EFTP](https://github.com/whomper/EFTP) · [EHypView](https://github.com/whomper/EHypView) · [ClaudeST](https://github.com/whomper/ClaudeST) · 8-bit: [EDOS](https://github.com/whomper/EDOS) · [EFTP_XL](https://github.com/whomper/EFTP_XL)
