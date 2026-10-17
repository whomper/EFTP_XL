;
; XFER.M65 - EFTP_XL 1.0
; Sending files, one after another
; Copyright (C) 2026 AERA | Erez Yaary
;
;
; XSEND - send the marked entries of
; the active pane to the other side,
; folders with all in them (XTREE)
; XONLY not 0: only the cursor's one
; Exit: C=1 if anything was sent
;       (read the panes again)
;
XSEND    LDA ACTIVE
         STA XDOWN          ; 1: server to Atari
         LDX SITE
         JSR SSEL
         LDY #SMODE         ; the site's Files
         LDA (SITEP),Y
         STA XMODE
         LDA ACTIVE
         JSR PUSE
         LDA #0
         STA XCOUNT
         STA XCUR
         STA XSTOP
         STA XOK
         STA XNF
         STA XWALK
         STA XERROR
         LDX #MAXE-1        ; no states yet
XSEND0   STA XQST,X
         DEX
         BPL XSEND0
         JSR PEND           ; TMP4 = pane end
         LDA XONLY
         BNE XSEND2
         LDX BASE           ; queue the marked
XSEND1   CPX TMP4
         BCS XSEND2
         LDA EFLAG,X
         AND #EMARK
         BEQ XSEND1A
         TXA
         LDY XCOUNT
         STA XQUEUE,Y
         INC XCOUNT
XSEND1A  INX
         BNE XSEND1
XSEND2   LDA XCOUNT
         BNE XSEND3
         JSR CURENT         ; none: the cursor's
         BEQ XSEND2A        ; empty pane
         LDA EFLAG,X
         AND #EUP           ; not ".."
         BNE XSEND2A
         STX XQUEUE
         INC XCOUNT
         BNE XSEND3
XSEND2A  JSR INFOI
         .BYTE "Mark files with SPACE, or put the cursor on one.",0
         CLC
         RTS
XSEND3   LDX #3             ; total done = 0
         LDA #0
XSEND3A  STA TDONE,X
         DEX
         BPL XSEND3A
         JSR TICKS
         LDA #<XT0          ; XT0 = start time
         LDY #>XT0
         JSR PUTL
XSEND4   LDA XCUR           ; each in the queue
         CMP XCOUNT
         BCS XSEND6         ; all done
         LDA XSTOP
         BNE XSEND6         ; ESC
         LDX XCUR
         LDA XQUEUE,X
         STA K
         TAX
         JSR DQUEUE
         LDX K
         LDA EFLAG,X
         AND #EDIR
         BEQ XSEND4A
         JSR XTREE          ; a folder
         JMP XSEND5
XSEND4A  JSR XFILE
XSEND5   LDX XCUR
         STA XQST,X         ; how it went
         JSR DQUEUE
         INC XCUR
         JMP XSEND4
;
; XFILE - send file K to the other
; side, counting it in XNF and XOK
; Exit: A=EDONE, EFAIL or ESKIP
;
XFILE    LDX K
         JSR ESIZE
         LDA #<FSIZEB       ; FSIZEB = its size
         LDY #>FSIZEB
         JSR PUTL
         LDX #3             ; none done yet
         LDA #0
XFILE1   STA FDONEB,X
         DEX
         BPL XFILE1
         JSR ISTEXT
         JSR XPROG
         INC XNF            ; files tried
         LDA XDOWN
         BEQ XFILE2
         JSR GETF           ; server to Atari
         JMP XFILE3
XFILE2   JSR PUTF           ; Atari to server
XFILE3   CMP #EDONE
         BNE XFILE4
         INC XOK            ; files sent
XFILE4   RTS
;
; All gone: SUMMARY = "2 of 3 files,
; 260K in 0:42 (6K/s)"
;
XSEND6   JSR ELAPSED
         JSR HZ
         JSR DIVA           ; seconds
         LDA #60
         JSR DIVA           ; minutes, REM secs
         LDA REM
         STA XSECS
         LDA NUM
         STA XMINS
         LDA NUM+1
         STA XMINS+1
         LDA #<SUMMARY
         LDY #>SUMMARY
         JSR SBSTART
         LDA XOK
         CMP XNF
         BEQ XSEND7         ; all sent: no "of"
         JSR SBBYTE
         JSR SBI
         .BYTE " of ",0
XSEND7   LDA XNF
         PHA
         JSR SBBYTE
         JSR SBI
         .BYTE " file",0
         PLA
         JSR SBPLURAL
         JSR SBI
         .BYTE ", ",0
         LDA #<TDONE
         LDY #>TDONE
         JSR GETL
         JSR SBSIZE
         JSR SBI
         .BYTE " in ",0
         LDA XMINS
         STA NUM
         LDA XMINS+1
         STA NUM+1
         JSR SBNUM
         LDA #':
         JSR SBCH
         LDA XSECS
         JSR SB2
         JSR SBI
         .BYTE " (",0
         JSR SBRATE
         LDA #')
         JSR SBCH
         LDA XSTOP
         BEQ XSEND8
         JSR INFOI
         .BYTE "Stopped.",0
         SEC
         RTS
XSEND8   LDA #<XERROR       ; why one failed,
         LDY #>XERROR       ; if any, over
         LDX XERROR         ; the sums
         BNE XSEND9
         LDA #<SUMMARY
         LDY #>SUMMARY
XSEND9   JSR INFO
         SEC
         RTS
;
; DIVA - NUM = NUM / A
; Exit: REM = what is left
;
DIVA     STA NUM2
         LDA #0
         STA NUM2+1
         STA NUM2+2
         STA NUM2+3
         JMP DIV32
;
; HZ - clock ticks a second
; Exit: A=50 (PAL) or 60 (NTSC)
;
HZ       LDA PAL
         AND #$0E           ; 0 on PAL
         BEQ HZ1
         LDA #60
         RTS
HZ1      LDA #50
         RTS
;
; TICKS - NUM = the clock, RTCLOK
;
TICKS    LDA RTCLOK+2       ; low byte last
         STA NUM
         LDA RTCLOK+1
         STA NUM+1
         LDA RTCLOK
         STA NUM+2
         LDA #0
         STA NUM+3
         RTS
;
; ELAPSED - NUM = ticks since XT0,
; at least 1
;
ELAPSED  JSR TICKS
         LDX #0
         LDY #4
         SEC
ELAP1    LDA NUM,X
         SBC XT0,X
         STA NUM,X
         INX
         DEY
         BNE ELAP1
         LDA NUM
         ORA NUM+1
         ORA NUM+2
         ORA NUM+3
         BNE ELAP2
         INC NUM            ; never divide by 0
ELAP2    RTS
;
; SBRATE - add the speed, "3K/s"
;
SBRATE   JSR ELAPSED
         LDA #<XT           ; XT = ticks
         LDY #>XT
         JSR PUTL
         LDA #<TDONE
         LDY #>TDONE
         JSR GETL
         JSR HZ
         JSR MUL8           ; bytes * ticks/s
         LDA #<XT
         LDY #>XT
         JSR NUM2L
         JSR DIV32          ; / ticks = bytes/s
         JSR GE1000
         PHP
         JSR SBSIZE
         PLP
         BCS SBRATE1        ; it has K or M
         LDA #'B            ; "512B/s"
         JSR SBCH
SBRATE1  JSR SBI
         .BYTE "/s",0
         RTS
;
; ISTEXT - XTEXT = 1 if file K is
; text: the site's Files is Text, or
; By type and it has a type below
;
ISTEXT   LDA XMODE
         CMP #MODETYPE
         BEQ ISTEXT2        ; by type
         CMP #MODETEXT
         BEQ ISTEXT1
ISTEXT0  LDA #0             ; binary
         .BYTE $2C          ; BIT: skips LDA #1
ISTEXT1  LDA #1
         STA XTEXT
         RTS
ISTEXT2  LDX K
         JSR LASTDOT
         BCS ISTEXT0        ; no extension
         LDX #0             ; EXTB = " EXT "
         LDA #32            ; in capitals,
         STA EXTB           ; 1 to 4 letters
ISTEXT3  INY
         LDA (PTR),Y
         BEQ ISTEXT4
         INX
         CPX #5
         BCS ISTEXT0        ; too long
         JSR UPPER
         STA EXTB,X
         BNE ISTEXT3
ISTEXT4  TXA
         BEQ ISTEXT0        ; empty
         LDA #32
         STA EXTB+1,X
         LDA #0
         STA EXTB+2,X
         LDA #<TTYPES
         STA PTR3
         LDA #>TTYPES
         STA PTR3+1
         LDA #<EXTB
         LDY #>EXTB
         JSR STRSTR         ; in TTYPES?
         BCS ISTEXT0
         BCC ISTEXT1
;
; EFTP's text types, and BASIC
; listings
;
TTYPES   .BYTE " TXT ASC DOC ME NFO DIZ HTM HTML INF LST ",0
;
; LASTDOT - find the last "." in the
; name of entry X (LASTDS: of A/Y)
; Exit: PTR=name; C=0 and Y=the dot,
;       or C=1 if none
;
LASTDOT  JSR ENAME
LASTDS   STA PTR
         STY PTR+1
         LDA #$FF           ; none yet
         STA ADOT
         LDY #0
LASTD1   LDA (PTR),Y
         BEQ LASTD2
         CMP #'.
         BNE LASTD1A
         STY ADOT
LASTD1A  INY
         BNE LASTD1
LASTD2   LDY ADOT
         CPY #$FF
         BEQ LASTD3
         CLC
         RTS
LASTD3   SEC
         RTS
;
; ANAMEX - ANAME = a DOS 8.3 name for
; entry X (ANAMES: for name A/Y):
; letters and digits in capitals, a
; letter first, as
; "STinG 1.26.zip" -> STING126.ZIP
;
ANAMEX   JSR ENAME
ANAMES   JSR LASTDS
         LDX #0
         LDY #0
         LDA (PTR),Y
         JSR ISALPH
         BCS ANAME1         ; a letter first,
         LDA #'F            ; else F
         STA ANAME
         INX
ANAME1   LDA (PTR),Y        ; the name
         BEQ ANAME3
         CPY ADOT
         BEQ ANAME3         ; up to the dot
         CPX #8
         BCS ANAME3         ; 8 at most
         JSR ISALNUM
         BCC ANAME2         ; drop the rest
         JSR UPPER
         STA ANAME,X
         INX
ANAME2   INY
         BNE ANAME1
ANAME3   LDY ADOT
         CPY #$FF
         BEQ ANAME6         ; no extension
         LDA #'.
         STA ANAME,X
         INX
         STX TMP            ; TMP: where in ANAME
         LDA #0
         STA TMP2           ; TMP2: its length
ANAME4   INY
         LDA (PTR),Y
         BEQ ANAME5
         JSR ISALNUM
         BCC ANAME4
         JSR UPPER
         LDX TMP
         STA ANAME,X
         INC TMP
         INC TMP2
         LDA TMP2
         CMP #3             ; 3 at most
         BNE ANAME4
ANAME5   LDX TMP
         LDA TMP2
         BNE ANAME6
         DEX                ; none: drop the dot
ANAME6   LDA #0
         STA ANAME,X
         RTS
;
; SHOWN - entry X's name as shown:
; its 8.3 name going to the Atari
; Exit: A/Y=name
;
SHOWN    LDA XDOWN
         BNE SHOWN1
         JMP ENAME          ; going up: as is
SHOWN1   JSR ANAMEX
         LDA #<ANAME
         LDY #>ANAME
         RTS
;
; Text files: CR LF on the server,
; EOL on the Atari; TAB is $7F there
;
; TOATARI - the NLEN bytes in BUF to
; Atari text, in place
; Exit: XLEN = bytes now
;
TOATARI  LDA #<BUF          ; in and out at BUF
         STA PTR
         STA PTR2
         LDA #>BUF
         STA PTR+1
         STA PTR2+1
         LDA NLEN
         STA XCNT
         LDA NLEN+1
         STA XCNT+1
TOAT1    JSR XNEXT
         BCS XOUT           ; all done
         CMP #13
         BEQ TOAT1          ; drop CR
         CMP #10
         BNE TOAT2
         LDA #EOL           ; LF -> EOL
TOAT2    CMP #9
         BNE TOAT3
         LDA #$7F           ; TAB
TOAT3    JSR XPUT
         JMP TOAT1
;
; TOSERV - the CGOT bytes at BUF+256
; to CR LF text at BUF (up to twice
; as long)
; Exit: XLEN = bytes
;
TOSERV   LDA #<[BUF+256]
         STA PTR
         LDA #>[BUF+256]
         STA PTR+1
         LDA #<BUF
         STA PTR2
         LDA #>BUF
         STA PTR2+1
         LDA CGOT
         STA XCNT
         LDA CGOT+1
         STA XCNT+1
TOSV1    JSR XNEXT
         BCS XOUT           ; all done
         CMP #EOL
         BNE TOSV2
         LDA #13            ; EOL -> CR LF
         JSR XPUT
         LDA #10
TOSV2    CMP #$7F
         BNE TOSV3
         LDA #9             ; TAB
TOSV3    JSR XPUT
         JMP TOSV1
;
; XNEXT - next byte at PTR, XCNT of
; them
; Exit: C=1 when none left
;
XNEXT    LDA XCNT
         ORA XCNT+1
         BEQ XNEXT2         ; none left
         LDA XCNT           ; XCNT - 1
         BNE XNEXT1
         DEC XCNT+1
XNEXT1   DEC XCNT
         LDY #0
         LDA (PTR),Y
         JSR INCPTR
         CLC
         RTS
XNEXT2   SEC
         RTS
;
; XPUT - A to PTR2, and on
;
XPUT     LDY #0
         STA (PTR2),Y
         INC PTR2
         BNE XPUT1
         INC PTR2+1
XPUT1    RTS
;
; XOUT - XLEN = PTR2 - BUF
;
XOUT     LDA PTR2
         SEC
         SBC #<BUF
         STA XLEN
         LDA PTR2+1
         SBC #>BUF
         STA XLEN+1
         RTS
