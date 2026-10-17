;
; PANE.M65 - EFTP_XL 1.0
; The panes' entries
; Copyright (C) 2026 AERA | Erez Yaary
;
; PUSE - work on pane A: SIDE=A and
; BASE its first entry (Atari 0,
; server MAXE)
; Exit: X=A
;
PUSE     STA SIDE
         TAX
         BEQ PUSE1          ; Atari: BASE 0
         LDA #MAXE
PUSE1    STA BASE
         RTS
;
; PCLEAR - empty pane SIDE
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
; PADD - add the entry named A/Y to
; pane SIDE, with NSIZE, NFLAGS and
; the date NDAY..NMIN (NDAY 0: none)
; Exit: those cleared (NCLEAR);
;       PFULL set if no room
;
PADD4    LDA #1             ; no room
         STA PFULL,X
         JMP NCLEAR
PADD     JSR STRLEN         ; PTR = the name
         STA TMP            ; name length
         LDX SIDE
         LDA PCOUNT,X
         CMP #MAXE
         BEQ PADD4          ; no entry free
; TMP2/3 = pool used with this name
         LDA PUSEDL,X       ; pool used + name + 0
         SEC
         ADC TMP            ; +1 for the 0
         STA TMP2
         LDA PUSEDH,X
         ADC #0
         STA TMP3
         LDA PSIZEL,X       ; PSIZE < TMP2/3?
         CMP TMP2           ; (16-bit compare,
         LDA PSIZEH,X
         SBC TMP3           ; C=0 if so)
         BCC PADD4          ; pool full
         LDA BASE
         CLC
         ADC PCOUNT,X
         TAY                ; Y = the new entry
         LDA POOLL,X        ; its name: next free
         CLC                ; in the pool
         ADC PUSEDL,X
         STA ENL,Y
         STA PTR2
         LDA POOLH,X
         ADC PUSEDH,X
         STA ENH,Y
         STA PTR2+1
         LDA TMP2           ; pool used = that
         STA PUSEDL,X
         LDA TMP3
         STA PUSEDH,X
         INC PCOUNT,X
; its size, date and flags
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
         LSR A              ; EUP to C
         BCS PADD3          ; ".." is not counted
         LSR A              ; EDIR to C
         BCC PADD2
         INC PDIRS,X
         BCS PADD3          ; always
PADD2    INC PFILES,X
PADD3    LDA PTR            ; name into the pool:
         LDY PTR+1          ; PTR still the name
         JSR STRCPY
         JMP NCLEAR
;
; NCLEAR - clear NFLAGS, NDAY and
; NSIZE for the next entry
;
NCLEAR   LDA #0
         STA NFLAGS
         STA NDAY
         STA NSIZE
         STA NSIZE+1
         STA NSIZE+2
         STA NSIZE+3
         RTS
;
; PSORT - sort pane SIDE: ".." first,
; then folders, then files, by name
; (insertion sort, NE the spare):
; PSI goes up from BASE+1; each one
; is held in NE while the sorted
; ones that go after it move up one
;
PSORT    LDX SIDE
         LDA BASE
         STA PSI
         CLC
         ADC PCOUNT,X
         STA PSEND
PSORT1   INC PSI            ; BASE..PSI-1 sorted
         LDA PSI
         CMP PSEND
         BCS PSORT4         ; all done
         LDX #NE            ; hold it in NE
         LDY PSI
         JSR ECOPY
         LDA PSI
         STA PSJ
PSORT2   LDX PSJ            ; PSJ: the gap
         CPX BASE           ; at BASE: no more
         BEQ PSORT3
         DEX
         LDY #NE
         JSR EAFTER         ; PSJ-1 after NE?
         BCC PSORT3
         LDX PSJ            ; yes: move it up
         LDY PSJ
         DEY
         JSR ECOPY
         DEC PSJ
         JMP PSORT2
PSORT3   LDX PSJ            ; into the gap
         LDY #NE
         JSR ECOPY
         JMP PSORT1
PSORT4   RTS
;
; EAFTER - does entry X go after
; entry Y? By RANK, then by name,
; case ignored
; Exit: C=1 if so
;
EAFTER   STX TMP
         STY TMP2
         LDA EFLAG,Y
         JSR RANK
         STA TMP3
         LDA EFLAG,X
         JSR RANK
         CMP TMP3           ; X's rank vs Y's
         BNE EAFT3          ; C=1: X's is higher
         LDA ENL,X
         STA PTR
         LDA ENH,X
         STA PTR+1
         LDA ENL,Y
         STA PTR2
         LDA ENH,Y
         STA PTR2+1
         LDY #0             ; Y: char index
EAFT1    LDA (PTR2),Y       ; Y's name char
         JSR UPPER
         STA TMP4
         LDA (PTR),Y        ; X's name char
         JSR UPPER
         CMP TMP4
         BNE EAFT3          ; C from the compare
         TAX
         BEQ EAFT2          ; the same name
         INY
         BNE EAFT1
EAFT2    CLC                ; same: not after
EAFT3    RTS
;
; RANK - flags A as 0 "..", 1 a
; folder, 2 a file
;
RANK     LSR A              ; EUP to C
         BCS RANK2
         LSR A              ; EDIR to C
         LDA #2             ; LDA keeps C
         BCC RANK1          ; not a folder
         LDA #1
RANK1    RTS
RANK2    LDA #0
         RTS
;
; ECOPY - copy entry Y to entry X
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
; PFIND - find the name A/Y in pane
; SIDE (case counts)
; Exit: C=0, A=entry; else C=1, A=NO
;
PFIND    STA PTR2
         STY PTR2+1
         LDX SIDE
         LDA BASE
         STA TMP4           ; TMP4: entry tried,
         CLC
         ADC PCOUNT,X
         STA TMP3           ; TMP3: the end
PFIND1   LDX TMP4
         CPX TMP3
         BCS PFIND3         ; not there
         LDA ENL,X
         LDY ENH,X
         JSR STRCMP         ; PTR2 kept
         BEQ PFIND2
         INC TMP4
         BNE PFIND1         ; always
PFIND2   LDA TMP4
         CLC
         RTS
PFIND3   LDA #NO
         SEC
         RTS
;
; ESIZE - NUM = entry X's size
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
;
; ENAME - A/Y = entry X's name
;
ENAME    LDA ENL,X
         LDY ENH,X
         RTS
;
; SBSTAMP - add entry X's date:
; "15.10", "15.10.26" or "15.10 15:20"
;
SBSTAMP  LDA EDAY,X
         BEQ SBSTA2         ; no date
         STX STK            ; SB2 changes X
         JSR SB2
         JSR SBDOT
         LDX STK
         LDA EMON,X
         JSR SB2
         LDX STK
         LDA EYEAR,X
         CMP #NO
         BEQ SBSTA1         ; no year: the time?
         PHA                ; the year: SBDOT
         JSR SBDOT          ; loses A
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
;
; SBDOT - add "."; SBSP: a space
;
SBDOT    LDA #'.
         .BYTE $2C          ; BIT: skips LDA #32
SBSP     LDA #32
         JMP SBCH
;
; Each pane's name pool and its size
;
POOLL    .BYTE <POOL0,<POOL1
POOLH    .BYTE >POOL0,>POOL1
PSIZEL   .BYTE <1024,<1280
PSIZEH   .BYTE >1024,>1280
