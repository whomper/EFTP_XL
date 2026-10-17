;
; EQUATES.M65 - EFTP_XL 1.1
; OS addresses, zero page, constants
; Copyright (C) 2026 AERA | Erez Yaary
;
; The OS
;
DOSVEC   =   $0A
RTCLOK   =   $12        ; $14 is the low byte
ICAX1Z   =   $2A        ; AUX1 for a handler
ATRACT   =   $4D        ; colour-shift timer
SAVMSC   =   $58        ; screen memory
;
; SIO block
;
DDEVIC   =   $0300
DUNIT    =   $0301
DCOMND   =   $0302
DSTATS   =   $0303
DBUFLO   =   $0304
DBUFHI   =   $0305
DTIMLO   =   $0306      ; timeout, about 1 s
DBYTLO   =   $0308
DBYTHI   =   $0309
DAUX1    =   $030A
DAUX2    =   $030B
;
; IOCBs
;
ICCOM0   =   $0342      ; IOCB 0, E:
ICBAL0   =   $0344
ICBAH0   =   $0345
ICBLL0   =   $0348
ICBLH0   =   $0349
IOCB     =   $50        ; IOCB 5, the disks
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
HELPFG   =   $02DC      ; HELP pressed
RUNAD    =   $02E0
INITAD   =   $02E2
MEMTOP   =   $02E5
MEMLO    =   $02E7
CRSINH   =   $02F0      ; 1: no cursor
CHBAS    =   $02F4      ; font, its page
CH       =   $02FC      ; key; $FF none
PAL      =   $D014      ; bits 1-3 0: PAL
KEYBDV   =   $E420      ; K: handler table
CIOV     =   $E456
SIOV     =   $E459
;
; Zero page: $82 up, free once DOS
; has started a program
;
PTR      =   $82        ; pointers
PTR2     =   $84
PTR3     =   $86
SBP      =   $88        ; string being built
SCRP     =   $8A        ; row being drawn
NUM      =   $8C        ; 32-bit numbers
REM      =   $90        ; (DIV32: NUM, REM
NUM2     =   $94        ; shift as one)
DVT      =   $A7        ; 4 bytes, DIV32
PCX      =   $AB        ; PUTCH saves regs
PCY      =   $AC
PCA      =   $AD
EDS      =   $AE        ; string EDIT edits
SITEP    =   $B0        ; a site
SROW     =   $98        ; where drawing goes
SCOL     =   $99
SINV     =   $9A        ; $80: inverse
SW       =   $9B        ; width, PUTW, REP
TMP      =   $9C
TMP2     =   $9D
TMP3     =   $9E
TMP4     =   $9F
ARGP     =   $A0        ; FTP arg; hi 0: none
K        =   $A2        ; an entry
SIDE     =   $A3        ; pane worked on
BASE     =   $A4        ; its first entry
ACTIVE   =   $A5        ; pane with the keys
CONN     =   $A6        ; 0 N1:, 1 N2:
;
; Screen characters (ATASCII)
;
CHHLINE  =   $12        ; box lines
CHVLINE  =   $7C
CHTL     =   $11        ; corners
CHTR     =   $05
CHBL     =   $1A
CHBR     =   $03
CHLT     =   $01        ; tees
CHRT     =   $04
CHTT     =   $17
CHBT     =   $18
CHDOT    =   $14        ; connected
CHMARK   =   $60        ; a marked file
CHUP     =   $1C        ; arrows
CHDOWN   =   $1D
CHFOLDER =   $00        ; own (mkfont.py)
CHFILE   =   $10
CHMORE   =   $06        ; name cut short
CHSHADE  =   $7B        ; bar fill
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
; Panes
;
LOCAL    =   0
REMOTE   =   1
MAXE     =   64         ; entries a pane
NE       =   128        ; both; NE: sort spare
EUP      =   $01        ; entry flags: ".."
EDIR     =   $02
EMARK    =   $04
EDONE    =   $10        ; how a transfer went
EFAIL    =   $20
ESKIP    =   $40
PATHLEN  =   80
NO       =   $FF        ; none
;
; Screen
;
SCRL     =   1          ; columns 1..38
SCRR     =   38
SCRW     =   38
DIV      =   19         ; line between panes
HEADROW  =   3
CNTROW   =   4
LISTROW  =   5
VIS      =   11         ; files in a pane
DETROW   =   17
XROW     =   18         ; the transfers
XROWS    =   3
NAMEW    =   DIV-SCRL-6
;
; FTP errors: C=1, A one of these
;
EOPEN    =   1          ; no TCP connection
ETIME    =   2          ; no answer in time
ECLOSED  =   3          ; connection closed
EREPLY   =   4          ; server said no
;
MODEBIN  =   0          ; site's Files: binary
MODETEXT =   1          ; text
MODETYPE =   2          ; by extension
MAXSITES =   8
