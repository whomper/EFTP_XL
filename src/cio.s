; EFTP_XL - call CIO for an IOCB set up in C
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; unsigned char __fastcall__ cio(unsigned char x);
;   x is the IOCB number times 16; returns CIO's status (Y)

        .export _cio
        .include "atari.inc"

_cio:   tax
        jsr     CIOV
        tya
        ldx     #0
        rts
