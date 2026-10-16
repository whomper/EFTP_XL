;
; EFTP_XL - the variables: after the program, not in the file; START
; sets them all to 0
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
BSS      =   *
;
; the screen and text
;
OCHBAS   *=  *+1        ; DOS's font and colours
OCOL1    *=  *+1
OCOL2    *=  *+1
OCOL4    *=  *+1
ROWLO    *=  *+24       ; where each row is
ROWHI    *=  *+24
IRET     *=  *+2
SUNIT    *=  *+1
EDLEN    *=  *+1
EDCOL    *=  *+1
EDCUR    *=  *+1
EDMAX    *=  *+1
EDMASK   *=  *+1
;
; the Atari's disks
;
SPARTA   *=  *+1        ; the listing is SpartaDOS's
LEXT     *=  *+1
CGOT     *=  *+2
XLEN     *=  *+2
WCNT     *=  *+1
WLO      *=  *+9        ; the words of a line
WHI      *=  *+9
LNAMEB   *=  *+13
LLINE    *=  *+64
FSPEC    *=  *+96       ; a file on the Atari: "D1:>GAMES>DIGDUG.XEX"
;
; the panes
;
ENL      *=  *+NE+1     ; the entries: name, size, flags, date
ENH      *=  *+NE+1
ES0      *=  *+NE+1
ES1      *=  *+NE+1
ES2      *=  *+NE+1
ES3      *=  *+NE+1
EFLAG    *=  *+NE+1
EDAY     *=  *+NE+1
EMON     *=  *+NE+1
EYEAR    *=  *+NE+1     ; NO: the time is known instead
EHOUR    *=  *+NE+1     ; NO: it isn't
EMIN     *=  *+NE+1
PCOUNT   *=  *+2        ; the panes
PTOP     *=  *+2
PCUR     *=  *+2
PDIRS    *=  *+2
PFILES   *=  *+2
PFULL    *=  *+2
PUSEDL   *=  *+2
PUSEDH   *=  *+2
NSIZE    *=  *+4        ; the next entry's
NFLAGS   *=  *+1
NDAY     *=  *+1
NMON     *=  *+1
NYEAR    *=  *+1
NHOUR    *=  *+1
NMIN     *=  *+1
PSI      *=  *+1
PSJ      *=  *+1
PSEND    *=  *+1
STK      *=  *+1
PATH0    *=  *+PATHLEN  ; "D1:" or "D1:>GAMES>"
PATH1    *=  *+PATHLEN  ; the server's
POOL0    *=  *+1024     ; the names
POOL1    *=  *+1280
;
; FTP
;
NSTAT    *=  *+4
NBUF     *=  *+2
NLEN     *=  *+2
CPOS     *=  *+2
CLEN     *=  *+2
CBUF0    *=  *+128
CBUF1    *=  *+128
T0       *=  *+2
TOUT     *=  *+2
GMAX     *=  *+1
GLEN     *=  *+1
RCHI     *=  *+1
RCLO     *=  *+1
PHI      *=  *+1
PCOMMA   *=  *+1
DVERB    *=  *+2
DARG     *=  *+2
FTPMSG   *=  *+80       ; the server's last reply
FLINE    *=  *+160
CMDB     *=  *+168
HOST     *=  *+64
DPORT    *=  *+8
PASSW    *=  *+20
MW       *=  *+3
BUF      *=  *+512      ; a file's blocks
SPEC     =   BUF        ; FujiNet's 256-byte N: spec
;
; the main screen
;
SAVESP   *=  *+1
KEY      *=  *+1
SITE     *=  *+1
CONNECTD *=  *+1
MSG      *=  *+100
UTMP     *=  *+PATHLEN
SIZEB    *=  *+8
DEI      *=  *+1
DEK      *=  *+1
DEF      *=  *+1
DLI      *=  *+1
MCNT     *=  *+1
MSIZE    *=  *+4
CURK     *=  *+1
DPS      *=  *+1
DPC      *=  *+1
DPW      *=  *+1
DPP      *=  *+2
FERR     *=  *+1
RRS      *=  *+1
ASKQ     *=  *+2
ASKB     *=  *+2
AFLG     *=  *+1
DLK      *=  *+1
DLEND    *=  *+1
MVI      *=  *+1
MVOLD    *=  *+1
MVTOP    *=  *+1
GUOFF    *=  *+1
MKALL    *=  *+1
MKANY    *=  *+1
JKEY     *=  *+1
JN       *=  *+1
JI       *=  *+1
JJ       *=  *+1
HROW     *=  *+1
XONLY    *=  *+1
;
; the transfers
;
XDOWN    *=  *+1
XMODE    *=  *+1
XTEXT    *=  *+1
XCOUNT   *=  *+1
XCUR     *=  *+1
XFIRST   *=  *+1
XSTOP    *=  *+1
XOK      *=  *+1
XRES     *=  *+1
XSECS    *=  *+1
XMINS    *=  *+2
XST      *=  *+1
XN       *=  *+2
XCNT     *=  *+2
TDONE    *=  *+4
XT0      *=  *+4
XT       *=  *+4
FSIZEB   *=  *+4
FDONEB   *=  *+4
ADOT     *=  *+1
DRI      *=  *+1
DRJ      *=  *+1
DRF      *=  *+1
DRFILL   *=  *+1
DQR      *=  *+1
MRN      *=  *+2
EXTB     *=  *+8
ANAME    *=  *+14
XQUEUE   *=  *+MAXE
XQST     *=  *+MAXE     ; how each went: EDONE, EFAIL, ESKIP
XNF      *=  *+1        ; files tried
XWALK    *=  *+1        ; in a folder (XTREE)
XTFAIL   *=  *+1
XDEPTH   *=  *+1
XIDX     *=  *+XDEEP    ; where the walk is, in each folder down
XFN      *=  *+96
XLINE    *=  *+48
XERROR   *=  *+40
SUMMARY  *=  *+40
;
; the sites
;
SCOUNT   *=  *+1
SFI      *=  *+1
SSI      *=  *+1
SMD      *=  *+1
SMI      *=  *+1
SHS      *=  *+1
SCUR     *=  *+1
SCUR2    *=  *+1
SLI      *=  *+1
SEDI     *=  *+1
SLINE    *=  *+200
SCOPY    *=  *+SITESZ
SITES    *=  *+SITESZ*MAXSITES
;
BSSEND   =   *
