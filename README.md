# EFTP_XL

File transfer for 8-bit Atari computers (400/800/XL/XE) over
[FujiNet](https://fujinet.online), written in C with cc65. Connects to a
Mac (or any SFTP/FTP server) and moves files between it and your Atari drives.

Works with DOS 2.5 and SpartaDOS 3.x. All local file access goes through CIO,
so any CIO-compatible DOS should work. Files are transferred as raw binary
with no conversion.

## Status

**Step 1: smoke test.** Shows FujiNet info and lists a remote directory.
Transfers come next.

- [x] Connect over SFTP or FTP and list a remote directory
- [ ] Download a file to `Dn:`
- [ ] Upload a file from `Dn:`
- [ ] Two-pane browser UI, saved settings
- [ ] Delete / rename / mkdir (SFTP only, see below)

## Setting up the Mac

### SFTP (recommended)

macOS already includes an SFTP server. Turn it on in
**System Settings → General → Sharing → Remote Login**, and allow your user.

Use your normal Mac username and password. The path is a full Mac path, for
example `/Users/yourname/AtariShare/`.

### FTP

macOS no longer includes an FTP server. A quick one for testing:

```sh
pip3 install pyftpdlib
mkdir -p ~/AtariShare
python3 -m pyftpdlib -p 2121 -w -d ~/AtariShare -u atari -P somepassword
```

Then use port `2121`, user `atari`, and path `/`.

FTP is unencrypted, so only use it on your home network. FujiNet's FTP support
can list, download and upload, but rename/delete/mkdir are not implemented in
the firmware (they report success without doing anything). Use SFTP for those.

## Running on the Atari

1. Get `bin/EFTPXL.XEX` onto a disk the Atari can read, e.g. an ATR on the
   FujiNet SD card or a TNFS share.
2. Load it: `L` from the DOS 2.5 menu, or type `EFTPXL` at the SpartaDOS prompt.
3. At the prompts, pick `S` (SFTP) or `F` (FTP), then enter the host (IP
   address of the Mac), port (blank = default), username, password and path.

Notes:

- Usernames, passwords and paths are case-sensitive. Press **CAPS** to switch
  to lowercase.
- The username and password can't contain `@`, `:` or `/` (FujiNet URL
  limitation).
- SFTP needs a recent FujiNet firmware. The program shows the firmware
  version at startup. If SFTP fails to connect, try FTP or update FujiNet.
- **ESC** at any prompt quits.
- The startup screen shows `MEMLO`. The program loads at `$3000`. If DOS's
  MEMLO is higher, the loader stops with an error. Let me know your value and
  we'll adjust.

## Building

You need a recent [cc65](https://github.com/cc65/cc65) built from git (the
2.19 release is too old for fujinet-lib):

```sh
git clone https://github.com/cc65/cc65 && make -C cc65
export PATH="$PWD/cc65/bin:$PATH"

git clone --recurse-submodules https://github.com/whomper/EFTP_XL
cd EFTP_XL
make
```

The output is `bin/EFTPXL.XEX`. `START_ADDR` changes the load address, for
example `make START_ADDR=0x2800`.

[fujinet-lib](https://github.com/FujiNetWIFI/fujinet-lib) is included as a
submodule (GPL-3.0).

## Licence

EFTP_XL is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation, either version 2 of the License, or (at your option)
any later version. It is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [COPYING](COPYING).

Copyright (C) 2026 AERA | Erez Yaary.

`bin/EFTPXL.XEX` is linked with fujinet-lib (GPL-3.0), so the built
program as a whole is distributed under the GPL version 3.
