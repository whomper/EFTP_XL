# AERA-Atari xl/tools/a8sim - the floating point ROM, as far as programs use it
# Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
"""AFP, FASC, IFP and FPI for whole numbers, which is what EDOS uses them
for (number to text and back). install_fp(m) traps them. For the full
6-byte BCD arithmetic (MAC/65's), see xl/tools/mac65real/fp.py."""
AFP, FASC, IFP, FPI = 0xD800, 0xD8E6, 0xD9AA, 0xD9D2
FR0, LBUFF, INBUFF, CIX = 0xD4, 0x0580, 0xF3, 0xF2


def install_fp(m):
    state = {'v': 0}

    def ifp(m):
        state['v'] = m.mem[FR0] | m.mem[FR0 + 1] << 8
        m.rts()

    def fasc(m):
        s = str(state['v']).encode()
        for k, c in enumerate(s):
            m.mem[LBUFF + k] = c | (0x80 if k == len(s) - 1 else 0)
        m.poke_word(INBUFF, LBUFF)
        m.rts()

    def afp(m):
        p = m.word(INBUFF) + m.mem[CIX]
        s = ''
        while chr(m.mem[p]).isdigit():
            s += chr(m.mem[p])
            p += 1
        state['v'] = int(s or '0')
        m.rts()

    def fpi(m):
        m.poke_word(FR0, state['v'])
        m.rts()

    m.traps.update({IFP: ifp, FASC: fasc, AFP: afp, FPI: fpi})
    return state
