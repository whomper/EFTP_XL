#!/usr/bin/env python3
# EFTP_XL - the servers of the SFTP and FTPS checks
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""AERA-Gateway's eftpgate and, behind it, the SFTP and FTPS servers of
eftpgate's own tests (user atari, password falcon), all from
AERA-Gateway's latest release (make test fetches it to bin/gateway),
in a process of their own, so they don't wait on the emulator for
Python's lock. Prints the ports, the gateway's then the SFTP and FTPS
servers', and serves until it is stopped.

    tools/gwserve.py GATEWAYDIR ROOT
"""
import os
import sys
import tempfile
import time


def main():
    gwdir, root = sys.argv[1], sys.argv[2]
    sys.path.insert(0, gwdir)
    import paramiko
    import test_eftpgate as t
    work = tempfile.mkdtemp(prefix='eftpxl-gw-')
    _, sport = t.sftp_server(root, paramiko.ECDSAKey.generate())
    chain, ca = t.make_certs(work)
    _, fport, _ = t.ftps_server(root, chain)
    _, gport = t.gateway(os.path.join(work, 'state'), cafile=ca)
    print(gport, sport, fport, flush=True)
    while True:
        time.sleep(3600)


if __name__ == '__main__':
    main()
