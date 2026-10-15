;
; EFTP_XL - FTP over FujiNet TCP connections
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; The program speaks FTP itself: the commands go over N1:, a passive
; mode data connection over N2:, both plain TCP. FujiNet's own FTP is
; not used (up to firmware 1.6.1 it always logs in as anonymous on
; port 21); TCP open, read, write, status and close are all it needs,
; so firmware 1.3 and later work.
;
; The F routines return the carry clear when all went well, else the
; carry set and A one of EOPEN, ETIME, ECLOSED, EREPLY (FTPMSG has the
; server's reply then, "530 Login incorrect.").
;
; -- the FujiNet: N1: and N2: are SIO devices $71 and $72
;
; NETCALL: command A to connection CONN; DSTATS Y ($40 in, $80 out);
; NBUF, NLEN the buffer and its length. Carry set when it failed.
;
NETCALL  STA DCOMND
         STY DSTATS
         LDA CONN
         CLC
         ADC #$71
         STA DDEVIC
         LDA #1
         STA DUNIT
         LDA #$0F
         STA DTIMLO
         LDA NBUF
         STA DBUFLO
         LDA NBUF+1
         STA DBUFHI
         LDA NLEN
         STA DBYTLO
         LDA NLEN+1
         STA DBYTHI
         LDX #0
         LDY #0
         LDA DCOMND
         CMP #'O
         BNE NETC1
         LDX #12            ; read and write
NETC1    CMP #'R
         BEQ NETC2
         CMP #'W
         BNE NETC3
NETC2    LDX NLEN           ; how many
         LDY NLEN+1
NETC3    STX DAUX1
         STY DAUX2
         JSR SIOV
         CPY #128
         RTS
;
; NSETB: NBUF = A/Y, NLEN = X
;
NSETB    STA NBUF
         STY NBUF+1
         STX NLEN
         LDA #0
         STA NLEN+1
         RTS
;
; NSTATUS: NSTAT = bytes waiting (2), connected, error
;
NSTATUS  LDA #<NSTAT
         LDY #>NSTAT
         LDX #4
         JSR NSETB
         LDA #'S
         LDY #$40
         JMP NETCALL
NCLOSE   LDX #0
         JSR NSETB
         LDA #'C
         LDY #0
         JMP NETCALL
NREAD    LDA #'R
         LDY #$40
         JMP NETCALL
NWRITE   LDA #'W
         LDY #$80
         JMP NETCALL
DCLOSE   LDA #1
         STA CONN
         BNE NCLOSE
;
; CONOPEN: open CONN to HOST, port A/Y: "N1:TCP://HOST:PORT"
;
CONOPEN  STA PTR3
         STY PTR3+1
         LDA #0
         TAX
CONO1    STA SPEC,X         ; FujiNet takes 256 bytes
         INX
         BNE CONO1
         LDA #<SPEC
         LDY #>SPEC
         JSR SBSTART
         LDA #'N
         JSR SBCH
         LDA CONN
         CLC
         ADC #'1
         JSR SBCH
         JSR SBI
         .BYTE ":TCP://",0
         LDA #<HOST
         LDY #>HOST
         JSR SBADD
         LDA #':
         JSR SBCH
         LDA PTR3
         LDY PTR3+1
         JSR SBADD
         LDX CONN
         LDA #0
         STA CPOS,X
         STA CLEN,X
         LDA #<SPEC
         LDY #>SPEC
         JSR NSETB
         INC NLEN+1         ; 256
         LDA #'O
         LDY #$80
         JMP NETCALL
;
; -- the time: TOUT ticks (and 1) is long enough to give up
;
TSTART   LDA RTCLOK+2
         STA T0
         LDA RTCLOK+1
         STA T0+1
         RTS
;
; TIMEUP: carry set when TOUT ticks have gone since TSTART
;
TIMEUP   LDA RTCLOK+2
         SEC
         SBC T0
         TAX
         LDA RTCLOK+1
         SBC T0+1
         TAY
         CPX TOUT
         TYA
         SBC TOUT+1
         RTS
;
; -- reading what comes, a buffer for each connection
;
; GETC: the next byte from CONN in A
;
GETC     LDX CONN
         LDA CPOS,X
         CMP CLEN,X
         BCS GETC1
         INC CPOS,X
         TAY
         JSR CBUFP
         LDA (PTR3),Y
         CLC
         RTS
GETC1    JSR TSTART
GETC2    JSR NSTATUS
         BCS GETC5
         LDA NSTAT
         ORA NSTAT+1
         BNE GETC3
         LDA NSTAT+2        ; connected?
         BEQ GETC5
         JSR TIMEUP
         BCC GETC2
         LDA #ETIME
         RTS
GETC3    LDA NSTAT          ; at most 128
         LDX NSTAT+1
         BNE GETC4
         CMP #128
         BCC GETC4A
GETC4    LDA #128
GETC4A   LDX CONN
         STA CLEN,X
         PHA
         LDA #0
         STA CPOS,X
         JSR CBUFP
         PLA
         TAX
         LDA PTR3
         LDY PTR3+1
         JSR NSETB
         JSR NREAD
         BCC GETC
GETC5    LDA #ECLOSED
         SEC
         RTS
;
CBUFP    LDA CBUFL,X
         STA PTR3
         LDA CBUFH,X
         STA PTR3+1
         RTS
CBUFL    .BYTE <CBUF0,<CBUF1
CBUFH    .BYTE >CBUF0,>CBUF1
;
; GETS: a line from CONN into A/Y without its CR LF, X bytes at most
; with its 0 (the rest is left out). The last line may end without LF.
;
GETS     STA PTR2
         STY PTR2+1
         STX GMAX
         LDA #0
         STA GLEN
GETS1    JSR GETC
         BCS GETS3
         CMP #10
         BEQ GETS2
         CMP #13
         BEQ GETS1
         LDY GLEN
         INY
         CPY GMAX
         BCS GETS1
         DEY
         STA (PTR2),Y
         INC GLEN
         BNE GETS1
GETS2    LDY GLEN
         LDA #0
         STA (PTR2),Y
         CLC
         RTS
GETS3    PHA
         JSR GETS2
         PLA
         CMP #ECLOSED
         BNE GETS4
         LDY GLEN
         BNE GETS5
GETS4    SEC
         RTS
GETS5    CLC
         RTS
;
; REPLY: the server's reply, the lines of a long one too; the last in
; FTPMSG, its code in RCHI (the first digit) and RCLO (the others)
;
REPLY    LDA #0
         STA CONN
         LDA #<FTPMSG
         LDY #>FTPMSG
         LDX #80
         JSR GETS
         BCS REPLY9
         LDA FTPMSG
         CMP #'1
         BCC REPLYX
         CMP #'6
         BCS REPLYX
         LDA FTPMSG+1
         BEQ REPLYX
         LDA FTPMSG+2
         BEQ REPLYX
         LDA FTPMSG+3
         CMP #'-
         BNE REPLY4
REPLY1   LDA #<FLINE        ; "220-..." goes on to a line "220 ..."
         LDY #>FLINE
         LDX #160
         JSR GETS
         BCS REPLY9
         LDX #2
REPLY2   LDA FLINE,X
         CMP FTPMSG,X
         BNE REPLY1
         DEX
         BPL REPLY2
         LDA FLINE+3
         CMP #32
         BNE REPLY1
         LDX #0
REPLY3   LDA FLINE,X
         STA FTPMSG,X
         BEQ REPLY4
         INX
         CPX #79
         BNE REPLY3
         LDA #0
         STA FTPMSG,X
REPLY4   LDA FTPMSG+1
         ASL A
         ASL A
         ASL A
         ASL A
         STA RCLO
         LDA FTPMSG+2
         AND #$0F
         ORA RCLO
         STA RCLO
         LDA FTPMSG
         AND #$0F
         STA RCHI
         CLC
         RTS
REPLYX   LDA #EREPLY
         SEC
REPLY9   RTS
;
; RCIS: was the reply X (first digit), A (the others: $20 for 220)?
; Z set when so
;
RCIS     CPX RCHI
         BNE RCIS1
         CMP RCLO
RCIS1    RTS
;
; SEND: the command A/Y, with ARGP after it unless ARGP+1 is 0; then
; its reply. SEND0: without.
;
SEND0    LDX #0
         STX ARGP+1
SEND     PHA
         TYA
         PHA
         LDA #<CMDB
         LDY #>CMDB
         JSR SBSTART
         PLA
         TAY
         PLA
         JSR SBADD
         LDA ARGP+1
         BEQ SEND1
         JSR SBSP
         LDA ARGP
         LDY ARGP+1
         JSR SBADD
SEND1    LDA #13
         JSR SBCH
         LDA #10
         JSR SBCH
         LDA #0
         STA CONN
         LDA SBP
         SEC
         SBC #<CMDB
         TAX
         LDA #<CMDB
         LDY #>CMDB
         JSR NSETB
         JSR NWRITE
         BCS FCLOSED
         JMP REPLY
FCLOSED  LDA #ECLOSED
         RTS
;
; FNO: the server said no
;
FNO      LDA #EREPLY
         SEC
         RTS
FOK      CLC
         RTS
;
; MSGI: FTPMSG = the string after the JSR
;
MSGI     JSR INLINE
         LDX #<FTPMSG
         STX PTR2
         LDX #>FTPMSG
         STX PTR2+1
         JMP STRCPY
;
; FCONN: connect to HOST at the port A/Y ("" is 21)
;
FCONN    STA PTR
         STY PTR+1
         LDY #0
         LDA (PTR),Y
         BNE FCONN1
         LDA #<P21
         LDY #>P21
         BNE FCONN2
FCONN1   LDA PTR
         LDY PTR+1
FCONN2   LDX #0
         STX CONN
         JSR CONOPEN
         BCC FCONN3
         JSR MSGI
         .BYTE "Could not connect.",0
         LDA #EOPEN
         SEC
         RTS
FCONN3   JSR REPLY
         BCS FCONN4
         LDX #2
         LDA #$20
         JSR RCIS
         BNE FNO
         CLC
FCONN4   RTS
P21      .BYTE "21",0
;
; FLOGIN: log in as A/Y ("": anonymous), with the password in PASSW
;
FLOGIN   STA ARGP
         STY ARGP+1
         LDY #0
         LDA (ARGP),Y
         BNE FLOG1
         LDA #<ANON
         STA ARGP
         LDA #>ANON
         STA ARGP+1
FLOG1    LDA #<VUSER
         LDY #>VUSER
         JSR SEND
         BCS FLOG9
         LDX #3
         LDA #$31
         JSR RCIS
         BNE FLOG2
         LDA #<PASSW
         STA ARGP
         LDA #>PASSW
         STA ARGP+1
         LDA #<VPASS
         LDY #>VPASS
         JSR SEND
         BCS FLOG9
FLOG2    LDX #2
         LDA #$30
         JSR RCIS
         BNE FNO2
         LDA #<TYPEI
         STA ARGP
         LDA #>TYPEI
         STA ARGP+1
         LDA #<VTYPE
         LDY #>VTYPE
         JSR SEND
         BCS FLOG9
         LDX #2
         LDA #0
         JSR RCIS
         BNE FNO2
         CLC
FLOG9    RTS
FNO2     LDA #EREPLY
         SEC
         RTS
;
; FDO: the command A/Y (with ARGP); all went well with a 2xx or 3xx
;
FDO      JSR SEND
         BCS FDO9
         LDA RCHI
         CMP #2
         BCC FNO2
         CMP #4
         BCS FNO2
         CLC
FDO9     RTS
;
; FCWD: into the folder A/Y
;
FCWD     STA ARGP
         STY ARGP+1
         LDA #<VCWD
         LDY #>VCWD
         JMP FDO
;
; FPWD: the server's folder into PATH1: 257 "/pub/atari" is ...
;
FPWD     LDA #<VPWD
         LDY #>VPWD
         JSR SEND0
         BCS FPWD9
         LDX #2
         LDA #$57
         JSR RCIS
         BNE FNO2
         LDA #<FTPMSG
         STA PTR
         LDA #>FTPMSG
         STA PTR+1
         LDA #$22
         JSR FINDCH
         BCS FNO2
         LDY #1
         LDX #0
FPWD1    LDA (PTR),Y
         BEQ FNO2
         CMP #$22
         BEQ FPWD2
         STA PATH1,X
         INY
         INX
         CPX #PATHLEN-1
         BNE FPWD1
FPWD2    LDA #0
         STA PATH1,X
         CLC
FPWD9    RTS
;
; PASV: passive mode; the data port into DPORT. EPSV first:
; 229 Entering Extended Passive Mode (|||6446|), then PASV:
; 227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)
;
PASV0    RTS
PASV     LDA #<VEPSV
         LDY #>VEPSV
         JSR SEND0
         BCS PASV0
         LDX #2
         LDA #$29
         JSR RCIS
         BNE PASV1
         LDA #<FTPMSG
         STA PTR3
         LDA #>FTPMSG
         STA PTR3+1
         JSR STRSTRI
         .BYTE "|||",0
         BCS PASV1
         LDA PTR3
         CLC
         ADC #3
         STA PTR
         LDA PTR3+1
         ADC #0
         STA PTR+1
         JSR ATOL
         JMP PASV6
PASV1    LDA #<VPASV
         LDY #>VPASV
         JSR SEND0
         BCS PASV9
         LDX #2
         LDA #$27
         JSR RCIS
         BNE PASVNO
         LDA #<FTPMSG
         STA PTR
         LDA #>FTPMSG
         STA PTR+1
         LDA #'(
         JSR FINDCH
         BCS PASV2
         JSR INCPTR
         JMP PASV4
PASV2    LDA #<[FTPMSG+4]
         STA PTR
         LDA #>[FTPMSG+4]
         STA PTR+1
PASV3    LDY #0
         LDA (PTR),Y
         BEQ PASV4
         JSR ISDIG
         BCS PASV4
         JSR INCPTR
         JMP PASV3
PASV4    LDA #4             ; past h1,h2,h3,h4
         STA PCOMMA
PASV5    LDA #',
         JSR FINDCH
         BCS PASVNO
         JSR INCPTR
         DEC PCOMMA
         BNE PASV5
         JSR ATOL
         LDA NUM
         STA PHI
         LDA #',
         JSR FINDCH
         BCS PASVNO
         JSR INCPTR
         JSR ATOL
         LDA PHI
         STA NUM+1
PASV6    LDA #<DPORT
         LDY #>DPORT
         JSR SBSTART
         JSR SBNUM
         CLC
PASV9    RTS
PASVNO   JMP FNO
;
; DOPEN: passive mode, the data connection, then the command A/Y (with
; ARGP): LIST, RETR or STOR
;
DOPEN    STA DVERB
         STY DVERB+1
         LDA ARGP
         STA DARG
         LDA ARGP+1
         STA DARG+1
         JSR PASV
         BCS DOPEN9
         LDA #1
         STA CONN
         LDA #<DPORT
         LDY #>DPORT
         JSR CONOPEN
         BCC DOPEN1
         JSR MSGI
         .BYTE "Could not open data connection.",0
         LDA #EOPEN
         SEC
         RTS
DOPEN1   LDA DARG
         STA ARGP
         LDA DARG+1
         STA ARGP+1
         LDA DVERB
         LDY DVERB+1
         JSR SEND
         BCS DOPEN2
         LDA RCHI           ; 125 or 150: it's coming
         CMP #1
         BNE DOPEN1A
         CLC
         RTS
DOPEN1A  LDA #EREPLY
DOPEN2   PHA
         JSR DCLOSE
         PLA
         SEC
DOPEN9   RTS
;
; FLIST: the folder's LIST, RADD for each line
;
FLIST    LDA #0
         STA ARGP+1
         LDA #<VLIST
         LDY #>VLIST
         JSR DOPEN
         BCS DOPEN9
FLIST1   LDA #1
         STA CONN
         LDA #<FLINE
         LDY #>FLINE
         LDX #160
         JSR GETS
         BCC FLIST2
         JMP FDONE
FLIST2   LDA FLINE
         BEQ FLIST1
         JSR RADD
         JMP FLIST1
;
; FRETR, FSTOR: the file A/Y down or up
;
FRETR    STA ARGP
         STY ARGP+1
         LDA #<VRETR
         LDY #>VRETR
         JMP DOPEN
FSTOR    STA ARGP
         STY ARGP+1
         LDA #<VSTOR
         LDY #>VSTOR
         JMP DOPEN
;
; FREAD: what has come of the file into BUF, NLEN bytes (512 at most);
; NLEN 0 at its end
;
FREAD    JSR TSTART
FREAD1   LDA #1
         STA CONN
         JSR NSTATUS
         BCS FREAD9
         LDA NSTAT
         ORA NSTAT+1
         BNE FREAD3
         LDA NSTAT+2
         BEQ FREAD2
         JSR TIMEUP
         BCC FREAD1
         LDA #ETIME
         RTS
FREAD2   STA NLEN
         STA NLEN+1
         CLC
         RTS
FREAD3   LDA NSTAT
         LDX NSTAT+1
         CPX #2
         BCC FREAD4
         LDA #0
         LDX #2
FREAD4   STX TMP
         TAX
         LDA #<BUF
         LDY #>BUF
         JSR NSETB
         LDA TMP
         STA NLEN+1
         JSR NREAD
         BCC FREAD5
FREAD9   JMP FCLOSED1
FREAD5   RTS
FCLOSED1 LDA #ECLOSED
         SEC
         RTS
;
; FWRITE: XLEN bytes of BUF
;
FWRITE   LDA #1
         STA CONN
         LDA #<BUF
         LDY #>BUF
         LDX XLEN
         JSR NSETB
         LDA XLEN+1
         STA NLEN+1
         JSR NWRITE
         BCS FCLOSED1
         RTS
;
; FDONE: the file has all gone: 226 or 250
;
FDONE    JSR DCLOSE
         JSR REPLY
         BCS FDONE9
         LDX #2
         LDA #$26
         JSR RCIS
         BEQ FDONE8
         LDA #$50
         JSR RCIS
         BEQ FDONE8
         JMP FNO
FDONE8   CLC
FDONE9   RTS
;
; FABORT: stop a file early. Closing the data connection ends it; the
; server says so (426, at times 226 too): read what comes within two
; seconds, so it isn't taken for the next command's reply.
;
FABORT   JSR DCLOSE
         LDA #121
         STA TOUT
         LDA #0
         STA TOUT+1
FABORT1  JSR REPLY
         BCC FABORT1
FTOUT    LDA #<1201         ; 20 seconds
         STA TOUT
         LDA #>1201
         STA TOUT+1
         RTS
;
FQUIT    LDA #<VQUIT
         LDY #>VQUIT
         JSR SEND0
         LDA #0
         STA CONN
         JMP NCLOSE
;
VUSER    .BYTE "USER",0
VPASS    .BYTE "PASS",0
VTYPE    .BYTE "TYPE",0
VCWD     .BYTE "CWD",0
VPWD     .BYTE "PWD",0
VEPSV    .BYTE "EPSV",0
VPASV    .BYTE "PASV",0
VLIST    .BYTE "LIST",0
VRETR    .BYTE "RETR",0
VSTOR    .BYTE "STOR",0
VQUIT    .BYTE "QUIT",0
ANON     .BYTE "anonymous",0
TYPEI    .BYTE "I",0
