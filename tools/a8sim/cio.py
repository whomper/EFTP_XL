# AERA-Atari xl/tools/a8sim - CIO and its devices
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""CIO as the OS does it, for the devices a program uses:
- a name given to CIO (OPEN, XIO) ends at its EOL or a 0, never at ICBLL;
- the status goes back in Y and ICSTA; ICBLL says how many came;
- GET RECORD stops after its EOL, PUT RECORD writes up to its EOL;
- a length of 0 is one byte, in A;
- 136 at the end of a file.
A device: open(spec, aux1, aux2) -> (status, handle); get(handle, n,
record) -> (status, data); put(handle, data, record) -> status;
close(handle); xio(cmd, spec, aux1, aux2) -> status."""
import datetime
import fnmatch
import os

IOCB = 0x340
EOL = 0x9B
OPEN, GETREC, GETCHR, PUTREC, PUTCHR, CLOSE, STATIS = 3, 5, 7, 9, 11, 12, 13


def cio_name(m, buf):
    """a file name given to CIO: it ends at its EOL, or at a 0, where DOS's
    name parsing stops too"""
    return bytes(m[buf:buf + 128]).split(b'\x9b')[0].split(b'\0')[0].decode('latin-1')


class CIO:
    """CIO's dispatcher: e, k, d, and any more by letter (devices={'N': x}).
    IOCB 0 is open to E: from the start, as the OS leaves it."""

    def __init__(self, e=None, k=None, d=None, devices=None):
        self.devices = dict(devices or {})
        for letter, dev in (('E', e), ('K', k), ('D', d)):
            if dev is not None:
                self.devices[letter] = dev
        self.e = e
        self.open = {}              # iocb -> (device, handle)
        self.log = []               # (iocb, command, status)
        self.reset()

    def reset(self):
        """RESET or start: everything closed, IOCB 0 on E:"""
        for x, (dev, h) in list(self.open.items()):
            if x and hasattr(dev, 'close'):
                dev.close(h)
        self.open = {}
        if self.e is not None:
            self.open[0] = (self.e, self.e.open('E:', 12, 0)[1])

    def call(self, m, x):
        b = IOCB + x
        cmd = m.mem[b + 2]
        buf = m.word(b + 4)
        n = m.word(b + 8)
        aux1, aux2 = m.mem[b + 10], m.mem[b + 11]
        y, a = self._do(m, x, b, cmd, buf, n, aux1, aux2)
        self.log.append((x >> 4, cmd, y))
        return y, a

    def _do(self, m, x, b, cmd, buf, n, aux1, aux2):
        if cmd == OPEN:
            if x in self.open:
                return 129, None
            spec = cio_name(m.mem, buf)
            dev = self.devices.get(spec[:1].upper())
            if dev is None:
                return 130, None
            st, h = dev.open(spec, aux1, aux2)
            if st < 128:
                self.open[x] = (dev, h)
                m.mem[b] = x            # ICHID: open
            return st, None
        if cmd == CLOSE:
            dev, h = self.open.pop(x, (None, None))
            if dev is not None and hasattr(dev, 'close'):
                dev.close(h)
            m.mem[b] = 0xFF
            return 1, None
        if cmd >= 0x0E:                 # XIO: the device the spec names
            spec = cio_name(m.mem, buf)
            dev = self.devices.get(spec[:1].upper())
            if x in self.open and not spec[:1].isalpha():
                dev = self.open[x][0]
            if dev is None or not hasattr(dev, 'xio'):
                return 146 if dev else 130, None
            return dev.xio(cmd, spec, aux1, aux2), None
        if x not in self.open:
            return 133, None
        dev, h = self.open[x]
        if cmd == STATIS:
            return 1, None
        if cmd in (GETREC, GETCHR):
            st, data = dev.get(h, n or 1, cmd == GETREC)
            if n == 0:
                m.poke_word(b + 8, 0)
                return st, data[0] if data else None
            m.poke(buf, data)
            m.poke_word(b + 8, len(data))
            return st, None
        if cmd in (PUTREC, PUTCHR):
            if n == 0:
                data = bytes([m.mpu.a])
            else:
                data = bytes(m.mem[buf:buf + n])
                if cmd == PUTREC and EOL in data:
                    data = data[:data.index(EOL) + 1]
            return dev.put(h, data, cmd == PUTREC), None
        return 132, None


class E:
    """the screen editor: what is put is kept in out (bytes); a GET takes
    the next of lines (str, without its EOL)"""

    def __init__(self, lines=()):
        self.out = bytearray()
        self.lines = list(lines)

    def open(self, spec, aux1, aux2):
        return 1, None

    def put(self, h, data, record):
        self.out += data
        return 1

    def get(self, h, n, record):
        if not self.lines:
            return 136, b''
        line = self.lines.pop(0).encode('latin-1') + bytes([EOL])
        return 1, line[:n]

    def text(self):
        return bytes(self.out).replace(b'\x9b', b'\n').decode('latin-1')


class K:
    """K:: each GET is the next key of the key script (keys.py); none
    left ends the run"""

    def __init__(self, keys):
        self.keys = keys

    def open(self, spec, aux1, aux2):
        return 1, None

    def get(self, h, n, record):
        k = self.keys.next_key()
        if k is None:
            return 128, b''                 # BREAK
        return 1, bytes([k])

    def put(self, h, data, record):
        return 135


class Disks:
    """D1:..D8: as folders on this machine (EFTP_XL's): files, folders
    (>), the directory listed as SpartaDOS 3 (aux2 $80: bytes and <DIR>)
    or DOS 2.5 lists it (sectors, no folders), XIO 32 rename, 33 delete,
    35 lock, 36 unlock, and 42/43 make and remove a folder (SpartaDOS
    only; 146 on DOS 2)."""

    def __init__(self, drives, dos='sparta', volume='AERATEST'):
        self.drives = drives            # {1: '/path', ...}
        self.dos = dos
        self.volume = volume
        self.locked = set()             # paths locked by XIO 35

    def _resolve(self, spec):
        dev, _, rest = spec.partition(':')
        n = int(dev[1:]) if len(dev) > 1 and dev[1:].isdigit() else 1
        if n not in self.drives:
            return None, None
        parts = [p for p in rest.replace('\\', '>').split('>') if p]
        name = parts.pop() if parts and not rest.endswith('>') else ''
        return os.path.join(self.drives[n], *parts), name

    def _listing(self, folder, pattern, long=True):
        names = sorted(os.listdir(folder))
        lines = []
        sparta = self.dos == 'sparta' and long
        secsize = 256 if self.dos == 'sparta' else 125
        if sparta:
            lines += ['', f'Volume:    {self.volume}', 'Directory: ' +
                      (os.path.basename(folder).upper() or 'MAIN'), '']
        for n in names:
            full = os.path.join(folder, n)
            base, _, ext = n.upper().partition('.')
            if not fnmatch.fnmatch(n.upper(), pattern.upper().replace('*.*', '*')):
                continue
            t = datetime.datetime.fromtimestamp(os.path.getmtime(full))
            when = t.strftime('%d-%m-%y %H:%M')
            if os.path.isdir(full):
                if sparta:
                    lines.append(f'{base[:8]:<8}     <DIR>  {when}')
                continue
            size = os.path.getsize(full)
            if sparta:
                lines.append(f'{base[:8]:<8} {ext[:3]:<3} {size:>7} {when}')
            else:
                lines.append(f'  {base[:8]:<8}{ext[:3]:<3} {(size + secsize - 1) // secsize:03d}')
        lines.append(' 1234 FREE SECTORS' if sparta else '609 FREE SECTORS')
        return ''.join(x + '\x9b' for x in lines).encode('latin-1')

    def open(self, spec, aux1, aux2):
        folder, name = self._resolve(spec)
        if folder is None:
            return 130, None
        if aux1 & 2 and aux1 & 4:                       # 6: the directory
            if not os.path.isdir(folder):
                return 150, None
            return 1, dict(data=self._listing(folder, name or '*.*', bool(aux2 & 0x80)),
                           pos=0, write=False)
        path = os.path.join(folder, name)
        if aux1 & 8:
            if path in self.locked:
                return 167, None
            data = bytearray()
            if aux1 & 1 and os.path.isfile(path):         # 9: append
                with open(path, 'rb') as fh:
                    data = bytearray(fh.read())
            return 1, dict(data=data, pos=len(data), write=True, path=path)
        if not os.path.isfile(path):
            return 170, None
        with open(path, 'rb') as fh:
            return 1, dict(data=fh.read(), pos=0, write=False)

    def get(self, f, n, record):
        d, p = f['data'], f['pos']
        if p >= len(d):
            return 136, b''
        end = (d.find(b'\x9b', p) + 1 or len(d)) if record else len(d)
        short = not record and p + n > len(d)
        end = min(end, p + n)
        f['pos'] = end
        # GET BYTES asking for more than is left: the bytes there are and
        # 136 together, as CIO and the FMS give them (not 1, then 136
        # with nothing on the next GET)
        return (136 if short else 1), bytes(d[p:end])

    def put(self, f, data, record):
        if not f['write']:
            return 135
        f['data'] += data
        return 1

    def close(self, f):
        if f and f['write']:
            with open(f['path'], 'wb') as fh:
                fh.write(bytes(f['data']))

    def xio(self, cmd, spec, aux1, aux2):
        if cmd in (42, 43) and self.dos != 'sparta':
            return 146
        folder, name = self._resolve(spec.split(',')[0])
        if folder is None:
            return 130
        path = os.path.join(folder, name)
        if cmd in (42, 43):
            try:
                os.mkdir(path) if cmd == 42 else os.rmdir(path)
            except FileExistsError:
                return 151
            except OSError:
                return 167 if cmd == 43 and os.path.isdir(path) else 170
            return 1
        if cmd in (32, 33, 35, 36):
            if not os.path.exists(path):
                return 170
            if cmd == 33:
                if path in self.locked:
                    return 167
                os.remove(path)
            elif cmd == 32:
                os.rename(path, os.path.join(folder, spec.split(',')[1]))
            elif cmd == 35:
                self.locked.add(path)
            else:
                self.locked.discard(path)
            return 1
        return 146
