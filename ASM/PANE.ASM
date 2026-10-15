;
; EFTP_XL - the panes' entries
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; The entries of both panes are in arrays of their fields: the Atari's
; at 0..63, the server's at 64..127, entry 128 spare for sorting. An
; entry is an index, a field one LDA ...,X. A pane's own values are in
; arrays of two, by side. Most routines work on the pane in SIDE, its
; entries from BASE (PUSE).
;
PUSE     STA SIDE
         TAX
         BEQ PUSE1
         LDA #MAXE
PUSE1    STA BASE
         RTS
;
PCLEAR   LDX SIDE
         LDA #0
         STA PCOUNT,X
         STA PTOP,X
         STA PCUR,X
         STA PDIRS,X
         STA PFILES,X
         STA PFULL,X
         STA PUSEDL,X
         STA PUSEDH,X
         RTS
;
; PADD: an entry called A/Y, with NSIZE, NFLAGS and the date in NDAY..
; NMIN; then they go back to 0 (no date: NDAY 0). No room: PFULL set.
;
PADD4    LDA #1             ; no room
         STA PFULL,X
         JMP NCLEAR
PADD     JSR STRLEN
         STA TMP
         LDX SIDE
         LDA PCOUNT,X
         CMP #MAXE
         BEQ PADD4
         LDA PUSEDL,X       ; the pool used, with this name and its 0
         SEC
         ADC TMP
         STA TMP2
         LDA PUSEDH,X
         ADC #0
         STA TMP3
         LDA PSIZEL,X
         CMP TMP2
         LDA PSIZEH,X
         SBC TMP3
         BCC PADD4
         LDA BASE
         CLC
         ADC PCOUNT,X
         TAY
         LDA POOLL,X
         CLC
         ADC PUSEDL,X
         STA ENL,Y
         STA PTR2
         LDA POOLH,X
         ADC PUSEDH,X
         STA ENH,Y
         STA PTR2+1
         LDA TMP2
         STA PUSEDL,X
         LDA TMP3
         STA PUSEDH,X
         INC PCOUNT,X
         LDA NSIZE
         STA ES0,Y
         LDA NSIZE+1
         STA ES1,Y
         LDA NSIZE+2
         STA ES2,Y
         LDA NSIZE+3
         STA ES3,Y
         LDA NDAY
         STA EDAY,Y
         LDA NMON
         STA EMON,Y
         LDA NYEAR
         STA EYEAR,Y
         LDA NHOUR
         STA EHOUR,Y
         LDA NMIN
         STA EMIN,Y
         LDA NFLAGS
         STA EFLAG,Y
         LSR A
         BCS PADD3          ; ".." is not counted
         LSR A
         BCC PADD2
         INC PDIRS,X
         BCS PADD3
PADD2    INC PFILES,X
PADD3    LDA PTR
         LDY PTR+1
         JSR STRCPY
         JMP NCLEAR
NCLEAR   LDA #0
         STA NFLAGS
         STA NDAY
         STA NSIZE
         STA NSIZE+1
         STA NSIZE+2
         STA NSIZE+3
         RTS
;
; PSORT: ".." first, then the folders, then the files, by name
;
PSORT    LDX SIDE
         LDA BASE
         STA PSI
         CLC
         ADC PCOUNT,X
         STA PSEND
PSORT1   INC PSI
         LDA PSI
         CMP PSEND
         BCS PSORT4
         LDX #NE
         LDY PSI
         JSR ECOPY
         LDA PSI
         STA PSJ
PSORT2   LDX PSJ
         CPX BASE
         BEQ PSORT3
         DEX
         LDY #NE
         JSR EAFTER
         BCC PSORT3
         LDX PSJ
         LDY PSJ
         DEY
         JSR ECOPY
         DEC PSJ
         JMP PSORT2
PSORT3   LDX PSJ
         LDY #NE
         JSR ECOPY
         JMP PSORT1
PSORT4   RTS
;
; EAFTER: does entry X go after entry Y? carry set when so
;
EAFTER   STX TMP
         STY TMP2
         LDA EFLAG,Y
         JSR RANK
         STA TMP3
         LDA EFLAG,X
         JSR RANK
         CMP TMP3
         BNE EAFT3
         LDA ENL,X
         STA PTR
         LDA ENH,X
         STA PTR+1
         LDA ENL,Y
         STA PTR2
         LDA ENH,Y
         STA PTR2+1
         LDY #0
EAFT1    LDA (PTR2),Y
         JSR UPPER
         STA TMP4
         LDA (PTR),Y
         JSR UPPER
         CMP TMP4
         BNE EAFT3
         TAX
         BEQ EAFT2
         INY
         BNE EAFT1
EAFT2    CLC
EAFT3    RTS
;
; RANK: the flags A as 0 "..", 1 a folder, 2 a file
;
RANK     LSR A
         BCS RANK2
         LSR A
         LDA #2
         BCC RANK1
         LDA #1
RANK1    RTS
RANK2    LDA #0
         RTS
;
; ECOPY: entry Y to entry X
;
ECOPY    LDA ENL,Y
         STA ENL,X
         LDA ENH,Y
         STA ENH,X
         LDA ES0,Y
         STA ES0,X
         LDA ES1,Y
         STA ES1,X
         LDA ES2,Y
         STA ES2,X
         LDA ES3,Y
         STA ES3,X
         LDA EFLAG,Y
         STA EFLAG,X
         LDA EDAY,Y
         STA EDAY,X
         LDA EMON,Y
         STA EMON,X
         LDA EYEAR,Y
         STA EYEAR,X
         LDA EHOUR,Y
         STA EHOUR,X
         LDA EMIN,Y
         STA EMIN,X
         RTS
;
; PFIND: the entry called A/Y, in A with the carry clear; or NO and the
; carry set
;
PFIND    STA PTR2
         STY PTR2+1
         LDX SIDE
         LDA BASE
         STA TMP4
         CLC
         ADC PCOUNT,X
         STA TMP3
PFIND1   LDX TMP4
         CPX TMP3
         BCS PFIND3
         LDA ENL,X
         LDY ENH,X
         JSR STRCMP
         BEQ PFIND2
         INC TMP4
         BNE PFIND1
PFIND2   LDA TMP4
         CLC
         RTS
PFIND3   LDA #NO
         SEC
         RTS
;
; ESIZE: NUM = entry X's size; ENAME: A/Y its name
;
ESIZE    LDA ES0,X
         STA NUM
         LDA ES1,X
         STA NUM+1
         LDA ES2,X
         STA NUM+2
         LDA ES3,X
         STA NUM+3
         RTS
ENAME    LDA ENL,X
         LDY ENH,X
         RTS
;
; SBSTAMP: entry X's date, "15.10" "15.10.26" or "15.10 15:20"
;
SBSTAMP  LDA EDAY,X
         BEQ SBSTA2
         STX STK
         JSR SB2
         JSR SBDOT
         LDX STK
         LDA EMON,X
         JSR SB2
         LDX STK
         LDA EYEAR,X
         CMP #NO
         BEQ SBSTA1
         PHA
         JSR SBDOT
         PLA
         JMP SB2
SBSTA1   LDA EHOUR,X
         CMP #NO
         BEQ SBSTA2
         PHA
         JSR SBSP
         PLA
         JSR SB2
         LDA #':
         JSR SBCH
         LDX STK
         LDA EMIN,X
         JMP SB2
SBSTA2   RTS
SBDOT    LDA #'.
         .BYTE $2C          ; BIT: skips the LDA #32
SBSP     LDA #32
         JMP SBCH
;
POOLL    .BYTE <POOL0,<POOL1
POOLH    .BYTE >POOL0,>POOL1
PSIZEL   .BYTE <1024,<1280
PSIZEH   .BYTE >1024,>1280
