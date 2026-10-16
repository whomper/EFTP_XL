;
; EFTP_XL - the Atari side: files and folders through CIO, so any DOS
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; The CIO calls (IOCB 5) return the status in A, the carry set when it
; is an error (128 and up).
;
; IOSPEC: the buffer is the string A/Y, its length the length
;
IOSPEC   STA ICBAL
         STY ICBAH
         JSR STRLEN
IOLEN    STA ICBLL
         LDA #0
         STA ICBLH
         RTS
;
CCLOSE   LDA #12
IOCMD    STA ICCOM
         LDX #IOCB
         JSR CIOV
         TYA
         CPY #128
         RTS
;
; COPEN: open A/Y with aux1 X (4 read, 8 write, 6 a directory)
;
COPEN    STX ICAX1
         LDX #3
         BNE CXIO1
;
; CXIO: XIO X on A/Y: 32 rename, 33 delete, 42 new folder, 43 remove
;
CXIO     PHA
         LDA #0
         STA ICAX1
         PLA
CXIO1    STX TMP2
         STA TMP
         STY TMP3
         JSR CCLOSE
         LDA #0
         LDX ICAX1          ; a directory: SpartaDOS's long one, with
         CPX #6             ; bytes and <DIR> (aux2 $80; DOS 2 takes
         BNE CXIO2          ; no notice of it)
         LDA #$80
CXIO2    STA ICAX2
         LDA TMP
         LDY TMP3
         JSR IOSPEC
         LDA TMP2
         JMP IOCMD
;
; CGETLN: a line into A/Y, X bytes at most with its 0 (the EOL goes)
;
CGETLN   STA ICBAL
         STA PTR
         STY ICBAH
         STY PTR+1
         DEX
         TXA
         JSR IOLEN
         LDA #5
         JSR IOCMD
         PHP
         PHA
         LDY ICBLL
         BEQ CGETL1
         DEY
         LDA (PTR),Y
         CMP #EOL
         BEQ CGETL1
         INY
CGETL1   LDA #0
         STA (PTR),Y
         PLA
         PLP
         RTS
;
; CPUTLN: the string A/Y as a line (with an EOL)
;
CPUTLN   JSR IOSPEC
         LDY ICBLL
         STY TMP4
         LDA #EOL
         STA (PTR),Y
         INY
         TYA
         JSR IOLEN
         LDA #9
         JSR IOCMD
         PHP
         PHA
         LDY TMP4
         LDA #0
         STA (PTR),Y
         PLA
         PLP
         RTS
;
; CREAD: X pages into A/Y; CGOT how many bytes came (with 136 too)
;
CREAD    STA ICBAL
         STY ICBAH
         STX ICBLH
         LDA #0
         STA ICBLL
         LDA #7
         JSR IOCMD
         LDX ICBLL
         STX CGOT
         LDX ICBLH
         STX CGOT+1
         RTS
;
; CWRITE: XLEN bytes from A/Y
;
CWRITE   STA ICBAL
         STY ICBAH
         LDA XLEN
         STA ICBLL
         LDA XLEN+1
         STA ICBLH
         LDA #11
         JMP IOCMD
;
; -- the Atari's pane
;
; A directory is read the way DOS's own DIR does, opening "Dn:...*.*"
; with aux1 6 and reading its lines:
;
;   DOS 2.5    "* NAME     EXT 012"    (lock, name, ext, sectors)
;              "609 FREE SECTORS"
;   SpartaDOS  "Volume:    ..."  "Directory: ..."  (its header)
;              "NAME     EXT    1234 12-03-89 12:00"   (bytes)
;              "GAMES        <DIR>  12-03-89 12:00"
;              "  708 FREE SECTORS"
;
; LREAD: PATH0 into the pane; the carry set and A the CIO error when
; it failed
;
LREAD    LDA #LOCAL
         JSR PUSE
         JSR PCLEAR
         LDA #0
         STA SPARTA
         LDA #'>
         JSR LHASDIR
         BCS LREAD1
         LDA #EUP
         STA NFLAGS
         LDA #<DOTDOT
         LDY #>DOTDOT
         JSR PADD
LREAD1   LDA #<FSPEC
         LDY #>FSPEC
         JSR SBSTART
         LDA #<PATH0
         LDY #>PATH0
         JSR SBADD
         JSR SBI
         .BYTE "*.*",0
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #6
         JSR COPEN
         BCS LREAD4
LREAD2   LDA #<LLINE
         LDY #>LLINE
         LDX #64
         JSR CGETLN
         BCS LREAD3
         JSR LADD
         JMP LREAD2
LREAD3   PHA
         JSR CCLOSE
         JSR PSORT
         PLA
         CMP #136           ; the end of the directory
         BNE LREAD5
         LDA #1
         CLC
         RTS
LREAD4   PHA
         JSR CCLOSE
         PLA
LREAD5   SEC
         RTS
DOTDOT   .BYTE "..",0
;
; LHASDIR: is A in PATH0? carry clear when so, PTR on it
;
LHASDIR  PHA
         LDA #<PATH0
         STA PTR
         LDA #>PATH0
         STA PTR+1
         PLA
         JMP FINDCH
;
; LADD: a line of the listing into the pane
;
LADD0    RTS
LADD     LDA #<LLINE
         STA PTR3
         LDA #>LLINE
         STA PTR3+1
         JSR PREFIXI        ; SpartaDOS's header, after an empty line
         .BYTE "Volume",0
         BCS LADD1
         INC SPARTA
LADD1    JSR STRSTRI
         .BYTE "FREE SECTORS",0
         BCC LADD0
         LDA #<LLINE
         STA PTR3
         LDA #>LLINE
         STA PTR3+1
         LDA #1
         STA LEXT
         LDA SPARTA
         BNE LADD3
;
; DOS 2: lock flag, space, name in 8 columns, extension in the next 3,
; space, sectors: "* STARRAIDXEX 012"
;
         LDA #<LLINE
         LDY #>LLINE
         JSR STRLEN
         CMP #14
         BCC LADD0
         LDA LLINE+1
         CMP #32
         BNE LADD0
         LDA #<[LLINE+2]
         STA WLO
         LDA #>[LLINE+2]
         STA WHI
         LDA #<[LLINE+10]
         STA WLO+1
         LDA #>[LLINE+10]
         STA WHI+1
         JSR LNAME
         LDA #<[LLINE+14]
         LDY #>[LLINE+14]
         JSR ATOIP
         LDA #125
         JSR MUL8
         JSR NSIZEW
         JMP LADD8
;
; SpartaDOS: NAME [EXT] size or <DIR>, date
;
LADD3    JSR PREFIXI
         .BYTE "Volume",0
         BCC LADD9
         JSR PREFIXI
         .BYTE "Directory",0
         BCC LADD9
         LDA #<LLINE
         LDY #>LLINE
         LDX #4
         JSR WORDS
         LDA WCNT
         BEQ LADD9
         LDX #1             ; the word after the name
         CPX WCNT
         BCS LADD4
         JSR WCH0
         CMP #'<
         BEQ LADD4
         JSR ISDIG
         BCS LADD4
         INX                ; it was the extension
         BNE LADD5
LADD4    LDA #0             ; no extension
         STA LEXT
LADD5    STX TMP4
         JSR LNAME
         LDX TMP4
         CPX WCNT
         BCS LADD8
         JSR WCH0
         CMP #'<
         BNE LADD6
         LDA #EDIR
         STA NFLAGS
         BNE LADD7
LADD6    JSR WPTR
         JSR ATOL
         JSR NSIZEW
LADD7    LDX TMP4
         INX
         CPX WCNT
         BCS LADD8
         JSR WDATE
         LDA NDAY           ; "12-03-89": the day first
         LDY NMON
         STY NDAY
         STA NMON
LADD8    LDA #<LNAMEB
         LDY #>LNAMEB
         JMP PADD
LADD9    RTS
;
; WDATE: word X as "mm-dd-yy" into NMON, NDAY, NYEAR; no time
;
WDATE    JSR WPTR
         JSR ATOL
         LDA NUM
         STA NMON
         JSR INCPTR
         JSR ATOL
         LDA NUM
         STA NDAY
         JSR INCPTR
         JSR ATOL
         LDA NUM
         STA NYEAR
         LDA #NO
         STA NHOUR
         RTS
;
; WPTR: PTR = word X; WCH0: its first character
;
WPTR     LDA WLO,X
         STA PTR
         LDA WHI,X
         STA PTR+1
         RTS
WCH0     JSR WPTR
         LDY #0
         LDA (PTR),Y
         RTS
;
; NSIZEW: the entry's size is NUM
;
NSIZEW   LDA #<NSIZE
         LDY #>NSIZE
         JMP PUTL
;
; LNAME: LNAMEB = word 0 (8 at most, to a space), and "." word 1 (3
; at most) when LEXT
;
LNAME    LDX #0
         JSR WPTR
         LDY #0
LNAME1   LDA (PTR),Y
         CMP #33
         BCC LNAME2
         STA LNAMEB,Y
         INY
         CPY #8
         BNE LNAME1
LNAME2   STY TMP
         LDA LEXT
         BEQ LNAME4
         LDX #1
         JSR WCH0
         CMP #33
         BCC LNAME4
         LDX TMP
         LDA #'.
         STA LNAMEB,X
LNAME3   INX
         LDA (PTR),Y
         CMP #33
         BCC LNAME4A
         STA LNAMEB,X
         INY
         CPY #3
         BNE LNAME3
         INX
LNAME4A  STX TMP
LNAME4   LDX TMP
         LDA #0
         STA LNAMEB,X
         RTS
;
; WORDS: the starts of the words of A/Y, X of them at most, into
; WLO/WHI; WCNT how many (the string is left as it is)
;
WORDS    STA PTR
         STY PTR+1
         STX TMP
         LDX #0
WORDS1   LDY #0
WORDS2   LDA (PTR),Y
         CMP #32
         BNE WORDS3
         JSR INCPTR
         JMP WORDS2
WORDS3   CMP #0
         BEQ WORDS5
         CPX TMP
         BEQ WORDS5
         LDA PTR
         STA WLO,X
         LDA PTR+1
         STA WHI,X
         INX
WORDS4   JSR INCPTR
         LDA (PTR),Y
         BEQ WORDS5
         CMP #32
         BNE WORDS4
         BEQ WORDS1
WORDS5   STX WCNT
         RTS
;
; LINTO: into the folder A/Y: "D1:" + "GAMES" -> "D1:>GAMES>"
;
LINTO    STA PTR3
         STY PTR3+1
         LDA #'>
         JSR LHASDIR
         BCC LINTO1
         LDA #'>
         JSR LPADD
LINTO1   LDA PTR3
         LDY PTR3+1
         JSR STRLEN
         STA TMP4
         LDA #<PATH0
         LDY #>PATH0
         JSR STRLEN
         SEC
         ADC TMP4
         CMP #PATHLEN-2
         BCS LINTO2
         LDA #<PATH0
         LDY #>PATH0
         JSR SBEND
         LDA PTR3
         LDY PTR3+1
         JSR SBADD
         LDA #'>
         JMP SBCH
LINTO2   RTS
;
; LPADD: A on the end of PATH0
;
LPADD    PHA
         LDA #<PATH0
         LDY #>PATH0
         JSR SBEND
         PLA
         JMP SBCH
;
; SBEND: go on building at the end of the string A/Y
;
SBEND    JSR STRLEN
         CLC
         ADC PTR
         STA SBP
         LDA PTR+1
         ADC #0
         STA SBP+1
         RTS
;
; LUP: the folder above; carry set when already at the top of the drive
;
LUP      LDA #'>
         JSR LHASDIR
         BCS LUP3
         LDA #<PATH0
         LDY #>PATH0
         JSR STRLEN
         DEY                ; the last '>'
LUP1     DEY
         BEQ LUP2
         LDA PATH0,Y
         CMP #'>
         BNE LUP1
LUP2     LDA PATH0-1,Y
         CMP #':
         BEQ LUP2A
         INY                ; keep this '>'
LUP2A    LDA #0
         STA PATH0,Y
         CLC
LUP3     RTS
;
; LDRIVE: drive A: "D1:" .. "D8:"
;
LDRIVE   ORA #'0
         STA PATH0+1
         LDA #'D
         STA PATH0
         LDA #':
         STA PATH0+2
         LDA #0
         STA PATH0+3
         RTS
