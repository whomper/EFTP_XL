;
; EFTP_XL - the screen and the keyboard
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; GRAPHICS 0 as DOS left it, drawn straight into screen memory, in
; EDOS's font and colours. Drawing goes at SROW, SCOL (AT sets them,
; X the row and Y the column) and in inverse while SINV is $80.
;
SCRINIT  LDA CHBAS
         STA OCHBAS
         LDA COLOR1
         STA OCOL1
         LDA COLOR2
         STA OCOL2
         LDA COLOR4
         STA OCOL4
         LDA SAVMSC
         STA PTR
         LDA SAVMSC+1
         STA PTR+1
         LDX #0
SCRI1    LDA PTR
         STA ROWLO,X
         CLC
         ADC #40
         STA PTR
         LDA PTR+1
         STA ROWHI,X
         ADC #0
         STA PTR+1
         INX
         CPX #24
         BNE SCRI1
         LDX #23
SCRI2    JSR CLRROW
         DEX
         BPL SCRI2
         LDA #1
         STA CRSINH
         LDA #>FONT
         STA CHBAS
         LDA #$CA           ; light text
         STA COLOR1
         LDA #$94           ; on blue
         STA COLOR2
         LDA #0             ; in black
         STA COLOR4
         RTS
;
; SCRDONE: DOS's font and colours back, and the screen cleared by E:
;
SCRDONE  LDA OCHBAS
         STA CHBAS
         LDA OCOL1
         STA COLOR1
         LDA OCOL2
         STA COLOR2
         LDA OCOL4
         STA COLOR4
         LDA #0
         STA CRSINH
         STA ICBLL0
         STA ICBLH0
         LDA #11
         STA ICCOM0
         LDX #0
         LDA #$7D
         JMP CIOV
;
AT       STX SROW
         STY SCOL
         LDA ROWLO,X
         STA SCRP
         LDA ROWHI,X
         STA SCRP+1
         RTS
;
INVON    LDA #$80
         .BYTE $2C          ; BIT: skips the LDA #0
INVOFF   LDA #0
         STA SINV
         RTS
;
; PUTCH: A (ATASCII) at SROW, SCOL, and on; all registers are kept
;
PUTCH    STA PCA
         STX PCX
         STY PCY
         PHA
         LSR A
         LSR A
         LSR A
         LSR A
         LSR A
         AND #3
         TAX
         PLA
         CLC
         ADC SCRADJ,X
         EOR SINV
         LDY SCOL
         STA (SCRP),Y
         INC SCOL
         LDA PCA
         LDX PCX
         LDY PCY
         RTS
SCRADJ   .BYTE $40,$E0,$E0,$00
;
; PUTS: A/Y on, to the end of the line at most
;
PUTSI    JSR INLINE
PUTS     STA PTR
         STY PTR+1
         LDY #0
PUTS1    LDA (PTR),Y
         BEQ PUTS2
         LDX SCOL
         CPX #40
         BCS PUTS2
         JSR PUTCH
         INY
         BNE PUTS1
PUTS2    RTS
;
; PUTW: A/Y in exactly SW columns, cut or with spaces after it
;
PUTW     STA PTR
         STY PTR+1
         LDY #0
         LDX SW
         BEQ PUTW3
PUTW1    LDA (PTR),Y
         BEQ PUTW2
         INY
         .BYTE $2C          ; BIT: skips the LDA #32
PUTW2    LDA #32
         JSR PUTCH
         DEX
         BNE PUTW1
PUTW3    RTS
;
; REP: A, SW times
;
REP      LDX SW
         BEQ REP2
REP1     JSR PUTCH
         DEX
         BNE REP1
REP2     RTS
;
; SPACES: SW spaces
;
SPACES   LDA #32
         BNE REP
;
; CLRROW: row X blank (X is kept)
;
CLRROW   LDY #0
         JSR AT
         LDA #0
         LDY #39
CLRR1    STA (SCRP),Y
         DEY
         BPL CLRR1
         RTS
;
; RULE: a line across row X
;
RULE     LDY #SCRL
         JSR AT
         LDA #SCRW
         STA SW
         LDA #CHHLINE
         JMP REP
;
; BOX: a box over rows 3..22, A/Y its title
;
BOX      STA PTR3
         STY PTR3+1
         LDA #SCRW-2
         STA SW
         LDA #3
         STA TMP
BOX1     LDX TMP
         LDY #SCRL
         JSR AT
         LDY #0
         LDA TMP
         CMP #3
         BNE BOX2
         LDY #3
BOX2     CMP #22
         BNE BOX3
         LDY #6
BOX3     LDA BOXCH,Y
         JSR PUTCH
         LDA BOXCH+1,Y
         JSR REP
         LDA BOXCH+2,Y
         JSR PUTCH
         INC TMP
         LDA TMP
         CMP #23
         BNE BOX1
         LDX #3
         LDY #SCRL+2
         JSR AT
         JSR INVON
         JSR PUTSP
         LDA PTR3
         LDY PTR3+1
         JSR PUTS
         JSR PUTSP
         JMP INVOFF
BOXCH    .BYTE CHVLINE,32,CHVLINE,CHTL,CHHLINE,CHTR,CHBL,CHHLINE,CHBR
PUTSP    LDA #32
         JMP PUTCH
;
; KEYBAR: the keys on row 23, A/Y: "KEY",0,"what",0, ... 0
;
KEYBAR   STA PTR3
         STY PTR3+1
         LDX #23
         JSR CLRROW
         LDY #SCRL
         JSR AT
KEYB1    LDY #0
         LDA (PTR3),Y
         BEQ KEYB3
         JSR INVON
         JSR KEYB2
         JSR INVOFF
         INC SCOL
         JSR KEYB2
         INC SCOL
         JMP KEYB1
KEYB2    LDA PTR3
         LDY PTR3+1
         JSR PUTS
         LDA PTR3
         LDY PTR3+1
         JSR STRLEN
         SEC
         ADC PTR3
         STA PTR3
         BCC KEYB3
         INC PTR3+1
KEYB3    RTS
;
; KEYHIT: Z clear when a key is waiting. LDX CH is how tools/sim.py
; sees the program look at the keyboard.
;
KEYHIT   LDX CH
         CPX #$FF
         RTS
;
; KEYGET: the next key, in A ($FF is HELP)
;
KEYGET   LDA HELPFG
         BEQ KEYG1
         LDA #0
         STA HELPFG
         LDA #KHELP
         RTS
KEYG1    JSR KEYHIT
         BEQ KEYGET
         LDA #12            ; as cc65 does, for the handler called direct
         STA ICAX1Z
         LDA KEYBDV+5       ; K:'s get, returning to the caller
         PHA
         LDA KEYBDV+4
         PHA
         RTS
;
; EDIT: edit the string at A/Y (EDMAX - 1 characters at most, a * for
; each when EDMASK) in SW columns at SROW, SCOL. Returns the key that
; ended it: RETURN, ESC, up, down or TAB.
;
EDIT     STA EDS
         STY EDS+1
         JSR STRLEN
         STA EDLEN
         LDA SCOL
         STA EDCOL
EDIT1    LDA #$80           ; with the cursor
         JSR EDDRAW
         JSR KEYGET
         CMP #KRETURN
         BEQ EDIT2
         CMP #KESC
         BEQ EDIT2
         CMP #KUP
         BEQ EDIT2
         CMP #KDOWN
         BEQ EDIT2
         CMP #KTAB
         BNE EDIT3
EDIT2    PHA
         LDA #0             ; without it
         JSR EDDRAW
         PLA
         RTS
EDIT3    LDY EDLEN
         CMP #KBKSP
         BNE EDIT4
         TYA
         BEQ EDIT1
         DEY
         STY EDLEN
         LDA #0
         BEQ EDIT5
EDIT4    AND #$7F           ; inverse doesn't belong in names
         CMP #32
         BCC EDIT1
         CMP #$7B
         BCS EDIT1
         INY
         CPY EDMAX
         BCS EDIT1
         DEY
         STA (EDS),Y
         INY
         STY EDLEN
         LDA #0
EDIT5    STA (EDS),Y
         JMP EDIT1
;
; EDDRAW: the visible end of the string; A: $80 with the cursor
;
EDDRAW   STA EDCUR
         LDA EDCOL
         STA SCOL
         LDA #0
         STA TMP
         LDA EDLEN
         CMP SW
         BCC EDD1
         SBC SW
         ADC #0             ; carry is set: len - w + 1
         STA TMP
EDD1     LDA SW
         STA TMP2
EDD2     LDY TMP
         LDA #0
         CPY EDLEN
         BNE EDD3
         LDA EDCUR
EDD3     STA SINV
         LDA #32
         CPY EDLEN
         BCS EDD4
         LDA #'*
         LDX EDMASK
         BNE EDD4
         LDA (EDS),Y
EDD4     JSR PUTCH
         INC TMP
         DEC TMP2
         BNE EDD2
         JMP INVOFF
