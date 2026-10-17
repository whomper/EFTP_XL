# AERA-Atari xl/tools/a8sim - SIO
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""SIO's device control block, handed to the device DDEVIC names. The
devices are the program's own: EDOS's disk drive, EFTP_XL's FujiNet.
A device is f(m, dcb) -> status, or an object with call(m, dcb)."""
DCB = 0x300


class SIO:
    """devices {DDEVIC: device}; fallback for any other (EDOS's tests set
    one handler for every call); log keeps every DCB"""

    def __init__(self, devices=None, fallback=None):
        self.devices = dict(devices or {})
        self.fallback = fallback
        self.log = []

    @staticmethod
    def dcb(m):
        """the device control block, by name; sector is DAUX1/2 as a word"""
        b = m.mem
        return dict(dev=b[DCB], unit=b[DCB + 1], cmd=b[DCB + 2], stat=b[DCB + 3],
                    buf=b[DCB + 4] | b[DCB + 5] << 8, timeout=b[DCB + 6],
                    size=b[DCB + 8] | b[DCB + 9] << 8, aux1=b[DCB + 10], aux2=b[DCB + 11],
                    sector=b[DCB + 10] | b[DCB + 11] << 8, portb=b[0xD301])

    def call(self, m, dskinv=False):
        if dskinv:                          # DSKINV: the drive, DDEVIC set for us
            m.mem[DCB] = 0x31
        d = self.dcb(m)
        self.log.append(d)
        dev = self.devices.get(d['dev'], self.fallback)
        if dev is None:
            return 138                      # timeout: nothing answers
        return dev.call(m, d) if hasattr(dev, 'call') else dev(m, d)


def strict_length(size, want):
    """a device reads a fixed frame for a command: any other length puts
    its checksum in the wrong place (143); None when the length is right"""
    return None if want is None or size == want else 143
