;
; TEXT.M65 - EFTP_XL 1.0
; Strings, lines and 32-bit numbers
; Copyright (C) 2026 AERA | Erez Yaary
;
; INLINE - string after the JSR, for
; the ...I routines:
;          JSR SBI
;          .BYTE " files",0
; Their first instruction; returns
; past the 0
; Exit: A/Y=PTR=string
;
INLINE   PLA                ; our return
         STA IRET
         PLA
         STA IRET+1
         PLA                ; the caller's
         STA PTR
         PLA
         STA PTR+1
         JSR INCPTR         ; string starts here
         LDA PTR
         LDY PTR+1
         JSR STRLEN
         CLC
         ADC PTR
         TAX
         LDA PTR+1
         ADC #0
         PHA                ; return to the 0
         TXA
         PHA
         LDA IRET+1
         PHA
         LDA IRET
         PHA
         LDA PTR
         LDY PTR+1
         RTS
;
; INCPTR - PTR + 1
;
INCPTR   INC PTR
         BNE INCP1
         INC PTR+1
INCP1    RTS
;
; STRLEN - length of a string
; A/Y=string
; Exit: A=Y=length (255 max), Z=1
;       if empty, PTR=string
;
STRLEN   STA PTR
         STY PTR+1
         LDY #0
STRL1    LDA (PTR),Y
         BEQ STRL2
         INY
         BNE STRL1
STRL2    TYA
         RTS
;
; STRCPY - copy A/Y to PTR2, with
; the 0
; Exit: Y=length
;
STRCPY   STA PTR
         STY PTR+1
         LDY #0
STRC1    LDA (PTR),Y
         STA (PTR2),Y
         BEQ STRC2
         INY
         BNE STRC1
STRC2    RTS
;
; STRCMP - A/Y same as PTR2?
; Case counts
; Exit: Z=1 if the same
;
STRCMP   STA PTR
         STY PTR+1
         LDY #0
STRM1    LDA (PTR),Y
         CMP (PTR2),Y
         BNE STRM2
         TAX                ; both ended?
         BEQ STRM2
         INY
         BNE STRM1
STRM2    RTS
;
; FINDCH - PTR on to char A in its
; string
; Exit: C=0 found, C=1 none
;
FINDCH   STA TMP4
FINDC1   LDY #0
         LDA (PTR),Y
         BEQ FINDC2
         CMP TMP4
         BEQ FINDC3
         JSR INCPTR
         JMP FINDC1
FINDC2   SEC
         RTS
FINDC3   CLC
         RTS
;
; STRSTR - find A/Y in the string
; at PTR3
; Exit: C=0 found, PTR3 on it;
;       C=1 not there
;
STRSTRI  JSR INLINE
STRSTR   STA PTR2
         STY PTR2+1
STRS1    JSR PREFIX1
         BCC STRS3
         LDY #0
         LDA (PTR3),Y
         BEQ STRS2          ; end: not there
         INC PTR3
         BNE STRS1
         INC PTR3+1
         BNE STRS1
STRS2    SEC
STRS3    RTS
;
; PREFIX - string at PTR3 starts
; with A/Y?
; Exit: C=0 yes, C=1 no
;
PREFIXI  JSR INLINE
PREFIX   STA PTR2
         STY PTR2+1
PREFIX1  LDY #0
PREF1    LDA (PTR2),Y
         BEQ PREF2          ; all of A/Y matched
         CMP (PTR3),Y
         BNE STRS2
         INY
         BNE PREF1
PREF2    CLC
         RTS
;
; UPPER - A in capitals
;
UPPER    CMP #'a
         BCC UPP1
         CMP #'z+1
         BCS UPP1
         SBC #31            ; carry is clear: - 32
UPP1     RTS
;
; UPSTR - string A/Y in capitals,
; in place
;
UPSTR    STA PTR
         STY PTR+1
         LDY #0
UPS1     LDA (PTR),Y
         BEQ UPP1
         JSR UPPER
         STA (PTR),Y
         INY
         BNE UPS1
;
; ISDIG, ISALPH, ISALNUM - is A a
; digit, letter, either?
; Exit: C=1 yes, A kept
;
ISDIG    CMP #'9+1
         BCS ISNOT
         CMP #'0            ; C=1 if 0-9
         RTS
ISNOT    CLC
         RTS
ISALPH   PHA
         JSR UPPER
         CMP #'Z+1
         BCS ISAL1
         CMP #'A
         PLA
         RTS
ISAL1    PLA
         CLC
         RTS
ISALNUM  JSR ISDIG
         BCC ISALPH
         RTS
;
; Building a line at SBP: SBSTART,
; then SBADD, SBI, SBCH, SBNUM,
; SBBYTE, SBSIZE; always 0 ended
;
; SBSTART - start an empty line
; A/Y=buffer
;
SBSTART  STA SBP
         STY SBP+1
         LDA #0
         TAY
         STA (SBP),Y
         RTS
;
; SBADD - add string A/Y
; SBI - add the string after the JSR
;
SBI      JSR INLINE
SBADD    STA PTR
         STY PTR+1
         LDY #0
SBA1     LDA (PTR),Y
         BEQ SBA2
         JSR SBCH
         INY
         BNE SBA1
SBA2     RTS
;
; SBCH - add char A
; X and Y kept
;
SBCH     STY PCY
         LDY #0
         STA (SBP),Y
         INC SBP
         BNE SBC1
         INC SBP+1
SBC1     TYA                ; new 0 after it
         STA (SBP),Y
         LDY PCY
         RTS
;
; SBNUM - add NUM's low 16 bits in
; digits, no leading 0s
; NUM is lost
;
SBNUM    LDX #0
         STX TMP2           ; a digit seen yet
SBN1     LDA #'0
         STA TMP3
SBN2     LDA NUM            ; take off 10^n
         SEC
         SBC POWLO,X
         TAY
         LDA NUM+1
         SBC POWHI,X
         BCC SBN3
         STA NUM+1
         STY NUM
         INC TMP3
         BNE SBN2
SBN3     LDA TMP3
         CPX #4             ; always the last
         BEQ SBN4
         CMP #'0
         BNE SBN4
         LDY TMP2
         BEQ SBN5           ; leading 0
SBN4     STA TMP2
         JSR SBCH
SBN5     INX
         CPX #5
         BNE SBN1
         RTS
POWLO    .BYTE <10000,<1000,<100,<10,<1
POWHI    .BYTE >10000,>1000,>100,>10,>1
;
; SBBYTE - add A in digits
; SB2 - the same, two digits at least
;
SB2      CMP #10
         BCS SBBYTE
         PHA
         LDA #'0
         JSR SBCH
         PLA
SBBYTE   STA NUM
         LDA #0
         STA NUM+1
         JMP SBNUM
;
; SBSIZE - add NUM in 4 chars at
; most: "999", "244K", "13M"
; NUM is lost
;
SBSIZE   LDA #0
         STA SUNIT
         JSR GE1000
         BCC SBS1
         LDA #<1023         ; K, rounded up
         LDX #>1023
         JSR SHR10
         LDA #'K
         STA SUNIT
         JSR GE1000
         BCC SBS1
         LDA #<512          ; M, rounded
         LDX #>512
         JSR SHR10
         LDA #'M
         STA SUNIT
SBS1     JSR SBNUM
         LDA SUNIT
         BEQ SBS2
         JSR SBCH
SBS2     RTS
;
; GE1000 - NUM 1000 or more?
; Exit: C=1 yes
;
GE1000   LDA NUM+2
         ORA NUM+3
         BNE GE1
         LDA NUM
         CMP #<1000
         LDA NUM+1
         SBC #>1000
         RTS
GE1      SEC
         RTS
;
; SHR10 - NUM = (NUM + X/A) / 1024
; A=low, X=high
;
SHR10    JSR ADDNUM
         LDX #0             ; down a byte
SHR1     LDA NUM+1,X
         STA NUM,X
         INX
         CPX #3
         BNE SHR1
         LDA #0
         STA NUM+3
         JSR LSR32          ; and two bits
LSR32    LSR NUM+3
         ROR NUM+2
         ROR NUM+1
         ROR NUM
         RTS
;
; ADDNUM - NUM = NUM + X/A
; A=low, X=high
;
ADDNUM   CLC
         ADC NUM
         STA NUM
         TXA
         ADC NUM+1
         STA NUM+1
         BCC ADDN1
         INC NUM+2
         BNE ADDN1
         INC NUM+3
ADDN1    RTS
;
; ADDTO - 4 bytes at A/Y += NUM
;
ADDTO    STA PTR
         STY PTR+1
         LDY #0
         LDX #4
         CLC
ADDT1    LDA (PTR),Y
         ADC NUM,Y
         STA (PTR),Y
         INY
         DEX
         BNE ADDT1
         RTS
;
; GETL - NUM = 4 bytes at A/Y
; PUTL - 4 bytes at A/Y = NUM
;
GETL     STA PTR
         STY PTR+1
         LDY #3
GETL1    LDA (PTR),Y
         STA NUM,Y
         DEY
         BPL GETL1
         RTS
PUTL     STA PTR
         STY PTR+1
         LDY #3
PUTL1    LDA NUM,Y
         STA (PTR),Y
         DEY
         BPL PUTL1
         RTS
;
; NUM2L - NUM2 = 4 bytes at A/Y
;
NUM2L    STA PTR
         STY PTR+1
         LDY #3
NUM2L1   LDA (PTR),Y
         STA NUM2,Y
         DEY
         BPL NUM2L1
         RTS
;
; DIV32 - NUM = NUM / NUM2
; Exit: REM=remainder
;
DIV32    LDX #3
         LDA #0
DIV1     STA REM,X
         DEX
         BPL DIV1
         LDA #32            ; bits
         STA TMP4
DIV2     LDX #0             ; NUM,REM left 1
         LDY #8
         CLC
DIV3     ROL NUM,X
         INX
         DEY
         BNE DIV3
         LDX #0             ; DVT = REM - NUM2
         LDY #4
         SEC
DIV4     LDA REM,X
         SBC NUM2,X
         STA DVT,X
         INX
         DEY
         BNE DIV4
         BCC DIV6           ; doesn't go
         LDX #3
DIV5     LDA DVT,X
         STA REM,X
         DEX
         BPL DIV5
         INC NUM            ; quotient bit
DIV6     DEC TMP4
         BNE DIV2
         RTS
;
; MUL8 - NUM = NUM * A
; NUM2 is lost
;
MUL8     STA TMP4
         LDX #3
MUL1     LDA NUM,X          ; NUM2 = NUM, NUM 0
         STA NUM2,X
         LDA #0
         STA NUM,X
         DEX
         BPL MUL1
MUL2     LSR TMP4
         BCC MUL4
         LDX #0             ; bit set: add
         LDY #4
         CLC
MUL3     LDA NUM,X
         ADC NUM2,X
         STA NUM,X
         INX
         DEY
         BNE MUL3
MUL4     ASL NUM2           ; NUM2 * 2
         ROL NUM2+1
         ROL NUM2+2
         ROL NUM2+3
         LDA TMP4
         BNE MUL2
         RTS
;
; ATOL - digits at PTR into NUM
; Exit: PTR past them
;
ATOL     LDX #3
         LDA #0
ATOL1    STA NUM,X
         DEX
         BPL ATOL1
ATOL2    LDY #0
         LDA (PTR),Y
         JSR ISDIG
         BCC ATOL3
         AND #$0F
         PHA
         LDA #10            ; NUM*10 + digit
         JSR MUL8
         PLA
         LDX #0
         JSR ADDNUM
         JSR INCPTR
         JMP ATOL2
ATOL3    RTS
;
; ATOIP - number at A/Y
; Exit: NUM, A=its low byte
;
ATOIP    STA PTR
         STY PTR+1
         JSR ATOL
         LDA NUM
         RTS
;
; SKIPW - PTR on to the next word,
; past this one and its spaces
; Exit: C=1 no next word
;
SKIPW    LDY #0
         LDA (PTR),Y
         BEQ SKIPW2
         CMP #32
         BEQ SKIPW1
         JSR INCPTR
         JMP SKIPW
SKIPW1   JSR INCPTR         ; skip spaces
         LDA (PTR),Y
         CMP #32
         BEQ SKIPW1
         TAX
         BEQ SKIPW2
         CLC
         RTS
SKIPW2   SEC
         RTS
