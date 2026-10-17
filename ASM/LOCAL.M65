;
; LOCAL.M65 - EFTP_XL 1.1
; Atari files and folders, by CIO
; Copyright (C) 2026 AERA | Erez Yaary
;
; IOSPEC - buffer = string A/Y, its
; length the string's
; IOLEN - buffer length = A
; Exit: PTR=string (IOSPEC)
;
IOSPEC   STA ICBAL
         STY ICBAH
         JSR STRLEN
IOLEN    STA ICBLL          ; A = length
         LDA #0             ; under 256
         STA ICBLH
         RTS
;
; CCLOSE - close IOCB 5
; IOCMD - CIO command A on IOCB 5
; Exit: A=status, C=1 on error (128+)
;
CCLOSE   LDA #12            ; CLOSE
IOCMD    STA ICCOM
         LDX #IOCB          ; X = 5*16
         JSR CIOV
         TYA                ; CIO's status in Y
         CPY #128
         RTS
;
; COPEN - open A/Y, X=aux1:
; 4 read, 8 write, 6 directory
; Exit: C=1 on error, A=status
;
COPEN    STX ICAX1
         LDX #3             ; OPEN
         BNE CXIO1          ; always
;
; CXIO - XIO X on A/Y: 32 rename,
; 33 delete, 42 mkdir, 43 rmdir
; Exit: C=1 on error, A=status
;
CXIO     PHA                ; A kept over
         LDA #0             ; aux1 0
         STA ICAX1
         PLA
CXIO1    STX TMP2           ; the command,
         STA TMP            ; and A/Y, kept
         STY TMP3           ; over the CLOSE
         JSR CCLOSE         ; IOCB 5 free first
         LDA #0
         LDX ICAX1          ; directory: aux2
         CPX #6             ; $80 asks SpartaDOS
         BNE CXIO2          ; for the long one;
         LDA #$80           ; DOS 2 ignores it
CXIO2    STA ICAX2
         LDA TMP
         LDY TMP3
         JSR IOSPEC         ; buffer: the spec
         LDA TMP2
         JMP IOCMD
;
; CGETLN - read a line into A/Y,
; X=buffer size with its 0
; Exit: C=1 on error, A=status;
;       EOL replaced by a 0
;
CGETLN   STA ICBAL
         STA PTR            ; PTR too, for the 0
         STY ICBAH
         STY PTR+1
         DEX                ; room for the 0
         TXA
         JSR IOLEN
         LDA #5             ; GET RECORD
         JSR IOCMD
         PHP                ; C and status kept
         PHA                ; for the caller
         LDY ICBLL          ; bytes read
         BEQ CGETL1
         DEY                ; on the last one
         LDA (PTR),Y
         CMP #EOL
         BEQ CGETL1         ; 0 over the EOL
         INY                ; none: 0 after it
CGETL1   LDA #0
         STA (PTR),Y
         PLA
         PLP
         RTS
;
; CPUTLN - write string A/Y and EOL
; (the EOL goes over its 0 a while)
; Exit: C=1 on error, A=status
;
CPUTLN   JSR IOSPEC         ; PTR on it
         LDY ICBLL          ; Y = its length
         STY TMP4
         LDA #EOL           ; EOL over the 0
         STA (PTR),Y
         INY                ; length with EOL
         TYA
         JSR IOLEN
         LDA #9             ; PUT RECORD
         JSR IOCMD
         PHP                ; C and status kept
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
         STX ICBLH          ; X*256 bytes
         LDA #0
         STA ICBLL
         LDA #7             ; GET BYTES
         JSR IOCMD
         LDX ICBLL          ; CIO leaves the
         STX CGOT           ; count read here;
         LDX ICBLH          ; LDX: A and C kept
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
; Exit: C=1 on error, A=CIO status;
;       C=0, A=1 when all read
;
LREAD    LDA #LOCAL
         JSR PUSE           ; the Atari pane
         JSR PCLEAR
         LDA #0             ; DOS 2 until a
         STA SPARTA         ; "Volume" line
         LDA #'>
         JSR LHASDIR        ; in a folder?
         BCS LREAD1         ; top: no ".."
         LDA #EUP
         STA NFLAGS
         LDA #<DOTDOT
         LDY #>DOTDOT
         JSR PADD
;
; FSPEC = PATH0 and "*.*", as
; "D1:>GAMES>*.*"; open it as a
; directory, a line an entry
;
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
         LDX #6             ; directory
         JSR COPEN
         BCS LREAD4
LREAD2   LDA #<LLINE        ; each line
         LDY #>LLINE
         LDX #64            ; LLINE's size
         JSR CGETLN
         BCS LREAD3         ; 136 after the last
         JSR LADD
         JMP LREAD2
LREAD3   PHA                ; status kept
         JSR CCLOSE
         JSR PSORT
         PLA
         CMP #136           ; end of directory
         BNE LREAD5         ; else a real error
         LDA #1             ; status 1: all well
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
; ('>': in a folder, not the top)
; Exit: C=0 found, PTR on it
;
LHASDIR  PHA                ; A kept over
         LDA #<PATH0        ; setting PTR
         STA PTR
         LDA #>PATH0
         STA PTR+1
         PLA
         JMP FINDCH
;
; LADD - add a line of the listing
; in LLINE to the pane; SpartaDOS's
; starts: empty line, "Volume:"
; Both end "nnn FREE SECTORS"
;
LADD0    RTS
LADD     LDA #<LLINE
         STA PTR3
         LDA #>LLINE
         STA PTR3+1
         JSR PREFIXI        ; SpartaDOS?
         .BYTE "Volume",0
         BCS LADD1
         INC SPARTA         ; yes: all lines on
LADD1    JSR STRSTRI        ; anywhere in it
         .BYTE "FREE SECTORS",0
         BCC LADD0          ; the last line
         LDA #<LLINE        ; STRSTR moved PTR3:
         STA PTR3           ; back to the start
         LDA #>LLINE
         STA PTR3+1
         LDA #1             ; an ext unless
         STA LEXT           ; found otherwise
         LDA SPARTA
         BNE LADD3
;
; DOS 2: "* NAME    EXT 012"
; lock, name in 8, ext in 3, sectors
; Fixed columns: 0 '*' if locked,
; 2 name, 10 ext, 14 sectors
; ("  DOS     SYS 037"). SpartaDOS's
; empty first line goes here too
;
         LDA #<LLINE
         LDY #>LLINE
         JSR STRLEN
         CMP #14
         BCC LADD0          ; too short
         LDA LLINE+1        ; column 1 a space,
         CMP #32            ; or not an entry
         BNE LADD0
;
; Words 0 and 1 for LNAME set by
; hand, at the columns; LNAME stops
; at the spaces after them
;
         LDA #<[LLINE+2]    ; word 0: name
         STA WLO
         LDA #>[LLINE+2]
         STA WHI
         LDA #<[LLINE+10]   ; word 1: ext
         STA WLO+1
         LDA #>[LLINE+10]
         STA WHI+1
         JSR LNAME          ; "DOS.SYS"
         LDA #<[LLINE+14]   ; "037": sectors
         LDY #>[LLINE+14]
         JSR ATOIP
         LDA #125           ; bytes a sector
         JSR MUL8           ; (128 less 3 links)
         JSR NSIZEW         ; size, about
         JMP LADD8
;
; SpartaDOS: "NAME EXT 1234 date"
; or "NAME <DIR> date", the date
; "dd-mm-yy"; "Volume:" and
; "Directory:" lines are skipped
;
LADD3    JSR PREFIXI
         .BYTE "Volume",0
         BCC LADD9          ; header lines
         JSR PREFIXI
         .BYTE "Directory",0
         BCC LADD9
;
; Into 4 words at most, the time
; left out: "DOS SYS 1234 31-12-89"
; or "README 1234 31-12-89 12:00"
;
         LDA #<LLINE
         LDY #>LLINE
         LDX #4
         JSR WORDS
         LDA WCNT
         BEQ LADD9          ; empty line
;
; Word 1 is the ext unless it is
; "<DIR>" or a number (the size);
; X = the size word, 1 or 2
;
         LDX #1             ; word after name
         CPX WCNT
         BCS LADD4          ; none: name only
         JSR WCH0
         CMP #'<
         BEQ LADD4          ; "<DIR>"
         JSR ISDIG
         BCS LADD4          ; the size
         INX                ; it was the ext
         BNE LADD5          ; always
LADD4    LDA #0             ; no extension
         STA LEXT
LADD5    STX TMP4           ; size word
         JSR LNAME          ; "DOS.SYS"
         LDX TMP4
         CPX WCNT
         BCS LADD8          ; no size word
         JSR WCH0
         CMP #'<
         BNE LADD6
         LDA #EDIR          ; <DIR>
         STA NFLAGS
         BNE LADD7          ; always
LADD6    JSR WPTR
         JSR ATOL           ; "1234": bytes
         JSR NSIZEW
LADD7    LDX TMP4           ; the date: the
         INX                ; word after it
         CPX WCNT
         BCS LADD8          ; none
         JSR WDATE
         LDA NDAY           ; day first: swap
         LDY NMON
         STY NDAY
         STA NMON
LADD8    LDA #<LNAMEB       ; the entry, with
         LDY #>LNAMEB       ; NSIZE and NFLAGS
         JMP PADD
LADD9    RTS
;
; WDATE - word X, "mm-dd-yy", into
; NMON, NDAY, NYEAR; no time
;
WDATE    JSR WPTR           ; PTR on "10-15-26"
         JSR ATOL           ; 10, PTR on '-'
         LDA NUM
         STA NMON
         JSR INCPTR         ; past the '-'
         JSR ATOL           ; 15
         LDA NUM
         STA NDAY
         JSR INCPTR
         JSR ATOL           ; 26
         LDA NUM
         STA NYEAR
         LDA #NO
         STA NHOUR
         RTS
;
; WPTR - PTR = word X
; WCH0 - A = its first character
; Exit: X kept; WCH0: Y=0
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
; when LEXT: "DOS" "SYS" "DOS.SYS"
; A word ends at a space or the 0
;
LNAME    LDX #0
         JSR WPTR           ; PTR on word 0
         LDY #0             ; Y: in both
LNAME1   LDA (PTR),Y
         CMP #33            ; to a space or 0
         BCC LNAME2
         STA LNAMEB,Y
         INY
         CPY #8
         BNE LNAME1
LNAME2   STY TMP            ; name's length
         LDA LEXT
         BEQ LNAME4
         LDX #1
         JSR WCH0           ; PTR on word 1
         CMP #33
         BCC LNAME4         ; blank ext
         LDX TMP            ; X: in LNAMEB,
         LDA #'.            ; Y: in the ext
         STA LNAMEB,X
LNAME3   INX
         LDA (PTR),Y
         CMP #33
         BCC LNAME4A        ; ext ended
         STA LNAMEB,X
         INY
         CPY #3
         BNE LNAME3
         INX                ; 3 taken: past them
LNAME4A  STX TMP            ; the 0 goes here
LNAME4   LDX TMP
         LDA #0
         STA LNAMEB,X
         RTS
;
; WORDS - find words in string A/Y,
; X at most, starts into WLO/WHI
; Exit: WCNT=count, string unchanged
; (a word ends at a space or the 0)
;
WORDS    STA PTR
         STY PTR+1
         STX TMP            ; the most to take
         LDX #0             ; X: words found
WORDS1   LDY #0             ; Y stays 0, PTR moves
WORDS2   LDA (PTR),Y        ; skip spaces
         CMP #32
         BNE WORDS3
         JSR INCPTR
         JMP WORDS2
WORDS3   CMP #0
         BEQ WORDS5         ; line ended
         CPX TMP
         BEQ WORDS5         ; enough
         LDA PTR            ; word X starts here
         STA WLO,X
         LDA PTR+1
         STA WHI,X
         INX
WORDS4   JSR INCPTR         ; to its end
         LDA (PTR),Y
         BEQ WORDS5
         CMP #32
         BNE WORDS4
         BEQ WORDS1         ; always: next one
WORDS5   STX WCNT
         RTS
;
; LINTO - into folder A/Y:
; "D1:" + "GAMES" -> "D1:>GAMES>"
; Too long for PATH0: name not added
;
LINTO    STA PTR3
         STY PTR3+1
         LDA #'>
         JSR LHASDIR
         BCC LINTO1         ; in a folder
         LDA #'>            ; top: add a '>'
         JSR LPADD          ; "D1:>"
LINTO1   LDA PTR3
         LDY PTR3+1
         JSR STRLEN
         STA TMP4           ; name's length
         LDA #<PATH0
         LDY #>PATH0
         JSR STRLEN
         SEC                ; +1:
         ADC TMP4           ; both, and '>'
         CMP #PATHLEN-2
         BCS LINTO2         ; too long
         LDA #<PATH0
         LDY #>PATH0
         JSR SBEND          ; on at PATH0's 0
         LDA PTR3
         LDY PTR3+1
         JSR SBADD          ; the name
         LDA #'>
         JMP SBCH           ; and its '>'
LINTO2   RTS
;
; LPADD - add char A to PATH0
;
LPADD    PHA                ; A kept over SBEND
         LDA #<PATH0
         LDY #>PATH0
         JSR SBEND
         PLA
         JMP SBCH
;
; SBEND - go on building at the end
; of string A/Y
;
SBEND    JSR STRLEN         ; PTR on it, A=len
         CLC
         ADC PTR            ; SBP = its 0
         STA SBP
         LDA PTR+1
         ADC #0
         STA SBP+1
         RTS
;
; LUP - PATH0 up one folder:
; "D1:>GAMES>SUB>" -> "D1:>GAMES>",
; "D1:>GAMES>" -> "D1:"
; Exit: C=1 at the top already
;
LUP      LDA #'>
         JSR LHASDIR
         BCS LUP3           ; no '>': the top
         LDA #<PATH0
         LDY #>PATH0
         JSR STRLEN         ; Y = length
         DEY                ; the last '>'
LUP1     DEY                ; to the '>' before
         BEQ LUP2
         LDA PATH0,Y
         CMP #'>
         BNE LUP1
LUP2     LDA PATH0-1,Y      ; the char before it
         CMP #':
         BEQ LUP2A          ; "D1:>": to "D1:"
         INY                ; keep this '>'
LUP2A    LDA #0             ; cut PATH0 here
         STA PATH0,Y
         CLC
LUP3     RTS
;
; LDRIVE - PATH0 = drive A, "Dn:"
; A=the drive's number, 1-8
;
LDRIVE   ORA #'0            ; 1 to '1'
         STA PATH0+1
         LDA #'D
         STA PATH0
         LDA #':
         STA PATH0+2
         LDA #0
         STA PATH0+3
         RTS
