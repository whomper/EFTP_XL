;
; EFTP_XL - the Atari's addresses, the zero page, the constants
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; The OS
;
DOSVEC   =   $0A
RTCLOK   =   $12        ; $14 is the low byte
ICAX1Z   =   $2A
ATRACT   =   $4D
SAVMSC   =   $58
DDEVIC   =   $0300      ; the SIO block
DUNIT    =   $0301
DCOMND   =   $0302
DSTATS   =   $0303
DBUFLO   =   $0304
DBUFHI   =   $0305
DTIMLO   =   $0306
DBYTLO   =   $0308
DBYTHI   =   $0309
DAUX1    =   $030A
DAUX2    =   $030B
ICCOM0   =   $0342      ; IOCB 0, E:
ICBAL0   =   $0344
ICBAH0   =   $0345
ICBLL0   =   $0348
ICBLH0   =   $0349
IOCB     =   $50        ; IOCB 5, for the disks
ICCOM    =   $0392
ICBAL    =   $0394
ICBAH    =   $0395
ICBLL    =   $0398
ICBLH    =   $0399
ICAX1    =   $039A
ICAX2    =   $039B
COLOR1   =   $02C5
COLOR2   =   $02C6
COLOR4   =   $02C8
HELPFG   =   $02DC
RUNAD    =   $02E0
INITAD   =   $02E2
MEMTOP   =   $02E5
MEMLO    =   $02E7
CRSINH   =   $02F0
CHBAS    =   $02F4
CH       =   $02FC
PAL      =   $D014
KEYBDV   =   $E420
CIOV     =   $E456
SIOV     =   $E459
;
; The zero page: $82 up, free once DOS has started a program
;
PTR      =   $82        ; pointers
PTR2     =   $84
PTR3     =   $86
SBP      =   $88        ; where the string being built goes on
SCRP     =   $8A        ; the screen row being drawn in
NUM      =   $8C        ; 32-bit numbers: NUM and REM in a row
REM      =   $90        ; (DIV32 shifts them as one)
NUM2     =   $94
DVT      =   $A7        ; 4 bytes, for DIV32
PCX      =   $AB        ; PUTCH keeps the registers here
PCY      =   $AC
PCA      =   $AD
EDS      =   $AE        ; the string EDIT edits
SITEP    =   $B0        ; a site
SROW     =   $98        ; where drawing goes
SCOL     =   $99
SINV     =   $9A        ; $80: in inverse
SW       =   $9B        ; a width, for PUTW and REP
TMP      =   $9C
TMP2     =   $9D
TMP3     =   $9E
TMP4     =   $9F
ARGP     =   $A0        ; an FTP command's argument; high byte 0: none
K        =   $A2        ; an entry
SIDE     =   $A3        ; the pane worked on (PUSE)
BASE     =   $A4        ; its first entry
ACTIVE   =   $A5        ; the pane with the keyboard
CONN     =   $A6        ; the FujiNet connection: 0 N1:, 1 N2:
;
; Characters the screen draws (ATASCII)
;
CHHLINE  =   $12
CHVLINE  =   $7C
CHTL     =   $11
CHTR     =   $05
CHBL     =   $1A
CHBR     =   $03
CHLT     =   $01
CHRT     =   $04
CHTT     =   $17
CHBT     =   $18
CHDOT    =   $14        ; connected
CHMARK   =   $60        ; a marked file
CHUP     =   $1C
CHDOWN   =   $1D
CHFOLDER =   $00        ; EFTP_XL's own (tools/mkfont.py)
CHFILE   =   $10
CHMORE   =   $06
CHSHADE  =   $7B
;
; Keys
;
KRETURN  =   $9B
KESC     =   $1B
KBKSP    =   $7E
KTAB     =   $7F
KUP      =   $1C
KDOWN    =   $1D
KLEFT    =   $1E
KRIGHT   =   $1F
KDEL     =   $9C        ; Shift+Delete
KDEL2    =   $FE        ; Ctrl+Delete
KHELP    =   $FF
EOL      =   $9B
;
; The panes
;
LOCAL    =   0
REMOTE   =   1
MAXE     =   64         ; entries in a pane
NE       =   128        ; both; entry NE is spare, for sorting
EUP      =   $01        ; an entry's flags: ".."
EDIR     =   $02
EMARK    =   $04
EDONE    =   $10
EFAIL    =   $20
ESKIP    =   $40
PATHLEN  =   80
NO       =   $FF
;
; The screen
;
SCRL     =   1          ; columns 1..38
SCRR     =   38
SCRW     =   38
DIV      =   19         ; the line between the panes
HEADROW  =   3
CNTROW   =   4
LISTROW  =   5
VIS      =   11         ; files shown in a pane
DETROW   =   17
XROW     =   18         ; the transfers
XROWS    =   3
NAMEW    =   DIV-SCRL-6
;
; FTP's errors: carry set, A one of these
;
EOPEN    =   1          ; could not open the TCP connection
ETIME    =   2          ; no answer in time
ECLOSED  =   3          ; the connection closed
EREPLY   =   4          ; the server said no (FTPMSG has why)
;
MODEBIN  =   0          ; a site's Files
MODETEXT =   1
MODETYPE =   2
MAXSITES =   8
