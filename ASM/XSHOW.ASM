;
; EFTP_XL - sending files: showing it, and each file going
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; -- showing it
;
; XRATIO: the file's done * A / its size (255 at most)
;
XRATIO   PHA
         LDA FSIZEB
         ORA FSIZEB+1
         ORA FSIZEB+2
         ORA FSIZEB+3
         BNE XRATIO1
         PLA
         LDA #0
         RTS
XRATIO1  LDA #<FDONEB
         LDY #>FDONEB
         JSR GETL
         PLA
         JSR MUL8
         LDA #<FSIZEB
         LDY #>FSIZEB
         JSR NUM2L
         JSR DIV32
         LDA NUM+1
         ORA NUM+2
         ORA NUM+3
         BEQ XRATIO2
         LDA #255
         RTS
XRATIO2  LDA NUM
         RTS
;
; DROW: the transfer A of the queue on its row
;
DROW     STA DRI
         SEC
         SBC XFIRST
         CLC
         ADC #XROW+1
         TAX
         JSR CLRROW
         LDY #SCRL
         JSR AT
         LDA #CHUP
         LDX XDOWN
         BEQ DROW1
         LDA #CHDOWN
DROW1    JSR PUTCH
         INC SCOL
         LDA #12
         STA SW
         LDX DRI
         LDA XQST,X         ; how it went
         STA DRF
         LDA XQUEUE,X
         LDY XWALK          ; in a folder: the file going in it
         BEQ DROW1A
         CPX XCUR
         BNE DROW1A
         LDA K
DROW1A   STA DRJ
         TAX
         JSR SHOWN
         JSR PUTW
         INC SCOL
         JSR SIZESTART
         LDA DRI
         CMP XCUR
         BNE DROW3
         LDA DRF
         AND #EDONE+EFAIL+ESKIP
         BNE DROW3
         LDA #16            ; the bar
         JSR XRATIO
         CMP #17
         BCC DROW2
         LDA #16
DROW2    STA DRFILL
         STA SW
         JSR INVON
         JSR SPACES
         JSR INVOFF
         LDA #16
         SEC
         SBC DRFILL
         STA SW
         LDA #CHSHADE
         JSR REP
         LDA #100
         JSR XRATIO
         CMP #100
         BCC DROW2A
         LDA #99
DROW2A   JSR SBBYTE
         LDA #'%
         JSR SBCH
         JMP DROW8
DROW3    LDA DRF
         LDX #0
         AND #EDONE
         BNE DROW7
         LDX #5
         LDA DRF
         AND #ESKIP
         BNE DROW7
         LDX #13
         LDA DRF
         AND #EFAIL
         BEQ DROW7
         LDX #21
         LDA XSTOP
         BEQ DROW7
         LDA DRI
         CMP XCUR
         BNE DROW7
         LDX #28
DROW7    TXA
         CLC
         ADC #<STATES
         LDY #>STATES
         BCC DROW7A
         INY
DROW7A   JSR PUTS
         LDX DRJ
         LDA EFLAG,X        ; a folder has no size
         AND #EDIR
         BNE DROW8
         JSR ESIZE
         JSR SBSIZE
DROW8    LDA #<SIZEB
         LDY #>SIZEB
         JSR STRLEN
         EOR #$FF
         SEC
         ADC #SCRR+1
         STA SCOL
         LDA #<SIZEB
         LDY #>SIZEB
         JMP PUTS
STATES   .BYTE "Done",0,"Skipped",0,"Waiting",0,"Failed",0,"Stopped",0
;
; DQUEUE: the queue, the file going and those around it
;
DQUEUE   LDA XCUR
         BEQ DQUEUE1
         SEC
         SBC #1
DQUEUE1  STA XFIRST
         LDA XCOUNT
         CMP #XROWS+1
         BCS DQUEUE2
         LDA #0
         STA XFIRST
         BEQ DQUEUE3
DQUEUE2  SBC #XROWS
         CMP XFIRST
         BCS DQUEUE3
         STA XFIRST
DQUEUE3  LDA XFIRST
         STA DQR
DQUEUE4  LDA DQR
         CMP XCOUNT
         BCS DQUEUE5
         JSR DROW
         JMP DQUEUE6
DQUEUE5  SEC
         SBC XFIRST
         CLC
         ADC #XROW+1
         TAX
         JSR CLRROW
DQUEUE6  INC DQR
         LDA XFIRST
         CLC
         ADC #XROWS
         CMP DQR
         BNE DQUEUE4
         LDA #<XLINE        ; " 2 of 5 "
         LDY #>XLINE
         JSR SBSTART
         JSR SBSP
         LDA XCUR
         CLC
         ADC #1
         CMP XCOUNT
         BCC DQUEUE7
         LDA XCOUNT
DQUEUE7  JSR SBBYTE
         JSR SBI
         .BYTE " of ",0
         LDA XCOUNT
         JSR SBBYTE
         JSR SBSP
         LDX #XROW
         LDY #SCRR-10
         JSR AT
         LDA #11
         STA SW
         LDA #CHHLINE
         JSR REP
         LDA #<XLINE
         LDY #>XLINE
         JSR STRLEN
         EOR #$FF
         SEC
         ADC #SCRR+1
         STA SCOL
         LDA #<XLINE
         LDY #>XLINE
         JMP PUTS
;
; XPROG: the file going, on the info line and in the queue
;
XPROG    LDA #<XLINE
         LDY #>XLINE
         JSR SBSTART
         LDA #CHUP
         LDX XDOWN
         BEQ XPROG1
         LDA #CHDOWN
XPROG1   JSR SBCH
         JSR SBSP
         LDX K
         JSR SHOWN
         JSR SBADD
         JSR SBSP
         LDA #<FDONEB
         LDY #>FDONEB
         JSR GETL
         JSR SBSIZE
         LDA #'/
         JSR SBCH
         LDA #<FSIZEB
         LDY #>FSIZEB
         JSR GETL
         JSR SBSIZE
         JSR SBSP
         JSR SBRATE
         LDA #<XLINE
         LDY #>XLINE
         JSR INFO
         LDA XCUR
         JMP DROW
;
; XMOVED: XN bytes of a block went: count them, show them; Z clear
; when ESC was pressed
;
XMOVED   LDA XN
         STA NUM
         LDA XN+1
         STA NUM+1
         LDA #0
         STA NUM+2
         STA NUM+3
         LDA #<FDONEB
         LDY #>FDONEB
         JSR ADDTO
         LDA #<TDONE
         LDY #>TDONE
         JSR ADDTO
         JSR XPROG
         JSR KEYHIT
         BEQ XMOVED1
         JSR KEYGET
         CMP #KESC
         BNE XMOVED1
         LDA #1
         STA XSTOP
XMOVED1  LDA XSTOP
         RTS
;
; XERRI: XERROR = "what: why", what after the JSR, why from FERR
;
XERRI    JSR INLINE
         PHA
         TYA
         PHA
         LDA #<XERROR
         LDY #>XERROR
         JSR SBSTART
         PLA
         TAY
         PLA
         JSR SBADD
         JSR SBI
         .BYTE ": ",0
         LDA FERR
         CMP #ETIME
         BNE XERR1
         JSR SBI
         .BYTE "no answer",0
         JMP XERR3
XERR1    CMP #ECLOSED
         BNE XERR2
         JSR SBI
         .BYTE "connection lost",0
         JMP XERR3
XERR2    LDA #0
         STA FTPMSG+27
         LDA #<FTPMSG
         LDY #>FTPMSG
         JSR SBADD
XERR3    LDA #<XERROR
         LDY #>XERROR
         JMP INFO
;
; SAYCIO: XERROR = "NAME.EXT: error 144", the CIO status in XST
;
SAYCIO   LDA #<XERROR
         LDY #>XERROR
         JSR SBSTART
         LDA #<FSPEC
         LDY #>FSPEC
         JSR STRLEN         ; the name: after the last '>' or ':'
SAYCIO4  DEY
         BMI SAYCIO5
         LDA FSPEC,Y
         CMP #'>
         BEQ SAYCIO5
         CMP #':
         BNE SAYCIO4
SAYCIO5  INY
         TYA
         CLC
         ADC #<FSPEC
         TAX
         LDA #>FSPEC
         ADC #0
         TAY
         TXA
         JSR SBADD
         JSR SBI
         .BYTE ": error ",0
         LDA XST
         JSR SBBYTE
         JMP XERR3
;
; MAYREP: is A/Y in pane X? Then ask; the carry set: leave it (ESC
; stops too)
;
MAYREP   STA MRN
         STY MRN+1
         TXA
         JSR PUSE
         LDA MRN
         LDY MRN+1
         JSR PFIND
         BCC MAYREP1
         CLC
         RTS
MAYREP1  JSR MSGSTART
         LDA MRN
         LDY MRN+1
         JSR SBADD
         JSR SBI
         .BYTE " is there. Replace? Y/N",0
         JSR INFOMSG
         JSR KEYGET
         CMP #KESC
         BNE MAYREP2
         LDA #1
         STA XSTOP
MAYREP2  AND #$DF
         CMP #'Y
         BEQ MAYREP3
         SEC
         RTS
MAYREP3  CLC
         RTS
;
; -- one file each way; they return EDONE, EFAIL or ESKIP in A
;
GETF     LDX K
         JSR ANAMEX
         LDA #<ANAME
         LDY #>ANAME
         LDX #LOCAL
         JSR MAYREP
         BCC GETF1
         LDA #ESKIP
         RTS
GETF1    LDA #<ANAME
         LDY #>ANAME
         JSR LSPECN
         LDX K
         JSR ENAME
         JSR FRETR
         BCC GETF2
         STA FERR
         JSR XERRI
         .BYTE "Download",0
         LDA #EFAIL
         RTS
GETF2    LDA #<FSPEC
         LDY #>FSPEC
         LDX #8
         JSR COPEN
         BCC GETF3
         STA XST
         JSR CCLOSE
         JSR FABORT
         JSR SAYCIO
         LDA #EFAIL
         RTS
GETF3    JSR FREAD
         BCS GETF6
         LDA NLEN
         ORA NLEN+1
         BEQ GETF5
         LDA NLEN
         STA XLEN
         STA XN
         LDA NLEN+1
         STA XLEN+1
         STA XN+1
         LDA XTEXT
         BEQ GETF4
         JSR TOATARI
GETF4    LDA XLEN
         ORA XLEN+1
         BEQ GETF4A
         LDA #<BUF
         LDY #>BUF
         JSR CWRITE
         BCS GETF7
GETF4A   JSR XMOVED
         BEQ GETF3
         JSR CCLOSE         ; stopped
         JSR FABORT
         JMP GETF9
GETF5    JSR CCLOSE         ; all of it came
         BCS GETF7A
         JSR FDONE
         BCS GETF8
         LDA #EDONE
         RTS
GETF6    STA FERR           ; the connection failed
         JSR CCLOSE
         JSR FABORT
GETF8    JSR XERRI
         .BYTE "Download",0
         JMP GETF9
GETF7    STA XST            ; the disk failed
         JSR CCLOSE
         JMP GETF7B
GETF7A   STA XST
GETF7B   JSR FABORT
         JSR SAYCIO
GETF9    LDA #<FSPEC        ; no half files on the disk
         LDY #>FSPEC
         LDX #33
         JSR CXIO
         LDA #EFAIL
         RTS
;
PUTF     LDX K
         JSR ENAME
         LDX #REMOTE
         JSR MAYREP
         BCC PUTF1
         LDA #ESKIP
         RTS
PUTF1    LDX K
         JSR ENAME
         JSR LSPECN
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #4
         JSR COPEN
         BCC PUTF2
         STA XST
         JSR CCLOSE
         JSR SAYCIO
         LDA #EFAIL
         RTS
PUTF2    LDX K
         JSR ENAME
         JSR FSTOR
         BCC PUTF3
         STA FERR
         JSR CCLOSE
         JSR XERRI
         .BYTE "Upload",0
         LDA #EFAIL
         RTS
PUTF3    LDA #0
         STA FERR
PUTF4    LDA XTEXT
         BEQ PUTF5
         LDA #<[BUF+256]
         LDY #>[BUF+256]
         LDX #1
         BNE PUTF6
PUTF5    LDA #<BUF
         LDY #>BUF
         LDX #2
PUTF6    JSR CREAD
         STA XST
         LDA CGOT
         ORA CGOT+1
         BEQ PUTF8
         LDA CGOT
         STA XLEN
         STA XN
         LDA CGOT+1
         STA XLEN+1
         STA XN+1
         LDA XTEXT
         BEQ PUTF7
         JSR TOSERV
PUTF7    JSR FWRITE
         BCS PUTF10
         JSR XMOVED
         BNE PUTF9
PUTF8    LDA XST
         CMP #128
         BCC PUTF4
PUTF9    JSR CCLOSE
         LDA XST
         CMP #136
         BNE PUTF11
         LDA FERR
         BNE PUTF11
         LDA XSTOP
         BNE PUTF11
         JSR FDONE
         BCC PUTF13
         STA FERR
         JSR XERRI
         .BYTE "Upload",0
         LDA #EFAIL
         RTS
PUTF10   STA FERR
         JMP PUTF9
PUTF11   JSR FABORT
         LDA FERR
         BEQ PUTF12
         JSR XERRI
         .BYTE "Upload",0
         LDA #EFAIL
         RTS
PUTF12   LDA XST
         CMP #128
         BCC PUTF12A
         CMP #136
         BEQ PUTF12A
         JSR SAYCIO
PUTF12A  LDA #EFAIL
         RTS
PUTF13   LDA #EDONE
         RTS
;
; XDRAW: the transfers area, what the last transfer did
;
XDRAW    LDX #XROW+1
         LDY #SCRL
         JSR AT
         LDA SUMMARY
         BEQ XDRAW1
         LDA #<SUMMARY
         LDY #>SUMMARY
         JMP PUTS
XDRAW1   JSR PUTSI
         .BYTE "Nothing yet. RETURN sends a file,",0
         LDX #XROW+2
         LDY #SCRL
         JSR AT
         JSR PUTSI
         .BYTE "SPACE marks several, ^T sends them.",0
         RTS
