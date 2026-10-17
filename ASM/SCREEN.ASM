;
; SCREEN.M65 - EFTP_XL 1.1
; Screen output and keyboard input
; Copyright (C) 2026 AERA | Erez Yaary
;
; SCRINIT - take over DOS's GR.0
; screen: row table, cleared, EDOS
; font and colours (old ones kept)
;
SCRINIT  LDA CHBAS
         STA OCHBAS
         LDA COLOR1
         STA OCOL1
         LDA COLOR2
         STA OCOL2
         LDA COLOR4
         STA OCOL4
         LDA SAVMSC         ; screen memory
         STA PTR
         LDA SAVMSC+1
         STA PTR+1
;
; ROWLO/ROWHI: the 24 rows, 40
; bytes apart
;
         LDX #0
SCRI1    LDA PTR            ; row starts
         STA ROWLO,X
         CLC
         ADC #40
         STA PTR
         LDA PTR+1          ; LDA, STA keep the
         STA ROWHI,X        ; carry for the ADC
         ADC #0
         STA PTR+1
         INX
         CPX #24
         BNE SCRI1
         LDX #23
SCRI2    JSR CLRROW
         DEX
         BPL SCRI2
         LDA #1             ; no cursor
         STA CRSINH
         LDA #>FONT         ; the font's page
         STA CHBAS
         LDA #$CA           ; light text
         STA COLOR1
         LDA #$94           ; on blue
         STA COLOR2
         LDA #0             ; black border
         STA COLOR4
         RTS
;
; SCRDONE - DOS's font and colours
; back, screen cleared by E:
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
;
; PUT BYTES of length 0: CIO sends
; the one byte in A, to E: (IOCB 0)
;
         STA ICBLL0
         STA ICBLH0
         LDA #11            ; PUT BYTES
         STA ICCOM0
         LDX #0
         LDA #$7D           ; clear screen
         JMP CIOV
;
; AT - draw at X=row, Y=column
; Exit: SROW, SCOL, SCRP set
;
AT       STX SROW
         STY SCOL
         LDA ROWLO,X        ; SCRP: the row's
         STA SCRP           ; start; SCOL is
         LDA ROWHI,X        ; the Y into it
         STA SCRP+1
         RTS
;
; INVON, INVOFF - inverse on/off
; (SINV $80 or 0)
;
INVON    LDA #$80
         .BYTE $2C          ; BIT: skip LDA #0
INVOFF   LDA #0
         STA SINV
         RTS
;
; PUTCH - char A (ATASCII) at SROW,
; SCOL; SCOL moves on
; Exit: A, X, Y kept
;
; ATASCII to screen code, by bits
; 5-6: $00-1F +$40, $20-5F -$20,
; $60-7F as is; bit 7 stays
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
         AND #3             ; bits 5-6
         TAX
         PLA
         CLC
         ADC SCRADJ,X       ; to screen code
         EOR SINV           ; $80: inverse
         LDY SCOL
         STA (SCRP),Y
         INC SCOL
         LDA PCA
         LDX PCX
         LDY PCY
         RTS
SCRADJ   .BYTE $40,$E0,$E0,$00 ; $E0 is -$20
;
; PUTS - string A/Y, to column 39
; at most; PUTSI: string inline
;
PUTSI    JSR INLINE
PUTS     STA PTR
         STY PTR+1
         LDY #0
PUTS1    LDA (PTR),Y
         BEQ PUTS2
         LDX SCOL
         CPX #40
         BCS PUTS2          ; end of the row
         JSR PUTCH          ; Y kept
         INY
         BNE PUTS1
PUTS2    RTS
;
; PUTW - string A/Y in exactly SW
; columns, cut or space filled
;
PUTW     STA PTR
         STY PTR+1
         LDY #0
         LDX SW             ; X: columns left
         BEQ PUTW3
PUTW1    LDA (PTR),Y
         BEQ PUTW2          ; ended: spaces
         INY
         .BYTE $2C          ; BIT: skip LDA #32
PUTW2    LDA #32            ; Y stays on the 0
         JSR PUTCH
         DEX
         BNE PUTW1
PUTW3    RTS
;
; REP - char A, SW times
; Exit: Y kept
;
REP      LDX SW
         BEQ REP2
REP1     JSR PUTCH
         DEX
         BNE REP1
REP2     RTS
;
; SPACES - SW spaces
;
SPACES   LDA #32
         BNE REP            ; always
;
; CLRROW - blank row X
; Exit: X kept
;
CLRROW   LDY #0
         JSR AT
         LDA #0             ; screen code space
         LDY #39
CLRR1    STA (SCRP),Y
         DEY
         BPL CLRR1
         RTS
;
; RULE - a line across row X
;
RULE     LDY #SCRL
         JSR AT
         LDA #SCRW
         STA SW
         LDA #CHHLINE
         JMP REP
;
; BOX - box over rows 3-22, title
; A/Y in inverse on its top
;
BOX      STA PTR3
         STY PTR3+1
         LDA #SCRW-2        ; inside width
         STA SW
         LDA #3
         STA TMP            ; row
;
; Each row: left edge, SW of the
; middle, right edge; Y picks the
; three in BOXCH
;
BOX1     LDX TMP
         LDY #SCRL
         JSR AT
         LDY #0             ; side row
         LDA TMP
         CMP #3
         BNE BOX2
         LDY #3             ; top row
BOX2     CMP #22
         BNE BOX3
         LDY #6             ; bottom row
BOX3     LDA BOXCH,Y        ; edge, middle, edge
         JSR PUTCH
         LDA BOXCH+1,Y
         JSR REP            ; Y kept
         LDA BOXCH+2,Y
         JSR PUTCH
         INC TMP
         LDA TMP
         CMP #23
         BNE BOX1
         LDX #3             ; " title " on the
         LDY #SCRL+2        ; top line
         JSR AT
         JSR INVON
         JSR PUTSP
         LDA PTR3
         LDY PTR3+1
         JSR PUTS
         JSR PUTSP
         JMP INVOFF
;
; Side, top, bottom: 3 each
;
BOXCH    .BYTE CHVLINE,32,CHVLINE,CHTL,CHHLINE,CHTR,CHBL,CHHLINE,CHBR
;
; PUTSP - a space
;
PUTSP    LDA #32
         JMP PUTCH
;
; KEYBAR - the keys on row 23
; A/Y="KEY",0,"what",0, ... 0
;
KEYBAR   STA PTR3
         STY PTR3+1
         LDX #23
         JSR CLRROW
         LDY #SCRL
         JSR AT
KEYB1    LDY #0
         LDA (PTR3),Y
         BEQ KEYB3          ; end of list
         JSR INVON
         JSR KEYB2          ; key in inverse
         JSR INVOFF
         INC SCOL           ; a column between
         JSR KEYB2          ; what it does
         INC SCOL
         JMP KEYB1
;
; KEYB2 - print string PTR3, move
; PTR3 past it
;
KEYB2    LDA PTR3
         LDY PTR3+1
         JSR PUTS
         LDA PTR3
         LDY PTR3+1
         JSR STRLEN
         SEC
         ADC PTR3           ; length+1
         STA PTR3
         BCC KEYB3
         INC PTR3+1
KEYB3    RTS
;
; KEYHIT - Z=0 when a key waits
; (tools/sim.py watches LDX CH)
;
KEYHIT   LDX CH
         CPX #$FF           ; $FF: no key
         RTS
;
; KEYGET - wait for a key
; Exit: A=key, KHELP for HELP
;
KEYGET   LDA HELPFG         ; HELP, set by OS
         BEQ KEYG1
         LDA #0             ; seen
         STA HELPFG
         LDA #KHELP
         RTS
KEYG1    JSR KEYHIT
         BEQ KEYGET         ; wait
;
; K:'s get byte, from its table at
; KEYBDV: +4 is its address-1, so
; push it and RTS into it
;
         LDA #12            ; K: open mode: R+W
         STA ICAX1Z
         LDA KEYBDV+5       ; RTS to K: get, which
         PHA
         LDA KEYBDV+4       ; returns to our caller
         PHA
         RTS
;
; EDIT - edit string A/Y in SW
; columns at SROW, SCOL; EDMAX=size
; with 0, EDMASK<>0 shows a * each
; Exit: A=key that ended it: RETURN,
;       ESC, up, down or TAB
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
;
; Backspace: a 0 one back. Else a
; char at the end, if there is room
; for it and the 0
;
EDIT3    LDY EDLEN          ; Y: the end
         CMP #KBKSP
         BNE EDIT4
         TYA
         BEQ EDIT1          ; empty already
         DEY
         STY EDLEN
         LDA #0
         BEQ EDIT5          ; always
EDIT4    AND #$7F           ; no inverse in names
         CMP #32
         BCC EDIT1          ; control keys
         CMP #$7B           ; printable only
         BCS EDIT1
         INY
         CPY EDMAX
         BCS EDIT1          ; full
         DEY
         STA (EDS),Y
         INY
         STY EDLEN
         LDA #0
EDIT5    STA (EDS),Y        ; the end 0
         JMP EDIT1
;
; EDDRAW - the visible end of the
; string; A=$80 with the cursor
;
EDDRAW   STA EDCUR
         LDA EDCOL
         STA SCOL
         LDA #0
         STA TMP            ; first char shown
         LDA EDLEN
         CMP SW
         BCC EDD1           ; it all fits
         SBC SW             ; C=1 from the CMP
         ADC #0             ; C=1: len-w+1
         STA TMP            ; (room for cursor)
;
; SW columns from char TMP: the
; chars (or *s), then spaces; the
; one at EDLEN in EDCUR's inverse
;
EDD1     LDA SW
         STA TMP2           ; columns left
EDD2     LDY TMP
         LDA #0
         CPY EDLEN
         BNE EDD3
         LDA EDCUR          ; cursor: at the end
EDD3     STA SINV
         LDA #32
         CPY EDLEN
         BCS EDD4           ; past the end
         LDA #'*
         LDX EDMASK
         BNE EDD4
         LDA (EDS),Y
EDD4     JSR PUTCH
         INC TMP
         DEC TMP2
         BNE EDD2
         JMP INVOFF         ; SINV back to 0
