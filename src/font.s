; EFTP_XL - the character set: EDOS's, with a folder, a file, "..." and
; a progress-bar shade (tools/mkfont.py)
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.

        .export _font
        .segment "FONT"
_font:  .incbin "EFTPXL.FNT"
