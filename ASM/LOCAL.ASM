;
; LOCAL.M65 - EFTP_XL 1.0
; Atari files and folders, by CIO
; Copyright (C) 2026 AERA | Erez Yaary
;
; IOSPEC - buffer = string A/Y, its
; length the string's
;
IOSPEC   STA ICBAL
         STY ICBAH
         JSR STRLEN
IOLEN    STA ICBLL          ; A = length
         LDA #0
         STA ICBLH
         RTS
;
; CCLOSE - close IOCB 5
; IOCMD - CIO command A on IOCB 5
; Exit: A=status, C=1 on error (128+)
;
CCLOSE   LDA #12
IOCMD    STA ICCOM
         LDX #IOCB
         JSR CIOV
         TYA
         CPY #128
         RTS
;
; COPEN - open A/Y, X=aux1:
; 4 read, 8 write, 6 directory
; Exit: C=1 on error, A=status
;
COPEN    STX ICAX1
         LDX #3             ; OPEN
         BNE CXIO1
;
; CXIO - XIO X on A/Y: 32 rename,
; 33 delete, 42 mkdir, 43 rmdir
; Exit: C=1 on error, A=status
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
         LDX ICAX1          ; directory: aux2
         CPX #6             ; $80 asks SpartaDOS
         BNE CXIO2          ; for the long one;
         LDA #$80           ; DOS 2 ignores it
CXIO2    STA ICAX2
         LDA TMP
         LDY TMP3
         JSR IOSPEC
         LDA TMP2
         JMP IOCMD
;
; CGETLN - read a line into A/Y,
; X=buffer size with its 0
; Exit: C=1 on error, A=status;
;       EOL replaced by a 0
;
CGETLN   STA ICBAL
         STA PTR
         STY ICBAH
         STY PTR+1
         DEX
         TXA
         JSR IOLEN
         LDA #5             ; GET RECORD
         JSR IOCMD
         PHP
         PHA
         LDY ICBLL          ; bytes read
         BEQ CGETL1
         DEY
         LDA (PTR),Y
         CMP #EOL
         BEQ CGETL1         ; 0 over the EOL
         INY
CGETL1   LDA #0
         STA (PTR),Y
         PLA
         PLP
         RTS
;
; CPUTLN - write string A/Y and EOL
; Exit: C=1 on error, A=status
;
CPUTLN   JSR IOSPEC
         LDY ICBLL
         STY TMP4
         LDA #EOL           ; EOL over the 0
         STA (PTR),Y
         INY
         TYA
         JSR IOLEN
         LDA #9             ; PUT RECORD
         JSR IOCMD
         PHP
         PHA
         LDY TMP4
         LDA #0             ; the 0 back
         STA (PTR),Y
         PLA
         PLP
         RTS
;
; CREAD - read X pages into A/Y
; Exit: C=1 on error, A=status;
;       CGOT=bytes read (136 too)
;
CREAD    STA ICBAL
         STY ICBAH
         STX ICBLH
         LDA #0
         STA ICBLL
         LDA #7             ; GET BYTES
         JSR IOCMD
         LDX ICBLL
         STX CGOT
         LDX ICBLH
         STX CGOT+1
         RTS
;
; CWRITE - write XLEN bytes from A/Y
; Exit: C=1 on error, A=status
;
CWRITE   STA ICBAL
         STY ICBAH
         LDA XLEN
         STA ICBLL
         LDA XLEN+1
         STA ICBLH
         LDA #11            ; PUT BYTES
         JMP IOCMD
;
; The Atari's pane
;
; LREAD - read folder PATH0 into the
; pane, as DIR does: "*.*", aux1 6
; Exit: C=1 on error, A=CIO status
;
LREAD    LDA #LOCAL
         JSR PUSE
         JSR PCLEAR
         LDA #0
         STA SPARTA
         LDA #'>
         JSR LHASDIR
         BCS LREAD1         ; top: no ".."
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
LREAD2   LDA #<LLINE        ; each line
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
         CMP #136           ; end of directory
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
; LHASDIR - look for A in PATH0
; Exit: C=0 found, PTR on it
;
LHASDIR  PHA
         LDA #<PATH0
         STA PTR
         LDA #>PATH0
         STA PTR+1
         PLA
         JMP FINDCH
;
; LADD - add a line of the listing
; in LLINE to the pane; SpartaDOS's
; starts: empty line, "Volume:"
;
LADD0    RTS
LADD     LDA #<LLINE
         STA PTR3
         LDA #>LLINE
         STA PTR3+1
         JSR PREFIXI        ; SpartaDOS?
         .BYTE "Volume",0
         BCS LADD1
         INC SPARTA
LADD1    JSR STRSTRI
         .BYTE "FREE SECTORS",0
         BCC LADD0          ; the last line
         LDA #<LLINE
         STA PTR3
         LDA #>LLINE
         STA PTR3+1
         LDA #1
         STA LEXT
         LDA SPARTA
         BNE LADD3
;
; DOS 2: "* NAME    EXT 012"
; lock, name in 8, ext in 3, sectors
;
         LDA #<LLINE
         LDY #>LLINE
         JSR STRLEN
         CMP #14
         BCC LADD0          ; too short
         LDA LLINE+1
         CMP #32
         BNE LADD0
         LDA #<[LLINE+2]    ; word 0: name
         STA WLO
         LDA #>[LLINE+2]
         STA WHI
         LDA #<[LLINE+10]   ; word 1: ext
         STA WLO+1
         LDA #>[LLINE+10]
         STA WHI+1
         JSR LNAME
         LDA #<[LLINE+14]
         LDY #>[LLINE+14]
         JSR ATOIP
         LDA #125           ; bytes a sector
         JSR MUL8
         JSR NSIZEW
         JMP LADD8
;
; SpartaDOS: "NAME EXT 1234 date"
; or "NAME <DIR> date"
;
LADD3    JSR PREFIXI
         .BYTE "Volume",0
         BCC LADD9          ; header lines
         JSR PREFIXI
         .BYTE "Directory",0
         BCC LADD9
         LDA #<LLINE
         LDY #>LLINE
         LDX #4
         JSR WORDS
         LDA WCNT
         BEQ LADD9          ; empty line
         LDX #1             ; word after name
         CPX WCNT
         BCS LADD4
         JSR WCH0
         CMP #'<
         BEQ LADD4
         JSR ISDIG
         BCS LADD4
         INX                ; it was the ext
         BNE LADD5
LADD4    LDA #0             ; no extension
         STA LEXT
LADD5    STX TMP4           ; size word
         JSR LNAME
         LDX TMP4
         CPX WCNT
         BCS LADD8
         JSR WCH0
         CMP #'<
         BNE LADD6
         LDA #EDIR          ; <DIR>
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
         LDA NDAY           ; day first: swap
         LDY NMON
         STY NDAY
         STA NMON
LADD8    LDA #<LNAMEB
         LDY #>LNAMEB
         JMP PADD
LADD9    RTS
;
; WDATE - word X, "mm-dd-yy", into
; NMON, NDAY, NYEAR; no time
;
WDATE    JSR WPTR
         JSR ATOL
         LDA NUM
         STA NMON
         JSR INCPTR         ; past the '-'
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
; WPTR - PTR = word X
; WCH0 - A = its first character
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
; NSIZEW - entry's size = NUM
;
NSIZEW   LDA #<NSIZE
         LDY #>NSIZE
         JMP PUTL
;
; LNAME - LNAMEB = word 0 (8 at
; most), and "." word 1 (3 at most)
; when LEXT
;
LNAME    LDX #0
         JSR WPTR
         LDY #0
LNAME1   LDA (PTR),Y
         CMP #33            ; to a space or 0
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
         BCC LNAME4         ; blank ext
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
; WORDS - find words in string A/Y,
; X at most, starts into WLO/WHI
; Exit: WCNT=count, string unchanged
;
WORDS    STA PTR
         STY PTR+1
         STX TMP
         LDX #0
WORDS1   LDY #0
WORDS2   LDA (PTR),Y        ; skip spaces
         CMP #32
         BNE WORDS3
         JSR INCPTR
         JMP WORDS2
WORDS3   CMP #0
         BEQ WORDS5
         CPX TMP
         BEQ WORDS5         ; enough
         LDA PTR
         STA WLO,X
         LDA PTR+1
         STA WHI,X
         INX
WORDS4   JSR INCPTR         ; to its end
         LDA (PTR),Y
         BEQ WORDS5
         CMP #32
         BNE WORDS4
         BEQ WORDS1
WORDS5   STX WCNT
         RTS
;
; LINTO - into folder A/Y:
; "D1:" + "GAMES" -> "D1:>GAMES>"
; Too long for PATH0: no change
;
LINTO    STA PTR3
         STY PTR3+1
         LDA #'>
         JSR LHASDIR
         BCC LINTO1
         LDA #'>            ; top: add a '>'
         JSR LPADD
LINTO1   LDA PTR3
         LDY PTR3+1
         JSR STRLEN
         STA TMP4
         LDA #<PATH0
         LDY #>PATH0
         JSR STRLEN
         SEC
         ADC TMP4           ; both, and '>'
         CMP #PATHLEN-2
         BCS LINTO2         ; too long
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
; LPADD - add char A to PATH0
;
LPADD    PHA
         LDA #<PATH0
         LDY #>PATH0
         JSR SBEND
         PLA
         JMP SBCH
;
; SBEND - go on building at the end
; of string A/Y
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
; LUP - PATH0 up one folder
; Exit: C=1 at the top already
;
LUP      LDA #'>
         JSR LHASDIR
         BCS LUP3
         LDA #<PATH0
         LDY #>PATH0
         JSR STRLEN
         DEY                ; the last '>'
LUP1     DEY                ; to the '>' before
         BEQ LUP2
         LDA PATH0,Y
         CMP #'>
         BNE LUP1
LUP2     LDA PATH0-1,Y
         CMP #':
         BEQ LUP2A          ; "D1:>": to "D1:"
         INY                ; keep this '>'
LUP2A    LDA #0
         STA PATH0,Y
         CLC
LUP3     RTS
;
; LDRIVE - PATH0 = drive A, "Dn:"
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
