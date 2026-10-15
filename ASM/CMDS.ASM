;
; EFTP_XL - the main screen's commands: connect, send, new folder,
; rename, delete, moving about, help
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; -- connecting
;
DISC     LDA CONNECTD
         BEQ DISC1
         JSR FQUIT
DISC1    LDA #0
         STA CONNECTD
         STA ACTIVE
         LDA #REMOTE
         JSR PUSE
         JMP PCLEAR
;
; CONNECT: to site A
;
CONNECT  PHA
         JSR DISC
         PLA
         STA SITE
         JSR DALL
         LDX #4             ; its password, or ask for it
         JSR SITEF
         LDX #<PASSW
         STX PTR2
         LDX #>PASSW
         STX PTR2+1
         JSR STRCPY
         LDA PASSW
         BNE CONNECT1
         JSR MSGSTART
         JSR SBI
         .BYTE "Password for ",0
         JSR SNAME
         JSR SBADD
         LDA #':
         JSR SBCH
         LDA #20
         STA EDMAX
         LDA #1
         STA EDMASK
         LDA #<PASSW
         STA ASKB
         LDA #>PASSW
         STA ASKB+1
         LDA #<MSG
         LDY #>MSG
         JSR ASK
         PHP
         LDA #0
         STA EDMASK
         PLP
         BNE CONNECT1
         JMP IDLE
CONNECT1 JSR MSGSTART
         JSR SBI
         .BYTE "Connecting to ",0
         JSR SNAME
         JSR SBADD
         JSR SBI
         .BYTE "...",0
         JSR INFOMSG
         LDX #1
         JSR SITEF
         LDX #<HOST
         STX PTR2
         LDX #>HOST
         STX PTR2+1
         JSR STRCPY
         LDX #2
         JSR SITEF
         JSR FCONN
         BCC CONNECT2
         STA FERR
         JSR REPORTI
         .BYTE "Connect",0
         JMP FQUIT
CONNECT2 LDX #3
         JSR SITEF
         JSR FLOGIN
         PHP
         PHA
         LDX #19            ; the password goes from memory
         LDA #0
CONNECT3 STA PASSW,X
         DEX
         BPL CONNECT3
         PLA
         PLP
         BCC CONNECT4
         STA FERR
         JSR REPORTI
         .BYTE "Login",0
         JMP FQUIT
CONNECT4 LDA #1
         STA CONNECTD
         LDX #5             ; the server's folder
         JSR SITEF
         JSR STRLEN
         BEQ CONNECT5
         LDX #5
         JSR SITEF
         JSR FCWD
         BCC CONNECT5
         STA FERR
         JSR REPORTI
         .BYTE "Folder",0
CONNECT5 LDX #6             ; the Atari's
         JSR SITEF
         JSR STRLEN
         BEQ CONNECT6
         LDX #6
         JSR SITEF
         LDX #<PATH0
         STX PTR2
         LDX #>PATH0
         STX PTR2+1
         JSR STRCPY
         JSR READLOC
CONNECT6 JSR READREM
         LDA CONNECTD
         STA ACTIVE
         RTS
;
; SITEF: field X of the site in SITE, A/Y; SNAME: its name
;
SNAME    LDX #0
SITEF    TXA
         PHA
         LDX SITE
         JSR SSEL
         PLA
         TAX
         JMP SFIELD
;
; -- sending
;
; SENDF: the marked files, or the one under the cursor (A not 0: only
; that one), to the other side
;
SENDF    LDX CONNECTD
         BNE SENDF1
         JMP NOTCONN
SENDF1   STA XONLY
         JSR XSEND
         BCC SENDF2
         LDA #LOCAL
         JSR REREAD
         LDA #REMOTE
         JSR REREAD
         JSR DFRAME
         JMP DPANES
SENDF2   RTS
;
; -- new folder, rename, delete: on the server FTP's MKD, RNFR and
; RNTO, DELE, RMD; on the Atari the DOS's XIO 42 (SpartaDOS), 32, 33,
; 43
;
; LSPECN: FSPEC = the Atari pane's folder + the name A/Y
;
LSPECN   PHA
         TYA
         PHA
         LDA #<FSPEC
         LDY #>FSPEC
         JSR SBSTART
         LDA #<PATH0
         LDY #>PATH0
         JSR SBADD
         PLA
         TAY
         PLA
         JMP SBADD
;
; AFTERI: done (carry and A as the call left them: a CIO status on the
; Atari, an FTP error on the server): say so, or why not; then read
; the pane again, the cursor on UTMP
;
AFTERI   STA FERR
         PHP
         PLA
         STA AFLG
         JSR INLINE
         LSR AFLG
         BCC AFTER3
         LDX ACTIVE
         BNE AFTER2
         JSR WHAT
         LDA FERR
         CMP #146
         BNE AFTER1
         JSR SBI
         .BYTE "this DOS has no folders",0
         JMP INFOMSG2
AFTER1   CMP #170
         BNE AFTER1A
         JSR SBI
         .BYTE "not found",0
         JMP INFOMSG2
AFTER1A  JSR SBI
         .BYTE "error ",0
         LDA FERR
         JSR SBBYTE
INFOMSG2 JSR INFOMSG
         JMP AFTER4
AFTER2   JSR REPORT
         JMP AFTER4
AFTER3   JSR IDLE
AFTER4   LDA ACTIVE
         BNE AFTER5
         JSR LREAD
         JMP AFTER6
AFTER5   JSR RREAD
AFTER6   LDA ACTIVE
         JSR PUSE
         LDA #<UTMP
         LDY #>UTMP
         JSR FINDN
         LDA ACTIVE
         JSR DPANE
         JMP DDETAIL
;
; EDMAXS: EDMAX = A on the Atari, 64 on the server
;
EDMAXS   LDX ACTIVE
         BEQ EDMAXS1
         LDA #64
EDMAXS1  STA EDMAX
         RTS
;
UPTMP    LDA #<UTMP
         LDY #>UTMP
         JMP UPSTR
;
NEWFOLD  LDA #0
         STA UTMP
         LDA #9
         JSR EDMAXS
         JSR ASKTI
         .BYTE "New folder:",0
         BEQ NEWF3
         LDA UTMP
         BEQ NEWF3
         LDA ACTIVE
         BNE NEWF1
         JSR UPTMP
         LDA #<UTMP
         LDY #>UTMP
         JSR LSPECN
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #42
         JSR CXIO
         JMP NEWF2
NEWF1    LDA #<UTMP
         STA ARGP
         LDA #>UTMP
         STA ARGP+1
         LDA #<VMKD
         LDY #>VMKD
         JSR FDO
NEWF2    JSR AFTERI
         .BYTE "New folder",0
NEWF3    RTS
;
RENAME   JSR CURENT
         BEQ NEWF3
         LDA EFLAG,X
         AND #EUP
         BNE NEWF3
         JSR ENAME
         JSR TOUTMP
         LDA #13
         JSR EDMAXS
         JSR ASKTI
         .BYTE "Rename to:",0
         BEQ NEWF3
         LDA UTMP
         BEQ NEWF3
         LDX CURK
         JSR ENAME
         LDX #<UTMP
         STX PTR2
         LDX #>UTMP
         STX PTR2+1
         JSR STRCMP
         BEQ NEWF3
         LDA ACTIVE
         BNE RENAME1
         JSR UPTMP
         LDX CURK
         JSR ENAME
         JSR LSPECN
         LDA #',
         JSR SBCH
         LDA #<UTMP
         LDY #>UTMP
         JSR SBADD
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #32
         JSR CXIO
         JMP RENAME2
RENAME1  LDX CURK
         JSR ENAME
         STA ARGP
         STY ARGP+1
         LDA #<VRNFR
         LDY #>VRNFR
         JSR FDO
         BCS RENAME2
         LDA #<UTMP
         STA ARGP
         LDA #>UTMP
         STA ARGP+1
         LDA #<VRNTO
         LDY #>VRNTO
         JSR FDO
RENAME2  JSR AFTERI
         .BYTE "Rename",0
         RTS
;
; DELETE: the marked files and folders, or the one under the cursor; a
; folder has to be empty, as DOS and FTP want
;
DELETE0  RTS
DELETE   JSR MARKED
         JSR CURENT
         STA DLK
         LDA MCNT
         BNE DELETE1
         TYA                ; CURENT: the count, in Y
         BEQ DELETE0
         LDA EFLAG,X
         AND #EUP
         BNE DELETE0
DELETE1  JSR MSGSTART
         JSR SBI
         .BYTE "Delete ",0
         LDA MCNT
         BEQ DELETE2
         JSR SBBYTE
         JSR SBI
         .BYTE " marked",0
         JMP DELETE3
DELETE2  LDX DLK
         JSR ENAME
         JSR SBADD
DELETE3  JSR SBI
         .BYTE "? Y/N",0
         JSR INFOMSG
         JSR KEYGET
         AND #$DF
         CMP #'Y
         BEQ DELETE4
         JMP IDLE
DELETE4  LDA #0
         STA UTMP
         JSR PEND
         LDA TMP4
         STA DLEND
         LDA MCNT
         BEQ DELETE5
         LDA BASE
         STA DLK
DELETE5  LDX DLK
         CPX DLEND
         BCS DELETE8
         LDA MCNT
         BEQ DELETE6
         LDA EFLAG,X
         AND #EMARK
         BEQ DELETE7
DELETE6  JSR DELONE
         BCS DELETE10
         LDA MCNT
         BEQ DELETE8
DELETE7  INC DLK
         JMP DELETE5
DELETE8  CLC
DELETE10 JSR AFTERI
         .BYTE "Delete",0
DELETE9  RTS
;
; DELONE: entry DLK; the carry set when it failed (A why)
;
DELONE   LDX DLK
         LDA ACTIVE
         BNE DELONE2
         JSR ENAME
         JSR LSPECN
         LDX DLK
         LDA EFLAG,X
         AND #EDIR
         LDX #33
         CMP #0
         BEQ DELONE1
         LDX #43
DELONE1  LDA #<FSPEC
         LDY #>FSPEC
         JMP CXIO
DELONE2  LDX DLK
         JSR ENAME
         STA ARGP
         STY ARGP+1
         LDX DLK
         LDA EFLAG,X
         AND #EDIR
         BNE DELONE3
         LDA #<VDELE
         LDY #>VDELE
         JMP FDO
DELONE3  LDA #<VRMD
         LDY #>VRMD
         JMP FDO
;
; -- moving about
;
; MOVETO: the active pane's cursor to entry A
;
MOVETO   STA MVI
         LDA ACTIVE
         JSR PUSE
         LDX SIDE
         LDA PCOUNT,X
         BEQ MOVETO5
         LDA PCUR,X
         STA MVOLD
         LDA PTOP,X
         STA MVTOP
         LDA MVI
         CMP PCOUNT,X
         BCC MOVETO1
         LDA PCOUNT,X
         SBC #1
         STA MVI
MOVETO1  STA PCUR,X
         CMP MVTOP
         BCS MOVETO2
         STA PTOP,X
         BCC MOVETO3
MOVETO2  LDA MVTOP
         CLC
         ADC #VIS
         STA TMP4
         LDA MVI
         CMP TMP4
         BCC MOVETO3
         SBC #VIS-1
         STA PTOP,X
MOVETO3  LDA PTOP,X
         CMP MVTOP
         BEQ MOVETO4
         JSR DLIST
         JMP DDETAIL
MOVETO4  LDA MVOLD
         JSR DENTRY
         LDA MVI
         JSR DENTRY
         JMP DDETAIL
MOVETO5  RTS
;
GOUP     LDA ACTIVE
         BNE GOUP2
         LDA #<PATH0        ; remember the folder left: "D1:>A>B>" -> "B"
         LDY #>PATH0
         JSR TOUTMP
         DEY
         LDA #0
         STA UTMP,Y
GOUP1    DEY
         BMI GOUP1A
         LDA UTMP,Y
         CMP #'>
         BNE GOUP1
GOUP1A   INY
         STY GUOFF
         JSR LUP
         BCS MOVETO5
         JSR READLOC
         JMP GOUP5
GOUP2    LDY #0             ; "/pub/atari" -> "atari"
         STY GUOFF
         LDX #0
GOUP3    LDA PATH1,Y
         BEQ GOUP4
         INY
         CMP #'/
         BNE GOUP3
         STY GUOFF
         BEQ GOUP3
GOUP4    LDA GUOFF
         CLC
         ADC #<PATH1
         TAX
         LDA #>PATH1
         ADC #0
         TAY
         TXA
         JSR TOUTMP
         LDA #0
         STA GUOFF
         LDA #<DOTDOT
         LDY #>DOTDOT
         JSR FCWD
         BCC GOUP4A
         STA FERR
         JSR REPORTI
         .BYTE "Folder",0
         RTS
GOUP4A   JSR READREM
GOUP5    LDA ACTIVE
         JSR PUSE
         LDA #<UTMP
         CLC
         ADC GUOFF
         TAX
         LDA #>UTMP
         ADC #0
         TAY
         TXA
         JSR FINDN
         LDA ACTIVE
         JSR DPANE
         JMP DDETAIL
;
OPENENT0 RTS
OPENENT  JSR CURENT
         BEQ OPENENT0
         LDA EFLAG,X
         AND #EUP
         BEQ OPENENT1
         JMP GOUP
OPENENT1 LDA EFLAG,X
         AND #EDIR
         BNE OPENENT2
         LDA #1
         JMP SENDF
OPENENT2 JSR ENAME
         JSR TOUTMP
         LDA ACTIVE
         BNE OPENENT3
         LDA #<UTMP
         LDY #>UTMP
         JSR LINTO
         JSR READLOC
         JMP OPENENT4
OPENENT3 LDA #<UTMP
         LDY #>UTMP
         JSR FCWD
         BCC OPENENT5
         STA FERR
         JSR REPORTI
         .BYTE "Folder",0
         RTS
OPENENT5 JSR READREM
OPENENT4 LDA ACTIVE
         JSR DPANE
         JMP DDETAIL
;
; MARK: the file under the cursor and on (A 0), or all of them, or none
; when they all are
;
MARK     STA MKALL
         JSR CURENT
         BEQ MARK9
         JSR PEND
         LDA MKALL
         BNE MARK2
         LDX CURK
         LDA EFLAG,X
         AND #EUP
         BNE MARK1
         LDA EFLAG,X
         EOR #EMARK
         STA EFLAG,X
MARK1    LDX SIDE
         LDA PCUR,X
         JSR DENTRY
         LDX SIDE
         LDA PCUR,X
         CLC
         ADC #1
         JMP MOVETO
MARK2    LDA #0
         STA MKANY
         LDX BASE
MARK3    CPX TMP4
         BCS MARK4
         LDA EFLAG,X
         AND #EUP+EDIR+EMARK
         BNE MARK3A
         INC MKANY
MARK3A   INX
         BNE MARK3
MARK4    LDX BASE
MARK5    CPX TMP4
         BCS MARK7
         LDA EFLAG,X
         AND #EUP+EDIR
         BNE MARK6
         LDA EFLAG,X
         AND #255-EMARK
         LDY MKANY
         BEQ MARK5A
         ORA #EMARK
MARK5A   STA EFLAG,X
MARK6    INX
         BNE MARK5
MARK7    JSR DLIST
         JMP DDETAIL
MARK9    RTS
;
; JUMP: the next name starting with the letter A
;
JUMP     JSR UPPER
         STA JKEY
         LDA ACTIVE
         JSR PUSE
         LDX SIDE
         LDA PCOUNT,X
         STA JN
         BEQ MARK9
         LDA #1
         STA JI
JUMP1    LDX SIDE
         LDA PCUR,X
         CLC
         ADC JI
JUMP2    CMP JN
         BCC JUMP3
         SBC JN
         JMP JUMP2
JUMP3    STA JJ
         CLC
         ADC BASE
         TAX
         JSR ENAME
         STA PTR
         STY PTR+1
         LDY #0
         LDA (PTR),Y
         JSR UPPER
         CMP JKEY
         BEQ JUMP4
         INC JI
         LDA JN
         CMP JI
         BCS JUMP1
         RTS
JUMP4    LDA JJ
         JMP MOVETO
;
HELP     LDA #<HTITLE
         LDY #>HTITLE
         JSR BOX
         LDA #<HKEYS
         STA PTR3
         LDA #>HKEYS
         STA PTR3+1
         LDA #4
         STA HROW
HELP1    LDY #0
         LDA (PTR3),Y
         BEQ HELP2
         LDX HROW
         LDY #SCRL+2
         JSR AT
         JSR INVON
         JSR KEYB2
         JSR INVOFF
         LDX HROW
         LDY #SCRL+10
         JSR AT
         JSR KEYB2
         INC HROW
         JMP HELP1
HELP2    LDX #18
         LDY #SCRL+2
         JSR AT
         JSR PUTSI
         .BYTE "The same keys as EFTP on the ST.",0
         LDX #21
         LDY #SCRL+2
         JSR AT
         JSR INVON
         JSR PUTSI
         .BYTE "Any key",0
         JSR INVOFF
         INC SCOL
         JSR PUTSI
         .BYTE "back",0
         JSR KEYGET
         JMP DALL
;
COL0     .BYTE SCRL,DIV+1
WIDTH    .BYTE DIV-SCRL,SCRR-DIV
PATHL    .BYTE <PATH0,<PATH1
PATHH    .BYTE >PATH0,>PATH1
SERVER   .BYTE "Server",0
MKEYS    .BYTE "^K",0,"Sites",0,"^T",0,"Send",0,"TAB",0,"Pane",0
         .BYTE "HELP",0,"Keys",0,0
HTITLE   .BYTE "Keys",0
HKEYS    .BYTE "^K ^D",0,"sites / disconnect",0
         .BYTE "RETURN",0,"open folder, send file",0
         .BYTE "SPACE",0,"mark file and move on",0
         .BYTE "^A",0,"mark all",0
         .BYTE "^T",0,"send what is marked",0
         .BYTE "BKSP",0,"folder up",0
         .BYTE "TAB",0,"other pane",0
         .BYTE "^N ^E",0,"new folder / rename",0
         .BYTE "DEL",0,"delete",0
         .BYTE "^R",0,"read lists again",0
         .BYTE "1-8",0,"drive D1:-D8:",0
         .BYTE "ESC",0,"stop transfer",0
         .BYTE "^Q",0,"quit to DOS",0,0
VMKD     .BYTE "MKD",0
VRNFR    .BYTE "RNFR",0
VRNTO    .BYTE "RNTO",0
VDELE    .BYTE "DELE",0
VRMD     .BYTE "RMD",0
