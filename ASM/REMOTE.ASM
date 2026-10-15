;
; EFTP_XL - the server's pane
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; LIST has no standard format; the two seen in practice are
;
;   Unix  "drwxr-xr-x  2 user group  4096 Oct 15 15:20 games"
;         "-rw-r--r--  1 user group 249856 Apr 22  2024 STinG 1.26.zip"
;   DOS   "10-15-26  03:33PM       <DIR>          games"
;         "10-15-26  03:33PM               14336 index.html"
;
; Anything else is left out.
;
; RREAD: the server's folder into its pane, PATH1 from PWD
;
RREAD    LDA #REMOTE
         JSR PUSE
         JSR PCLEAR
         JSR FPWD
         BCS RREAD2
         LDA PATH1          ; not at "/": ".." first
         CMP #'/
         BNE RREAD1
         LDA PATH1+1
         BEQ RREAD1A
RREAD1   LDA #EUP
         STA NFLAGS
         LDA #<DOTDOT
         LDY #>DOTDOT
         JSR PADD
RREAD1A  JSR FLIST
         PHP
         PHA
         LDA #REMOTE
         JSR PUSE
         JSR PSORT
         PLA
         PLP
RREAD2   RTS
;
; RADD: the line in FLINE into the pane
;
RADD0    RTS
RADD     LDA FLINE
         JSR ISDIG
         BCC RADD3
;
; DOS: date, time, <DIR> or size, name
;
         LDA #<FLINE
         LDY #>FLINE
         LDX #4
         JSR WORDS
         LDA WCNT
         CMP #4
         BCC RADD0
         LDX #2
         JSR WCH0
         CMP #'<
         BNE RADD1
         LDA #EDIR
         STA NFLAGS
         BNE RADD2
RADD1    JSR ATOL
         JSR NSIZEW
RADD2    LDX #0
         JSR WDATE
         LDX #3
         BNE RADD7
;
; Unix: flags links owner group size month day time-or-year name
;
RADD3    CMP #'-
         BEQ RADD4
         CMP #'d
         BEQ RADD4
         CMP #'l
         BNE RADD0
RADD4    LDA #<FLINE
         LDY #>FLINE
         LDX #9
         JSR WORDS
         LDA WCNT
         CMP #9
         BCC RADD0
         LDA FLINE
         CMP #'d
         BNE RADD5
         LDA #EDIR
         STA NFLAGS
         BNE RADD6
RADD5    LDX #4
         JSR WPTR
         JSR ATOL
         JSR NSIZEW
RADD6    JSR UDATE
         LDA FLINE          ; a link: its name, not where it points
         CMP #'l
         BNE RADD6A
         LDX #8
         JSR WPTR
         LDA PTR
         STA PTR3
         LDA PTR+1
         STA PTR3+1
         JSR STRSTRI
         .BYTE " -> ",0
         BCS RADD6A
         LDA #0
         TAY
         STA (PTR3),Y
RADD6A   LDX #8
RADD7    JSR WPTR           ; "." and ".." are left out
         LDA #<DOTDOT+1
         STA PTR2
         LDA #>[DOTDOT+1]
         STA PTR2+1
         LDA PTR
         LDY PTR+1
         JSR STRCMP
         BEQ RADD8
         LDA #<DOTDOT
         STA PTR2
         LDA #>DOTDOT
         STA PTR2+1
         LDA PTR
         LDY PTR+1
         JSR STRCMP
         BEQ RADD8
         LDA PTR
         LDY PTR+1
         JMP PADD
RADD8    JMP NCLEAR
RADD9    RTS
;
; UDATE: words 5, 6, 7: "Oct 15 15:20" (this year) or "Apr 22 2024"
;
UDATE    LDX #5
         JSR WPTR
         LDY #2
UDATE1   LDA (PTR),Y
         STA MW,Y
         DEY
         BPL UDATE1
         LDX #0
         LDY #1
UDATE2   LDA MONTHS,X
         CMP MW
         BNE UDATE3
         LDA MONTHS+1,X
         CMP MW+1
         BNE UDATE3
         LDA MONTHS+2,X
         CMP MW+2
         BEQ UDATE4
UDATE3   INX
         INX
         INX
         INY
         CPY #13
         BNE UDATE2
         LDY #0
UDATE4   STY NMON
         LDX #6
         JSR WPTR
         JSR ATOL
         LDA NUM
         STA NDAY
         LDX #7
         JSR WPTR
         LDY #2
         LDA (PTR),Y
         CMP #':
         BNE UDATE5
         JSR ATOL
         LDA NUM
         STA NHOUR
         JSR INCPTR
         JSR ATOL
         LDA NUM
         STA NMIN
         LDA #NO
         STA NYEAR
         RTS
UDATE5   JSR ATOL           ; the year, 2024 as 24
         LDA #100
         STA NUM2
         LDA #0
         STA NUM2+1
         STA NUM2+2
         STA NUM2+3
         JSR DIV32
         LDA REM
         STA NYEAR
         LDA #NO
         STA NHOUR
         RTS
MONTHS   .BYTE "JanFebMarAprMayJunJulAugSepOctNovDec"
