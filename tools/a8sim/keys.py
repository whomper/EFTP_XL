# AERA-Atari xl/tools/a8sim - the key script
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""Keys typed from a script, as the OS gives them: CH says one waits, K:'s
get-byte (KEYBDV+4, or a K: GET) takes it; HELP through HELPFG; RESET.

    parse_keys(r'^K\\nTEST\\n\\s')
  \\n RETURN  \\e ESC  \\t TAB  \\b BACKSPACE  \\u \\d \\l \\r arrows
  \\x DELETE LINE  \\h HELP  \\! RESET  \\k BREAK  ^X Ctrl+X
  \\s a snapshot (on_shot)  \\w wait until the program is idle (a transfer
  ended)  \\z let one more look at the keyboard go by
The run ends (Stop) when the program waits for a key and none is left."""
from .core import Stop, CH

KEYBDV = 0xE420
KEY_TRAP = 0xE700           # KEYBDV's get-byte points here
HELPFG = 0x2DC
HELP, SHOT, WAIT, SKIP, RESET, BREAK = 'help', 'shot', 'wait', 'skip', 'reset', 'break'
BRKKEY = 0x11               # 0 after BREAK (the OS's BREAK interrupt)
IDLE_GAP = 300              # looks this close together: waiting for a key
IDLE_STOP = 200             # this many with no key left: the run ends
NAMED = {'n': 0x9B, 'e': 0x1B, 't': 0x7F, 'b': 0x7E, 'u': 0x1C, 'd': 0x1D,
         'l': 0x1E, 'r': 0x1F, 'x': 0x9C}
TOKENS = {'h': HELP, 's': SHOT, 'w': WAIT, 'z': SKIP, '!': RESET, 'k': BREAK}


def parse_keys(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s):
            k = s[i + 1]
            out.append(TOKENS.get(k, NAMED.get(k, ord(k))))
            i += 2
        elif c == '^' and i + 1 < len(s):
            out.append(ord(s[i + 1].upper()) & 0x1F)
            i += 2
        else:
            out.append(ord(c))
            i += 1
    return out


class Keys:
    """keys: from parse_keys. install(m) puts the get-byte trap in KEYBDV's
    table and watches every LDX CH / LDA CH (the program looking for a
    key). on_shot(m) is called for \\s."""

    def __init__(self, keys, on_shot=None):
        self.keys = list(keys)
        self.on_shot = on_shot
        self.m = None
        self.polls = 0
        self.last_poll = 0

    def install(self, m, scan=True):
        self.m = m
        m.poke_word(KEYBDV + 4, KEY_TRAP - 1)
        m.traps[KEY_TRAP] = self._get_byte
        if scan:
            self.watch_ch(m)

    def watch_ch(self, m, start=0x0400, end=0xC000):
        """every LDX CH, LDA CH, LDY CH in memory (run it after a load)"""
        mem = m.mem
        for a in range(start, end - 2):
            if mem[a] in (0xAE, 0xAD, 0xAC) and mem[a + 1] == CH & 255 and mem[a + 2] == CH >> 8:
                m.watch[a] = self._look

    def _get_byte(self, m):
        k = self.next_key()
        if k is None:
            m.rts(a=0x9B, y=128)            # BREAK: K: says 128
        else:
            m.rts(a=k, y=1)

    def next_key(self):
        """the next key, for K:; None for BREAK (K:'s status 128)"""
        while self.keys and not isinstance(self.keys[0], int):
            if self.keys[0] == BREAK:
                self.keys.pop(0)
                self.m.mem[BRKKEY] = 0
            if not self.m.mem[BRKKEY]:
                break
            self._look(self.m)
            if self.m.reset_pending:
                raise Stop('RESET while a key was read')
        if not self.m.mem[BRKKEY]:
            self.m.mem[BRKKEY] = 0xFF       # K: takes it (the OS's DEC BRKKEY)
            return None
        if not self.keys:
            raise Stop('no keys left')
        k = self.keys.pop(0)
        self.m.mem[CH] = 0xFF
        return k

    def _look(self, m):
        """the program looks at CH"""
        idle = m.steps - self.last_poll < IDLE_GAP
        self.last_poll = m.steps
        while self.keys and self.keys[0] in (WAIT, SHOT, SKIP):
            if self.keys[0] == SKIP:
                self.keys.pop(0)
                return          # one more look (a block of a transfer) goes by
            if self.keys[0] == WAIT:
                if not idle:
                    return      # busy: hold the keys back
                self.keys.pop(0)
            else:
                self.keys.pop(0)
                if self.on_shot:
                    self.on_shot(m)
        if self.keys and self.keys[0] == BREAK:
            self.keys.pop(0)
            m.mem[BRKKEY] = 0           # seen when the program looks at BRKKEY
            self.polls = 0
            return
        if self.keys and self.keys[0] == RESET:
            self.keys.pop(0)
            m.reset()
            return
        if self.keys and self.keys[0] == HELP:
            if not m.mem[HELPFG]:
                self.keys.pop(0)
                m.mem[HELPFG] = 0x11
            return
        if self.keys:
            if m.mem[CH] == 0xFF:
                m.mem[CH] = 0x0C        # a key waits (which one, K: says)
            self.polls = 0
            return
        self.polls = self.polls + 1 if idle else 0
        if self.polls > IDLE_STOP:
            raise Stop('no keys left')
