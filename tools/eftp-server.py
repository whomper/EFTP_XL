#!/usr/bin/env python3
# EFTP_XL - FTP server for FujiNet clients
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
#
# A pyftpdlib server that also accepts FujiNet's directory request.
# FujiNet always lists with a wildcard ("LIST /path/*"), and plain
# pyftpdlib answers that with "550 No such file or directory".
#
#   python3 -m venv ~/eftp-venv && ~/eftp-venv/bin/pip install pyftpdlib
#   ~/eftp-venv/bin/python eftp-server.py --dir ~/AtariShare --user atari --password secret

import argparse
import fnmatch
import os

from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.filesystems import AbstractedFS
from pyftpdlib.handlers import FTPHandler
from pyftpdlib.servers import FTPServer


class FujiNetFS(AbstractedFS):
    """Treat "dir/<wildcard>" as dir, listing only the names that match."""

    @staticmethod
    def _split(path):
        base, pattern = os.path.split(path)
        if any(c in pattern for c in "*?["):
            return base, pattern
        return path, None

    def isdir(self, path):
        return super().isdir(self._split(path)[0])

    def listdir(self, path):
        base, pattern = self._split(path)
        names = super().listdir(base)
        if pattern:
            names = [n for n in names if fnmatch.fnmatch(n, pattern)]
        return names

    def format_list(self, basedir, listing, ignore_err=True):
        return super().format_list(self._split(basedir)[0], listing, ignore_err)


def main():
    ap = argparse.ArgumentParser(description="FTP server for EFTP_XL / FujiNet")
    ap.add_argument("--dir", required=True, help="folder to share")
    ap.add_argument("--user", required=True)
    ap.add_argument("--password", required=True)
    ap.add_argument("--port", type=int, default=2121)
    ap.add_argument("--read-only", action="store_true",
                    help="allow downloads only")
    args = ap.parse_args()

    share = os.path.abspath(os.path.expanduser(args.dir))
    os.makedirs(share, exist_ok=True)

    auth = DummyAuthorizer()
    auth.add_user(args.user, args.password, share,
                  perm="elr" if args.read_only else "elradfmw")
    handler = FTPHandler
    handler.authorizer = auth
    handler.abstracted_fs = FujiNetFS
    handler.banner = "EFTP_XL server ready."

    print(f"Sharing {share} on port {args.port} as user '{args.user}'.")
    print("On the Atari: protocol F, this Mac's IP address, port "
          f"{args.port}, path /")
    FTPServer(("0.0.0.0", args.port), handler).serve_forever()


if __name__ == "__main__":
    main()
