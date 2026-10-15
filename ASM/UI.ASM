;
; EFTP_XL - the main screen, after EFTP on the ST
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
;   0  title bar                       16  -------+-------
;   1  info line                       17  details of the cursor's file
;   2  -------------+------------      18  --- Transfers -------
;   3  D1:>GAMES>   | /pub/atari       19-21 transfers
;   4  2 dirs 5 files| 2 dirs 5 files  22  ---------------
;   5-15 the files  | the files        23  keys
;
; Most routines work on the pane in SIDE (PUSE); ACTIVE is the pane
; with the keyboard.
;
START    LDA #<BSS          ; the variables start at 0
         STA PTR
         LDA #>BSS
         STA PTR+1
         LDY #0
START1   TYA
         STA (PTR),Y
         JSR INCPTR
         LDA PTR+1
         CMP #>BSSEND
         BCC START1
         LDA PTR
         CMP #<BSSEND
         BCC START1
         STY CONN
         STY ACTIVE
         STY SINV
         TSX                ; for ^Q, back to DOS from anywhere
         STX SAVESP
         JSR FTOUT
         LDA #NO
         STA SITE
         LDA #1
         JSR LDRIVE
         JSR SCRINIT
         JSR DALL
         JSR SLOAD
         JSR READLOC
         LDA #LOCAL
         JSR DPANE
         JSR DDETAIL
MAIN     JSR KEYGET
         STA KEY
         LDA ACTIVE
         JSR PUSE
         JSR DISP
         JMP MAIN
;
; DISP: the key's routine (they end with RTS)
;
DISP     LDX #0
DISP1    LDA KEYS,X
         BEQ DISP3
         CMP KEY
         BEQ DISP2
         INX
         BNE DISP1
DISP2    LDA KEYH,X
         PHA
         LDA KEYL,X
         PHA
         RTS
DISP3    LDA KEY            ; 1-8: a drive, in the Atari's pane
         CMP #'1
         BCC DISP4
         CMP #'9
         BCS DISP4
         LDX ACTIVE
         BNE DISP4
         AND #$0F
         JSR LDRIVE
         JSR READLOC
         LDA #LOCAL
         JSR DPANE
         JMP DDETAIL
DISP4    JSR ISALPH         ; a letter: the next name starting with it
         BCC DISP5
         JMP JUMP
DISP5    RTS
;
KEYS     .BYTE KUP,'-,KDOWN,'=,KLEFT,'+,KRIGHT,'*,KTAB,KRETURN,KBKSP,32
         .BYTE 1,11,4,18,KHELP,'?,17,20,14,5,KDEL,KDEL2,0
KEYL     .BYTE <[HUP-1],<[HUP-1],<[HDOWN-1],<[HDOWN-1],<[HPGUP-1]
         .BYTE <[HPGUP-1],<[HPGDN-1],<[HPGDN-1],<[HTAB-1],<[OPENENT-1]
         .BYTE <[GOUP-1],<[HSPACE-1],<[HMALL-1],<[HSITES-1],<[HDISC-1]
         .BYTE <[HREAD-1],<[HELP-1],<[HELP-1],<[HQUIT-1],<[HSEND-1]
         .BYTE <[NEWFOLD-1],<[RENAME-1],<[DELETE-1],<[DELETE-1]
KEYH     .BYTE >[HUP-1],>[HUP-1],>[HDOWN-1],>[HDOWN-1],>[HPGUP-1]
         .BYTE >[HPGUP-1],>[HPGDN-1],>[HPGDN-1],>[HTAB-1],>[OPENENT-1]
         .BYTE >[GOUP-1],>[HSPACE-1],>[HMALL-1],>[HSITES-1],>[HDISC-1]
         .BYTE >[HREAD-1],>[HELP-1],>[HELP-1],>[HQUIT-1],>[HSEND-1]
         .BYTE >[NEWFOLD-1],>[RENAME-1],>[DELETE-1],>[DELETE-1]
;
HUP      LDX SIDE
         LDA PCUR,X
         BEQ DISP5
         SEC
         SBC #1
         JMP MOVETO
HDOWN    LDX SIDE
         LDA PCUR,X
         CLC
         ADC #1
         JMP MOVETO
HPGUP    LDX SIDE
         LDA PCUR,X
         SEC
         SBC #VIS
         BCS HPGUP1
         LDA #0
HPGUP1   JMP MOVETO
HPGDN    LDX SIDE
         LDA PCUR,X
         CLC
         ADC #VIS
         JMP MOVETO
HTAB     LDA CONNECTD
         BEQ NOTCONN
         LDA ACTIVE
         EOR #1
         STA ACTIVE
         JMP DPANES
NOTCONN  JSR INFOI
         .BYTE "Not connected: ^K picks a site",0
         RTS
HSPACE   LDA #0
         JMP MARK
HMALL    LDA #1
         JMP MARK
HSITES   JSR SITESCR
         PHA
         JSR DALL
         PLA
         BMI HSITES1
         JSR CONNECT
         JMP DPANES         ; the panes; the info line keeps what was said
HSITES1  RTS
HDISC    JSR DISC
         JMP DALL
HREAD    JSR READLOC
         LDA CONNECTD
         BEQ HREAD1
         JSR READREM
HREAD1   JMP DALL
HQUIT    JSR DISC
         JSR SCRDONE
         LDX SAVESP
         TXS
         RTS
HSEND    LDA #0
         JMP SENDF
;
; -- drawing
;
; INFO: A/Y on the info line, and the dot when connected
;
INFOI    JSR INLINE
INFO     PHA
         TYA
         PHA
         LDX #1
         LDY #SCRL
         JSR AT
         LDA #SCRW-1
         STA SW
         PLA
         TAY
         PLA
         JSR PUTW
         LDA #32
         LDX CONNECTD
         BEQ INFO1
         LDA #CHDOT
INFO1    JMP PUTCH
;
; IDLE: the info line when nothing is going on
;
IDLE     LDA CONNECTD
         BEQ IDLE1
         LDX SITE
         JSR SSEL
         LDA SITEP
         LDY SITEP+1
         JMP INFO
IDLE1    JSR INFOI
         .BYTE "Not connected",0
         RTS
;
; INFOMSG: MSG on the info line
;
INFOMSG  LDA #<MSG
         LDY #>MSG
         JMP INFO
MSGSTART LDA #<MSG
         LDY #>MSG
         JMP SBSTART
;
DFRAME   LDX #2
DFRAME1  JSR CLRROW
         INX
         CPX #23
         BNE DFRAME1
         LDX #2
         JSR RULE
         LDX #16
         JSR RULE
         LDX #2
DFRAME2  LDY #DIV
         JSR AT
         LDA #CHVLINE
         CPX #2
         BNE DFRAME3
         LDA #CHTT
DFRAME3  CPX #16
         BNE DFRAME4
         LDA #CHBT
DFRAME4  JSR PUTCH
         INX
         CPX #17
         BNE DFRAME2
         LDX #XROW
         JSR RULE
         LDX #XROW
         LDY #SCRL+1
         JSR AT
         JSR PUTSI
         .BYTE " Transfers ",0
         LDX #22
         JSR RULE
         JMP XDRAW
;
; DENTRY: entry A of the pane in SIDE, on its row
;
DENTRY   STA DEI
         LDX SIDE
         SEC
         SBC PTOP,X
         CLC
         ADC #LISTROW
         TAX
         LDY SIDE
         LDA COL0,Y
         TAY
         JSR AT
         LDX SIDE
         LDA DEI
         CMP PCOUNT,X
         BCC DENT1
         LDA WIDTH,X
         STA SW
         JMP SPACES
DENT1    LDY #0
         CPX ACTIVE
         BNE DENT2
         CMP PCUR,X
         BNE DENT2
         LDY #$80
DENT2    STY SINV
         CLC
         ADC BASE
         STA DEK
         TAX
         LDA EFLAG,X
         STA DEF
         LDY #CHUP
         AND #EUP
         BNE DENT3
         LDY #CHMARK
         LDA DEF
         AND #EMARK
         BNE DENT3
         LDY #CHFOLDER
         LDA DEF
         AND #EDIR
         BNE DENT3
         LDY #CHFILE
DENT3    TYA
         JSR PUTCH
         LDA #NAMEW
         CLC
         ADC SIDE
         STA SW
         LDX DEK
         JSR ENAME
         JSR STRLEN
         CMP SW
         BCC DENT4
         BEQ DENT4
         DEC SW
         JSR DENTN
         LDA #CHMORE
         JSR PUTCH
         JMP DENT5
DENT4    JSR DENTN
DENT5    JSR SIZESTART
         LDA DEF
         AND #EDIR+EUP
         BNE DENT6
         LDX DEK
         JSR ESIZE
         JSR SBSIZE
DENT6    LDA #<SIZEB
         LDY #>SIZEB
         JSR STRLEN
         EOR #$FF
         SEC
         ADC #5
         STA SW
         JSR SPACES
         LDA #<SIZEB
         LDY #>SIZEB
         JSR PUTS
         JMP INVOFF
DENTN    LDX DEK
         JSR ENAME
         JMP PUTW
SIZESTART LDA #<SIZEB
         LDY #>SIZEB
         JMP SBSTART
;
DLIST    LDX SIDE
         LDA PTOP,X
         STA DLI
DLIST1   LDA DLI
         JSR DENTRY
         INC DLI
         LDX SIDE
         LDA PTOP,X
         CLC
         ADC #VIS
         CMP DLI
         BNE DLIST1
         RTS
;
; MARKED: how many are marked in the active pane (A, MCNT); MSIZE
; their size
;
MARKED   LDA ACTIVE
         JSR PUSE
         LDA #0
         STA MCNT
         STA MSIZE
         STA MSIZE+1
         STA MSIZE+2
         STA MSIZE+3
         JSR PEND
         LDX BASE
MARKED1  CPX TMP4
         BCS MARKED3
         LDA EFLAG,X
         AND #EMARK
         BEQ MARKED2
         INC MCNT
         CLC
         LDA MSIZE
         ADC ES0,X
         STA MSIZE
         LDA MSIZE+1
         ADC ES1,X
         STA MSIZE+1
         LDA MSIZE+2
         ADC ES2,X
         STA MSIZE+2
         LDA MSIZE+3
         ADC ES3,X
         STA MSIZE+3
MARKED2  INX
         BNE MARKED1
MARKED3  LDA MCNT
         RTS
;
; PEND: TMP4 = the end of the pane in SIDE (BASE + its count)
;
PEND     LDX SIDE
         LDA BASE
         CLC
         ADC PCOUNT,X
         STA TMP4
         RTS
;
; CURENT: the entry under the active pane's cursor, in A, X and CURK;
; the pane's count in Y, Z set when it is empty
;
CURENT   LDA ACTIVE
         JSR PUSE
         LDA BASE
         CLC
         ADC PCUR,X
         STA CURK
         TAX
         LDY SIDE
         LDA PCOUNT,Y
         TAY
         PHP
         TXA
         PLP
         RTS
;
DDETAIL  LDX #DETROW
         JSR CLRROW
         LDY #SCRL
         JSR AT
         JSR MARKED
         BEQ DDET1
         JSR MSGSTART
         LDA MCNT
         JSR SBBYTE
         JSR SBI
         .BYTE " marked, ",0
         LDA #<MSIZE
         LDY #>MSIZE
         JSR GETL
         JSR SBSIZE
         JMP DDET5
DDET1    JSR CURENT
         BEQ DDET6
         LDA EFLAG,X
         AND #EUP
         BEQ DDET2
         JSR PUTSI
         .BYTE "The folder above",0
         RTS
DDET2    JSR ENAME
         JSR STRLEN
         CMP #22
         BCC DDET3
         LDA #22
DDET3    STA SW
         LDX CURK
         JSR ENAME
         JSR PUTW
         JSR MSGSTART
         JSR SBSP
         LDX CURK
         LDA EFLAG,X
         AND #EDIR
         BEQ DDET4
         JSR SBI
         .BYTE "folder",0
         JMP DDET4A
DDET4    JSR ESIZE
         JSR SBSIZE
DDET4A   JSR SBSP
         LDX CURK
         JSR SBSTAMP
         LDA #<MSG
         LDY #>MSG
         JSR STRLEN
         CLC
         ADC SCOL
         CMP #SCRR+2
         BCS DDET6
DDET5    LDA #<MSG
         LDY #>MSG
         JMP PUTS
DDET6    RTS
;
; DPANE: pane A: its folder, how many there are, its files
;
DPANE    STA DPS
         JSR PUSE
         LDX DPS
         LDA COL0,X
         STA DPC
         LDA WIDTH,X
         STA DPW
         STA SW
         LDX #HEADROW
         LDY DPC
         JSR AT
         LDA DPS
         BEQ DPANE3
         LDA CONNECTD
         BNE DPANE3
         JMP DPNOCON
DPANE3   LDY #0             ; the folder, its end when it's too long
         LDA DPS
         CMP ACTIVE
         BNE DPANE4
         LDY #$80
DPANE4   STY SINV
         LDX DPS
         LDA PATHL,X
         STA DPP
         LDA PATHH,X
         STA DPP+1
         LDY DPP+1
         LDA DPP
         JSR STRLEN
         CMP DPW
         BCC DPANE5
         BEQ DPANE5
         SBC DPW            ; carry is set: n - w + 1 on
         SEC
         ADC DPP
         STA DPP
         BCC DPANE4A
         INC DPP+1
DPANE4A  DEC SW
         LDA #CHMORE
         JSR PUTCH
DPANE5   LDA DPP
         LDY DPP+1
         JSR PUTW
         JSR INVOFF
         JSR MSGSTART
         LDX DPS
         LDA PDIRS,X
         PHA
         JSR SBBYTE
         JSR SBI
         .BYTE " dir",0
         PLA
         JSR SBPLURAL
         JSR SBSP
         LDX DPS
         LDA PFILES,X
         PHA
         JSR SBBYTE
         JSR SBI
         .BYTE " file",0
         PLA
         JSR SBPLURAL
         LDX DPS
         LDA PFULL,X
         BEQ DPANE6
         LDA #'+
         JSR SBCH
DPANE6   LDX #CNTROW
         LDY DPC
         JSR AT
         LDA DPW
         STA SW
         JSR INFOMSG1
         JMP DLIST
INFOMSG1 LDA #<MSG
         LDY #>MSG
         JMP PUTW
;
; DPNOCON: the server's pane when not connected
;
DPNOCON  LDA #<SERVER
         LDY #>SERVER
         JSR PUTW
         LDX #CNTROW
DPANE1   LDY DPC
         JSR AT
         JSR SPACES
         LDX SROW
         INX
         CPX #LISTROW+VIS
         BNE DPANE1
         INC DPC
         LDX #LISTROW+2
         JSR DPAT
         JSR PUTSI
         .BYTE "Not connected.",0
         LDX #LISTROW+4
         JSR DPAT
         JSR PUTSI
         .BYTE "Press ^K to pick",0
         LDX #LISTROW+5
         JSR DPAT
         JSR PUTSI
         .BYTE "a site, or to add",0
         LDX #LISTROW+6
         JSR DPAT
         JSR PUTSI
         .BYTE "one with ^N.",0
         RTS
DPAT     LDY DPC
         JMP AT
;
; SBPLURAL: "s" unless A is 1
;
SBPLURAL CMP #1
         BEQ SBPL1
         LDA #'s
         JMP SBCH
SBPL1    RTS
;
DPANES   LDA #LOCAL
         JSR DPANE
         LDA #REMOTE
         JSR DPANE
         JMP DDETAIL
;
DALL     LDX #0
         LDY #SCRL
         JSR AT
         LDA #SCRW
         STA SW
         JSR INVON
         JSR SPACES
         LDX #0
         LDY #SCRL+1
         JSR AT
         LDA #<VERSION
         LDY #>VERSION
         JSR PUTS
         LDX #0
         LDY #SCRR-13
         JSR AT
         JSR PUTSI
         .BYTE "(C) AERA 2026",0
         JSR INVOFF
         JSR IDLE
         JSR DFRAME
         JSR DPANES
         LDA #<MKEYS
         LDY #>MKEYS
         JMP KEYBAR
;
; -- reading the panes
;
; REPORT: "what: why" on the info line, what A/Y and why from FERR
;
REPORTI  JSR INLINE
REPORT   JSR WHAT
         LDA FERR
         CMP #ETIME
         BNE REPORT1
         JSR SBI
         .BYTE "no answer",0
         JMP REPORT2
REPORT1  CMP #ECLOSED
         BNE REPORT3
         JSR SBI
         .BYTE "connection closed",0
REPORT2  LDA #0
         STA CONNECTD
         JMP INFOMSG
REPORT3  LDA #<FTPMSG
         LDY #>FTPMSG
         JSR SBADD
         JMP INFOMSG
;
; WHAT: MSG = A/Y + ": "
;
WHAT     PHA
         TYA
         PHA
         JSR MSGSTART
         PLA
         TAY
         PLA
         JSR SBADD
         JSR SBI
         .BYTE ": ",0
         RTS
;
READLOC  JSR INFOI
         .BYTE "Reading the disk...",0
         JSR LREAD
         BCC READLOC1
         STA FERR
         JSR MSGSTART
         LDA #<PATH0
         LDY #>PATH0
         JSR SBADD
         JSR SBI
         .BYTE " error ",0
         LDA FERR
         JSR SBBYTE
         JMP INFOMSG
READLOC1 JMP IDLE
;
READREM  JSR INFOI
         .BYTE "Reading the server's folder...",0
         JSR RREAD
         BCC READLOC1
         STA FERR
         JSR REPORTI
         .BYTE "List",0
         RTS
;
; FINDN: the cursor of the pane in SIDE on the name A/Y, if it's there
;
FINDN    JSR PFIND
         BCS FINDN2
         SEC
         SBC BASE
         LDX SIDE
         STA PCUR,X
         LDY #0
         CMP #VIS
         BCC FINDN1
         SBC #VIS/2
         TAY
FINDN1   TYA
         STA PTOP,X
FINDN2   RTS
;
; REREAD: read pane A again, the cursor staying on the same name
;
REREAD   STA RRS
         JSR PUSE
         LDA #0
         STA UTMP
         LDX SIDE
         LDA PCOUNT,X
         BEQ REREAD1
         LDA BASE
         CLC
         ADC PCUR,X
         TAX
         JSR ENAME
         JSR TOUTMP
REREAD1  LDA RRS
         BNE REREAD2
         JSR LREAD
         JMP REREAD3
REREAD2  JSR RREAD
REREAD3  LDA RRS
         JSR PUSE
         LDA #<UTMP
         LDY #>UTMP
         JMP FINDN
;
; TOUTMP: UTMP = A/Y
;
TOUTMP   LDX #<UTMP
         STX PTR2
         LDX #>UTMP
         STX PTR2+1
         JMP STRCPY
;
; ASK: ask A/Y on the info line, editing UTMP (EDMAX); Z set when left
; with ESC
;
ASKI     JSR INLINE
ASK      STA ASKQ
         STY ASKQ+1
         JSR INFO
         LDA ASKQ
         LDY ASKQ+1
         JSR STRLEN
         CLC
         ADC #SCRL+1
         TAY
         LDX #1
         JSR AT
         LDA #SCRR
         SEC
         SBC SCOL
         STA SW
         LDA ASKB
         LDY ASKB+1
         JSR EDIT
         CMP #KESC
         RTS
ASKTI    JSR INLINE
         LDX #<UTMP
         STX ASKB
         LDX #>UTMP
         STX ASKB+1
         JMP ASK
