;
; CMDS.M65 - EFTP_XL 1.0
; Main screen commands
; Copyright (C) 2026 AERA | Erez Yaary
;
; DISC - QUIT if connected, clear
; the server pane
;
DISC     LDA CONNECTD
         BEQ DISC1
         JSR FQUIT
DISC1    LDA #0
         STA CONNECTD
         STA ACTIVE         ; back to the Atari
         LDA #REMOTE
         JSR PUSE
         JMP PCLEAR
;
; CONNECT - connect and log in
; A=site
;
CONNECT  PHA
         JSR DISC
         PLA
         STA SITE
         JSR DALL
         LDX #4             ; its password
         JSR SITEF
         LDX #<PASSW
         STX PTR2
         LDX #>PASSW
         STX PTR2+1
         JSR STRCPY
         LDA PASSW
         BNE CONNECT1       ; none: ask for it
         JSR MSGSTART
         JSR SBI
         .BYTE "Password for ",0
         JSR SNAME
         JSR SBADD
         LDA #':
         JSR SBCH
         LDA #20            ; 19 at most
         STA EDMAX
         LDA #1             ; show *s
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
         JMP IDLE           ; ESC
CONNECT1 JSR MSGSTART
         JSR SBI
         .BYTE "Connecting to ",0
         JSR SNAME
         JSR SBADD
         JSR SBI
         .BYTE "...",0
         JSR INFOMSG
         LDX #1             ; host
         JSR SITEF
         LDX #<HOST
         STX PTR2
         LDX #>HOST
         STX PTR2+1
         JSR STRCPY
         LDX #2             ; port
         JSR SITEF
         JSR FCONN
         BCC CONNECT2
         STA FERR
         JSR REPORTI
         .BYTE "Connect",0
         JMP FQUIT
CONNECT2 LDX #3             ; user
         JSR SITEF
         JSR FLOGIN
         PHP
         PHA
         LDX #19            ; wipe the password
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
         LDX #5             ; server folder
         JSR SITEF
         JSR STRLEN
         BEQ CONNECT5       ; none given
         LDX #5
         JSR SITEF
         JSR FCWD
         BCC CONNECT5
         STA FERR
         JSR REPORTI
         .BYTE "Folder",0
CONNECT5 LDX #6             ; Atari folder
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
         STA ACTIVE         ; server pane
         RTS
;
; SITEF - field X of site SITE
; SNAME - its name (field 0)
; Exit: A/Y=field
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
; SENDF - send the marked, or the
; one under the cursor, to the
; other side
; A=0 marked, else only the one
;
SENDF    LDX CONNECTD
         BNE SENDF1
         JMP NOTCONN
SENDF1   STA XONLY
         JSR XSEND
         BCC SENDF2         ; nothing sent
         LDA #LOCAL
         JSR REREAD
         LDA #REMOTE
         JSR REREAD
         JSR DFRAME
         JMP DPANES
SENDF2   RTS
;
; New folder, rename, delete
; Server: MKD, RNFR/RNTO, DELE, RMD
; Atari: XIO 42, 32, 33, 43
;
; LSPECN - FSPEC = Atari folder
; + name
; A/Y=name
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
; AFTERI - say how it went, read the
; pane again, cursor on UTMP
; What it was after the JSR
; C=1 failed, A=CIO status (Atari)
; or FTP error (server)
;
AFTERI   STA FERR
         PHP
         PLA
         STA AFLG           ; carry in bit 0
         JSR INLINE
         LSR AFLG
         BCC AFTER3         ; it worked
         LDX ACTIVE
         BNE AFTER2
         JSR WHAT
         LDA FERR
         CMP #146           ; not supported
         BNE AFTER1
         JSR SBI
         .BYTE "this DOS has no folders",0
         JMP INFOMSG2
AFTER1   CMP #170           ; not found
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
AFTER2   JSR REPORT         ; server error
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
; EDMAXS - EDMAX = A on the Atari,
; 64 on the server
;
EDMAXS   LDX ACTIVE
         BEQ EDMAXS1
         LDA #64
EDMAXS1  STA EDMAX
         RTS
;
; UPTMP - UTMP in capitals
;
UPTMP    LDA #<UTMP
         LDY #>UTMP
         JMP UPSTR
;
; NEWFOLD - ask a name, make the
; folder in the active pane
;
NEWFOLD  LDA #0
         STA UTMP
         LDA #9             ; 8 chars on Atari
         JSR EDMAXS
         JSR ASKTI
         .BYTE "New folder:",0
         BEQ NEWF3          ; ESC
         LDA UTMP
         BEQ NEWF3          ; no name
         LDA ACTIVE
         BNE NEWF1
         JSR UPTMP
         LDA #<UTMP
         LDY #>UTMP
         JSR LSPECN
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #42            ; MKDIR
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
; RENAME - rename the entry under
; the cursor
;
RENAME   JSR CURENT
         BEQ NEWF3
         LDA EFLAG,X
         AND #EUP           ; not ".."
         BNE NEWF3
         JSR ENAME
         JSR TOUTMP         ; edit the old name
         LDA #13            ; 8.3 on Atari
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
         BEQ NEWF3          ; unchanged
         LDA ACTIVE
         BNE RENAME1
         JSR UPTMP
         LDX CURK
         JSR ENAME
         JSR LSPECN         ; "D1:>OLD,NEW"
         LDA #',
         JSR SBCH
         LDA #<UTMP
         LDY #>UTMP
         JSR SBADD
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #32            ; rename
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
; DELETE - delete the marked, or the
; one under the cursor, after a Y/N
; A folder must be empty
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
         AND #$DF           ; y = Y
         CMP #'Y
         BEQ DELETE4
         JMP IDLE
DELETE4  LDA #0
         STA UTMP           ; no name to find
         JSR PEND
         LDA TMP4
         STA DLEND
         LDA MCNT
         BEQ DELETE5
         LDA BASE           ; marked: from the top
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
         BCS DELETE10       ; stop at an error
         LDA MCNT
         BEQ DELETE8        ; only the one
DELETE7  INC DLK
         JMP DELETE5
DELETE8  CLC
DELETE10 JSR AFTERI
         .BYTE "Delete",0
DELETE9  RTS
;
; DELONE - delete entry DLK
; Exit: C=1 failed, A=why
;
DELONE   LDX DLK
         LDA ACTIVE
         BNE DELONE2
         JSR ENAME
         JSR LSPECN
         LDX DLK
         LDA EFLAG,X
         AND #EDIR
         LDX #33            ; file
         CMP #0             ; LDX hit Z
         BEQ DELONE1
         LDX #43            ; folder
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
; MOVETO - active pane's cursor to
; entry A, scrolling as needed
;
MOVETO   STA MVI
         LDA ACTIVE
         JSR PUSE
         LDX SIDE
         LDA PCOUNT,X
         BEQ MOVETO5        ; empty
         LDA PCUR,X
         STA MVOLD
         LDA PTOP,X
         STA MVTOP
         LDA MVI
         CMP PCOUNT,X
         BCC MOVETO1
         LDA PCOUNT,X       ; past end: last
         SBC #1
         STA MVI
MOVETO1  STA PCUR,X
         CMP MVTOP
         BCS MOVETO2
         STA PTOP,X         ; above: scroll up
         BCC MOVETO3
MOVETO2  LDA MVTOP
         CLC
         ADC #VIS
         STA TMP4
         LDA MVI
         CMP TMP4
         BCC MOVETO3
         SBC #VIS-1         ; below: bottom row
         STA PTOP,X
MOVETO3  LDA PTOP,X
         CMP MVTOP
         BEQ MOVETO4
         JSR DLIST          ; scrolled: all rows
         JMP DDETAIL
MOVETO4  LDA MVOLD          ; just the two rows
         JSR DENTRY
         LDA MVI
         JSR DENTRY
         JMP DDETAIL
MOVETO5  RTS
;
; GOUP - up one folder, cursor on
; the folder left
;
GOUP     LDA ACTIVE
         BNE GOUP2
         LDA #<PATH0        ; "D1:>A>B>" -> "B"
         LDY #>PATH0
         JSR TOUTMP
         DEY
         LDA #0             ; drop the last >
         STA UTMP,Y
GOUP1    DEY
         BMI GOUP1A
         LDA UTMP,Y
         CMP #'>
         BNE GOUP1
GOUP1A   INY
         STY GUOFF          ; name starts here
         JSR LUP
         BCS MOVETO5        ; at the top
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
         STY GUOFF          ; after the last /
         BEQ GOUP3          ; always
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
         LDA #<UTMP         ; find UTMP+GUOFF
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
; OPENENT - RETURN: into a folder,
; up for "..", or send a file
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
         LDA #1             ; this one only
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
; MARK - A=0: flip the mark under
; the cursor and move on; else mark
; all files, or none if all are
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
MARK2    LDA #0             ; count unmarked
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
MARK4    LDX BASE           ; files only
MARK5    CPX TMP4
         BCS MARK7
         LDA EFLAG,X
         AND #EUP+EDIR
         BNE MARK6
         LDA EFLAG,X
         AND #255-EMARK
         LDY MKANY
         BEQ MARK5A         ; all were: clear
         ORA #EMARK
MARK5A   STA EFLAG,X
MARK6    INX
         BNE MARK5
MARK7    JSR DLIST
         JMP DDETAIL
MARK9    RTS
;
; JUMP - cursor to the next name
; starting with letter A
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
JUMP2    CMP JN             ; wrap around
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
; HELP - the keys box, until a key
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
         BEQ HELP2          ; end of list
         LDX HROW
         LDY #SCRL+2
         JSR AT
         JSR INVON
         JSR KEYB2          ; the key
         JSR INVOFF
         LDX HROW
         LDY #SCRL+10
         JSR AT
         JSR KEYB2          ; what it does
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
; Per pane: Atari, server
;
COL0     .BYTE SCRL,DIV+1
WIDTH    .BYTE DIV-SCRL,SCRR-DIV
PATHL    .BYTE <PATH0,<PATH1
PATHH    .BYTE >PATH0,>PATH1
SERVER   .BYTE "Server",0
;
; Key bar and help: key, text pairs
;
MKEYS    .BYTE "^K",0,"Sites",0,"^T",0,"Send",0,"TAB",0,"Pane",0
         .BYTE "HELP",0,"Keys",0,0
HTITLE   .BYTE "Keys",0
HKEYS    .BYTE "^K ^D",0,"sites / disconnect",0
         .BYTE "RETURN",0,"open folder, send file",0
         .BYTE "SPACE",0,"mark and move on",0
         .BYTE "^A",0,"mark all",0
         .BYTE "^T",0,"send marked, folders too",0
         .BYTE "BKSP",0,"folder up",0
         .BYTE "TAB",0,"other pane",0
         .BYTE "^N ^E",0,"new folder / rename",0
         .BYTE "DEL",0,"delete",0
         .BYTE "^R",0,"read lists again",0
         .BYTE "1-8",0,"drive D1:-D8:",0
         .BYTE "ESC",0,"stop transfer",0
         .BYTE "^Q",0,"quit to DOS",0,0
;
; FTP commands
;
VMKD     .BYTE "MKD",0
VRNFR    .BYTE "RNFR",0
VRNTO    .BYTE "RNTO",0
VDELE    .BYTE "DELE",0
VRMD     .BYTE "RMD",0
