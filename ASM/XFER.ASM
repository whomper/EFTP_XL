;
; EFTP_XL - sending files
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; As in EFTP: the files go one after the other, the transfers area
; shows them (Done, Waiting, a bar for the one going), the info line
; what is happening, and ESC stops. A file going to the Atari gets an
; 8.3 name (STinG 1.26.zip -> STING126.ZIP); one already there is
; replaced only when you say so. Text files have their line ends
; changed (CR LF on the server, EOL on the Atari) when the site says
; Text, or By type and the name ends in one of EFTP's text types.
;
; XSEND: from the active pane to the other, the marked files and folders
; (a folder with all in it, XTREE); XONLY not 0: only the one under the
; cursor. The carry set when something was sent (the panes need reading
; again).
;
XSEND    LDA ACTIVE
         STA XDOWN
         LDX SITE
         JSR SSEL
         LDY #SMODE
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
         LDX #MAXE-1
XSEND0   STA XQST,X
         DEX
         BPL XSEND0
         JSR PEND
         LDA XONLY
         BNE XSEND2
         LDX BASE
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
         JSR CURENT         ; none marked: the one under the cursor
         BEQ XSEND2A
         LDA EFLAG,X
         AND #EUP
         BNE XSEND2A
         STX XQUEUE
         INC XCOUNT
         BNE XSEND3
XSEND2A  JSR INFOI
         .BYTE "Mark files with SPACE, or put the cursor on one.",0
         CLC
         RTS
XSEND3   LDX #3
         LDA #0
XSEND3A  STA TDONE,X
         DEX
         BPL XSEND3A
         JSR TICKS
         LDA #<XT0
         LDY #>XT0
         JSR PUTL
XSEND4   LDA XCUR
         CMP XCOUNT
         BCS XSEND6
         LDA XSTOP
         BNE XSEND6
         LDX XCUR
         LDA XQUEUE,X
         STA K
         TAX
         JSR DQUEUE
         LDX K
         LDA EFLAG,X
         AND #EDIR
         BEQ XSEND4A
         JSR XTREE
         JMP XSEND5
XSEND4A  JSR XFILE
XSEND5   LDX XCUR
         STA XQST,X
         JSR DQUEUE
         INC XCUR
         JMP XSEND4
;
; XFILE: file K to the other side; A: EDONE, EFAIL or ESKIP
;
XFILE    LDX K
         JSR ESIZE
         LDA #<FSIZEB
         LDY #>FSIZEB
         JSR PUTL
         LDX #3
         LDA #0
XFILE1   STA FDONEB,X
         DEX
         BPL XFILE1
         JSR ISTEXT
         JSR XPROG
         INC XNF
         LDA XDOWN
         BEQ XFILE2
         JSR GETF
         JMP XFILE3
XFILE2   JSR PUTF
XFILE3   CMP #EDONE
         BNE XFILE4
         INC XOK
XFILE4   RTS
;
; "2 of 3 files, 260K in 0:42 (6K/s)"
;
XSEND6   JSR ELAPSED
         JSR HZ
         JSR DIVA
         LDA #60
         JSR DIVA
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
         BEQ XSEND7
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
         LDA XSTOP          ; why one failed is worth more than the sums
         BEQ XSEND8
         JSR INFOI
         .BYTE "Stopped.",0
         SEC
         RTS
XSEND8   LDA #<XERROR
         LDY #>XERROR
         LDX XERROR
         BNE XSEND9
         LDA #<SUMMARY
         LDY #>SUMMARY
XSEND9   JSR INFO
         SEC
         RTS
;
; DIVA: NUM = NUM / A (REM what is left)
;
DIVA     STA NUM2
         LDA #0
         STA NUM2+1
         STA NUM2+2
         STA NUM2+3
         JMP DIV32
;
; HZ: the clock's ticks a second, 50 or 60, in A
;
HZ       LDA PAL
         AND #$0E
         BEQ HZ1
         LDA #60
         RTS
HZ1      LDA #50
         RTS
;
; TICKS: NUM = the clock; ELAPSED: the ticks since XT0 (at least 1)
;
TICKS    LDA RTCLOK+2
         STA NUM
         LDA RTCLOK+1
         STA NUM+1
         LDA RTCLOK
         STA NUM+2
         LDA #0
         STA NUM+3
         RTS
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
         INC NUM
ELAP2    RTS
;
; SBRATE: how fast it went, "3K/s"
;
SBRATE   JSR ELAPSED
         LDA #<XT
         LDY #>XT
         JSR PUTL
         LDA #<TDONE
         LDY #>TDONE
         JSR GETL
         JSR HZ
         JSR MUL8
         LDA #<XT
         LDY #>XT
         JSR NUM2L
         JSR DIV32
         JSR GE1000
         PHP
         JSR SBSIZE
         PLP
         BCS SBRATE1
         LDA #'B
         JSR SBCH
SBRATE1  JSR SBI
         .BYTE "/s",0
         RTS
;
; ISTEXT: XTEXT = is entry K a text file, for the site's Files
;
ISTEXT   LDA XMODE
         CMP #MODETYPE
         BEQ ISTEXT2
         CMP #MODETEXT
         BEQ ISTEXT1
ISTEXT0  LDA #0
         .BYTE $2C          ; BIT: skips the LDA #1
ISTEXT1  LDA #1
         STA XTEXT
         RTS
ISTEXT2  LDX K
         JSR LASTDOT
         BCS ISTEXT0
         LDX #0             ; " EXT " in capitals, 1 to 4 letters
         LDA #32
         STA EXTB
ISTEXT3  INY
         LDA (PTR),Y
         BEQ ISTEXT4
         INX
         CPX #5
         BCS ISTEXT0
         JSR UPPER
         STA EXTB,X
         BNE ISTEXT3
ISTEXT4  TXA
         BEQ ISTEXT0
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
         JSR STRSTR
         BCS ISTEXT0
         BCC ISTEXT1
;
; EFTP's text types, and BASIC listings
;
TTYPES   .BYTE " TXT ASC DOC ME NFO DIZ HTM HTML INF LST ",0
;
; LASTDOT: PTR = entry X's name (LASTDS: the name A/Y), Y where its
; last "." is (carry clear) or the carry set when it has none
;
LASTDOT  JSR ENAME
LASTDS   STA PTR
         STY PTR+1
         LDA #$FF
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
; ANAMEX: ANAME = a name DOS takes for entry X (ANAMES: for the name
; A/Y): up to 8 letters and digits, a letter first, and up to 3 for the
; extension, in capitals
;
ANAMEX   JSR ENAME
ANAMES   JSR LASTDS
         LDX #0
         LDY #0
         LDA (PTR),Y
         JSR ISALPH
         BCS ANAME1
         LDA #'F
         STA ANAME
         INX
ANAME1   LDA (PTR),Y
         BEQ ANAME3
         CPY ADOT
         BEQ ANAME3
         CPX #8
         BCS ANAME3
         JSR ISALNUM
         BCC ANAME2
         JSR UPPER
         STA ANAME,X
         INX
ANAME2   INY
         BNE ANAME1
ANAME3   LDY ADOT
         CPY #$FF
         BEQ ANAME6
         LDA #'.
         STA ANAME,X
         INX
         STX TMP
         LDA #0
         STA TMP2
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
         CMP #3
         BNE ANAME4
ANAME5   LDX TMP
         LDA TMP2
         BNE ANAME6
         DEX                ; no extension after all
ANAME6   LDA #0
         STA ANAME,X
         RTS
;
; SHOWN: the name entry X has on the screen, A/Y: its Atari name when
; going down
;
SHOWN    LDA XDOWN
         BNE SHOWN1
         JMP ENAME
SHOWN1   JSR ANAMEX
         LDA #<ANAME
         LDY #>ANAME
         RTS
;
; -- the line ends of text files
;
; TOATARI: the NLEN bytes in BUF, CR LF -> EOL, TAB -> Atari TAB; XLEN
; how many are left
;
TOATARI  LDA #<BUF
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
         BCS XOUT
         CMP #13
         BEQ TOAT1
         CMP #10
         BNE TOAT2
         LDA #EOL
TOAT2    CMP #9
         BNE TOAT3
         LDA #$7F
TOAT3    JSR XPUT
         JMP TOAT1
;
; TOSERV: the CGOT bytes at BUF+256 to CR LF text at BUF, XLEN bytes
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
         BCS XOUT
         CMP #EOL
         BNE TOSV2
         LDA #13
         JSR XPUT
         LDA #10
TOSV2    CMP #$7F
         BNE TOSV3
         LDA #9
TOSV3    JSR XPUT
         JMP TOSV1
;
; XNEXT: the next byte at PTR, the carry set when XCNT are done
;
XNEXT    LDA XCNT
         ORA XCNT+1
         BEQ XNEXT2
         LDA XCNT
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
XPUT     LDY #0
         STA (PTR2),Y
         INC PTR2
         BNE XPUT1
         INC PTR2+1
XPUT1    RTS
;
; XOUT: XLEN = how far PTR2 went from BUF
;
XOUT     LDA PTR2
         SEC
         SBC #<BUF
         STA XLEN
         LDA PTR2+1
         SBC #>BUF
         STA XLEN+1
         RTS
