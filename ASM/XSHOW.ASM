;
; XSHOW.M65 - EFTP_XL 0.9
; Transfers area, progress, each file
; Copyright (C) 2026 AERA | Erez Yaary
;
;
; XRATIO - the file's done * A / its
; size
; Exit: A, 255 at most (0 if size 0)
;
XRATIO   PHA
         LDA FSIZEB
         ORA FSIZEB+1
         ORA FSIZEB+2
         ORA FSIZEB+3
         BNE XRATIO1
         PLA                ; size 0
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
         LDA #255           ; over a byte
         RTS
XRATIO2  LDA NUM
         RTS
;
; DROW - queue entry A on its row:
; arrow, name, then a bar and % for
; the one going, else how it went
; and its size
;
DROW     STA DRI
         SEC
         SBC XFIRST         ; its screen row
         CLC
         ADC #XROW+1
         TAX
         JSR CLRROW
         LDY #SCRL
         JSR AT
         LDA #CHUP          ; arrow: which way
         LDX XDOWN
         BEQ DROW1
         LDA #CHDOWN
DROW1    JSR PUTCH
         INC SCOL
         LDA #12            ; name: 12 columns
         STA SW
         LDX DRI
         LDA XQST,X         ; how it went
         STA DRF
         LDA XQUEUE,X
         LDY XWALK          ; in a folder walk
         BEQ DROW1A
         CPX XCUR           ; the one going
         BNE DROW1A
         LDA K              ; shows file K
DROW1A   STA DRJ            ; DRJ = entry
         TAX
         JSR SHOWN
         JSR PUTW
         INC SCOL
         JSR SIZESTART      ; build in SIZEB
         LDA DRI
         CMP XCUR
         BNE DROW3          ; not the one going
         LDA DRF
         AND #EDONE+EFAIL+ESKIP
         BNE DROW3          ; or it has ended
         LDA #16            ; the bar, 16 wide
         JSR XRATIO
         CMP #17
         BCC DROW2
         LDA #16
DROW2    STA DRFILL
         STA SW
         JSR INVON          ; done: inverse
         JSR SPACES
         JSR INVOFF
         LDA #16
         SEC
         SBC DRFILL
         STA SW
         LDA #CHSHADE       ; to go: shaded
         JSR REP
         LDA #100
         JSR XRATIO
         CMP #100
         BCC DROW2A
         LDA #99            ; not 100% yet
DROW2A   JSR SBBYTE
         LDA #'%
         JSR SBCH
         JMP DROW8
DROW3    LDA DRF            ; X = in STATES
         LDX #0
         AND #EDONE
         BNE DROW7          ; Done
         LDX #5
         LDA DRF
         AND #ESKIP
         BNE DROW7          ; Skipped
         LDX #13
         LDA DRF
         AND #EFAIL
         BEQ DROW7          ; Waiting
         LDX #21
         LDA XSTOP
         BEQ DROW7          ; Failed
         LDA DRI
         CMP XCUR
         BNE DROW7
         LDX #28            ; Stopped by ESC
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
DROW8    LDA #<SIZEB        ; SIZEB at the right
         LDY #>SIZEB
         JSR STRLEN
         EOR #$FF
         SEC
         ADC #SCRR+1        ; SCRR+1 - length
         STA SCOL
         LDA #<SIZEB
         LDY #>SIZEB
         JMP PUTS
STATES   .BYTE "Done",0,"Skipped",0,"Waiting",0,"Failed",0,"Stopped",0
;
; DQUEUE - draw the queue: XROWS rows
; from the one before the one going,
; and " 2 of 5 " on the line above
;
DQUEUE   LDA XCUR
         BEQ DQUEUE1
         SEC
         SBC #1             ; one done above it
DQUEUE1  STA XFIRST
         LDA XCOUNT
         CMP #XROWS+1
         BCS DQUEUE2
         LDA #0             ; all fit: from 0
         STA XFIRST
         BEQ DQUEUE3
DQUEUE2  SBC #XROWS         ; else keep the
         CMP XFIRST         ; rows full
         BCS DQUEUE3
         STA XFIRST
DQUEUE3  LDA XFIRST
         STA DQR
DQUEUE4  LDA DQR            ; each row
         CMP XCOUNT
         BCS DQUEUE5        ; past the end
         JSR DROW
         JMP DQUEUE6
DQUEUE5  SEC                ; blank row
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
         ADC #1             ; from 1, up to
         CMP XCOUNT         ; XCOUNT
         BCC DQUEUE7
         LDA XCOUNT
DQUEUE7  JSR SBBYTE
         JSR SBI
         .BYTE " of ",0
         LDA XCOUNT
         JSR SBBYTE
         JSR SBSP
         LDX #XROW          ; the line above:
         LDY #SCRR-10       ; clear its end
         JSR AT
         LDA #11
         STA SW
         LDA #CHHLINE
         JSR REP
         LDA #<XLINE        ; then XLINE at
         LDY #>XLINE        ; the right
         JSR STRLEN
         EOR #$FF
         SEC
         ADC #SCRR+1
         STA SCOL
         LDA #<XLINE
         LDY #>XLINE
         JMP PUTS
;
; XPROG - show the file going: arrow,
; name, done/size and speed on the
; info line, and its queue row
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
; XMOVED - XN bytes of a block went:
; count them, show them, look for ESC
; Exit: A=XSTOP, Z=0 to stop
;
XMOVED   LDA XN             ; NUM = XN
         STA NUM
         LDA XN+1
         STA NUM+1
         LDA #0
         STA NUM+2
         STA NUM+3
         LDA #<FDONEB       ; the file's done
         LDY #>FDONEB
         JSR ADDTO
         LDA #<TDONE        ; and the total
         LDY #>TDONE
         JSR ADDTO
         JSR XPROG
         JSR KEYHIT
         BEQ XMOVED1        ; no key
         JSR KEYGET
         CMP #KESC
         BNE XMOVED1
         LDA #1             ; ESC: stop
         STA XSTOP
XMOVED1  LDA XSTOP
         RTS
;
; XERRI - XERROR = "what: why" on the
; info line; what: the string after
; the JSR, why: from FERR
;
XERRI    JSR INLINE
         PHA                ; keep A/Y
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
XERR2    LDA #0             ; else the reply,
         STA FTPMSG+27      ; cut to fit
         LDA #<FTPMSG
         LDY #>FTPMSG
         JSR SBADD
XERR3    LDA #<XERROR
         LDY #>XERROR
         JMP INFO
;
; SAYCIO - XERROR = "NAME.EXT: error
; 144" on the info line: CIO status
; XST, name from FSPEC
;
SAYCIO   LDA #<XERROR
         LDY #>XERROR
         JSR SBSTART
         LDA #<FSPEC
         LDY #>FSPEC
         JSR STRLEN         ; after last > or :
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
         ADC #<FSPEC        ; A/Y = FSPEC+Y
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
; MAYREP - if A/Y is in pane X, ask to
; replace it (ESC also stops it all)
; Exit: C=1 leave it, C=0 go on
;
MAYREP   STA MRN
         STY MRN+1
         TXA
         JSR PUSE
         LDA MRN
         LDY MRN+1
         JSR PFIND
         BCC MAYREP1        ; there: ask
         CLC                ; not there: go on
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
         LDA #1             ; ESC: stop
         STA XSTOP
MAYREP2  AND #$DF           ; to capitals
         CMP #'Y
         BEQ MAYREP3
         SEC
         RTS
MAYREP3  CLC
         RTS
;
; One file each way
;
; GETF - file K, server to Atari
; Exit: A=EDONE, EFAIL or ESKIP
;
GETF     LDX K
         JSR ANAMEX         ; its 8.3 name
         LDA #<ANAME
         LDY #>ANAME
         LDX #LOCAL
         JSR MAYREP
         BCC GETF1
         LDA #ESKIP         ; leave it
         RTS
GETF1    LDA #<ANAME
         LDY #>ANAME
         JSR LSPECN         ; FSPEC = its path
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
         LDX #8             ; write
         JSR COPEN
         BCC GETF3
         STA XST            ; could not open
         JSR CCLOSE
         JSR FABORT
         JSR SAYCIO
         LDA #EFAIL
         RTS
GETF3    JSR FREAD          ; next block
         BCS GETF6
         LDA NLEN
         ORA NLEN+1
         BEQ GETF5          ; end of file
         LDA NLEN
         STA XLEN           ; XLEN to write,
         STA XN             ; XN to count
         LDA NLEN+1
         STA XLEN+1
         STA XN+1
         LDA XTEXT
         BEQ GETF4
         JSR TOATARI
GETF4    LDA XLEN
         ORA XLEN+1
         BEQ GETF4A         ; none to write
         LDA #<BUF
         LDY #>BUF
         JSR CWRITE
         BCS GETF7
GETF4A   JSR XMOVED
         BEQ GETF3          ; no ESC: more
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
GETF9    LDA #<FSPEC        ; no half files
         LDY #>FSPEC
         LDX #33            ; XIO 33: delete
         JSR CXIO
         LDA #EFAIL
         RTS
;
; PUTF - file K, Atari to server
; Exit: A=EDONE, EFAIL or ESKIP
;
PUTF     LDX K
         JSR ENAME
         LDX #REMOTE
         JSR MAYREP
         BCC PUTF1
         LDA #ESKIP         ; leave it
         RTS
PUTF1    LDX K
         JSR ENAME
         JSR LSPECN         ; FSPEC = its path
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #4             ; read
         JSR COPEN
         BCC PUTF2
         STA XST            ; could not open
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
PUTF3    LDA #0             ; no net error yet
         STA FERR
PUTF4    LDA XTEXT
         BEQ PUTF5
         LDA #<[BUF+256]    ; text: 1 page at
         LDY #>[BUF+256]    ; BUF+256, as CR LF
         LDX #1             ; can double it
         BNE PUTF6
PUTF5    LDA #<BUF          ; else 2 pages
         LDY #>BUF
         LDX #2
PUTF6    JSR CREAD
         STA XST            ; CIO status
         LDA CGOT
         ORA CGOT+1
         BEQ PUTF8          ; none came
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
         BCS PUTF10         ; net failed
         JSR XMOVED
         BNE PUTF9          ; ESC
PUTF8    LDA XST
         CMP #128
         BCC PUTF4          ; no error: more
PUTF9    JSR CCLOSE
         LDA XST
         CMP #136           ; end of file,
         BNE PUTF11
         LDA FERR           ; no net error
         BNE PUTF11
         LDA XSTOP          ; and no ESC:
         BNE PUTF11
         JSR FDONE          ; all of it went
         BCC PUTF13
         STA FERR
         JSR XERRI
         .BYTE "Upload",0
         LDA #EFAIL
         RTS
PUTF10   STA FERR
         JMP PUTF9
PUTF11   JSR FABORT         ; it failed
         LDA FERR
         BEQ PUTF12
         JSR XERRI
         .BYTE "Upload",0
         LDA #EFAIL
         RTS
PUTF12   LDA XST            ; a disk error?
         CMP #128
         BCC PUTF12A
         CMP #136
         BEQ PUTF12A        ; EOF is not one
         JSR SAYCIO
PUTF12A  LDA #EFAIL
         RTS
PUTF13   LDA #EDONE
         RTS
;
; XDRAW - the transfers area: what
; the last transfer did, or how to
; start one
;
XDRAW    LDX #XROW+1
         LDY #SCRL
         JSR AT
         LDA SUMMARY
         BEQ XDRAW1         ; none yet
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
