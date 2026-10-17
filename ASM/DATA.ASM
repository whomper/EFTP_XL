;
; DATA.M65 - EFTP_XL 0.9
; The variables
; Copyright (C) 2026 AERA | Erez Yaary
;
; After the program and not in the
; file; START zeroes them all
;
BSS      =   *
;
; Screen and text
;
OCHBAS   *=  *+1        ; DOS's font, colours
OCOL1    *=  *+1
OCOL2    *=  *+1
OCOL4    *=  *+1
ROWLO    *=  *+24       ; each row's address
ROWHI    *=  *+24
IRET     *=  *+2        ; INLINE's return
SUNIT    *=  *+1        ; SBSIZE: K, M or 0
EDLEN    *=  *+1        ; EDIT: length,
EDCOL    *=  *+1        ; first column,
EDCUR    *=  *+1        ; cursor,
EDMAX    *=  *+1        ; room with the 0,
EDMASK   *=  *+1        ; not 0: show *s
;
; The Atari's disks
;
SPARTA   *=  *+1        ; SpartaDOS listing
LEXT     *=  *+1        ; LNAME adds the ext
CGOT     *=  *+2        ; CREAD: bytes read
XLEN     *=  *+2        ; bytes to write
WCNT     *=  *+1        ; a line's words:
WLO      *=  *+9        ; how many, where
WHI      *=  *+9
LNAMEB   *=  *+13       ; "NAME.EXT"
LLINE    *=  *+64       ; a listing line
FSPEC    *=  *+96       ; "D1:>GAMES>DIGDUG.XEX"
;
; The panes. Entry fields, by entry:
; Atari 0..63, server 64..127, 128
; spare for sorting
;
ENL      *=  *+NE+1     ; name
ENH      *=  *+NE+1
ES0      *=  *+NE+1     ; size, ES0 low
ES1      *=  *+NE+1
ES2      *=  *+NE+1
ES3      *=  *+NE+1
EFLAG    *=  *+NE+1     ; EUP EDIR EMARK ...
EDAY     *=  *+NE+1     ; 0: no date
EMON     *=  *+NE+1
EYEAR    *=  *+NE+1     ; NO: time instead
EHOUR    *=  *+NE+1     ; NO: no time
EMIN     *=  *+NE+1
;
; Each pane's own, by SIDE
;
PCOUNT   *=  *+2        ; entries
PTOP     *=  *+2        ; first one shown
PCUR     *=  *+2        ; the cursor
PDIRS    *=  *+2
PFILES   *=  *+2
PFULL    *=  *+2        ; some left out
PUSEDL   *=  *+2        ; name pool used
PUSEDH   *=  *+2
NSIZE    *=  *+4        ; the next entry's
NFLAGS   *=  *+1        ; (for PADD)
NDAY     *=  *+1
NMON     *=  *+1
NYEAR    *=  *+1
NHOUR    *=  *+1
NMIN     *=  *+1
PSI      *=  *+1        ; PSORT
PSJ      *=  *+1
PSEND    *=  *+1
STK      *=  *+1        ; SBSTAMP's X
PATH0    *=  *+PATHLEN  ; "D1:" or "D1:>GAMES>"
PATH1    *=  *+PATHLEN  ; the server's
POOL0    *=  *+1024     ; the names
POOL1    *=  *+1280
;
; FTP and FujiNet
;
NSTAT    *=  *+4        ; N: status
NBUF     *=  *+2        ; SIO buffer
NLEN     *=  *+2        ; and its length
CPOS     *=  *+2        ; by CONN: next byte
CLEN     *=  *+2        ; and bytes in CBUF
CBUF0    *=  *+128      ; N1: control
CBUF1    *=  *+128      ; N2: data
T0       *=  *+2        ; clock at TSTART
TOUT     *=  *+2        ; timeout, ticks
GMAX     *=  *+1        ; GETS
GLEN     *=  *+1
RCHI     *=  *+1        ; reply code: 1st
RCLO     *=  *+1        ; digit, the others
PHI      *=  *+1        ; PASV
PCOMMA   *=  *+1
DVERB    *=  *+2        ; DOPEN's command
DARG     *=  *+2        ; and its argument
FTPMSG   *=  *+80       ; server's last reply
FLINE    *=  *+160      ; a reply line
CMDB     *=  *+168      ; the command sent
HOST     *=  *+64
DPORT    *=  *+8        ; data port, digits
PASSW    *=  *+20
MW       *=  *+3        ; a listing's month
BUF      *=  *+512      ; a file's blocks
SPEC     =   BUF        ; N: spec, 256 bytes
;
; The main screen and its commands
;
SAVESP   *=  *+1        ; stack, for ^Q
KEY      *=  *+1
SITE     *=  *+1        ; the site; NO: none
CONNECTD *=  *+1        ; not 0: connected
MSG      *=  *+100      ; a line being built
UTMP     *=  *+PATHLEN  ; a name, to edit
SIZEB    *=  *+8        ; "244K"
DEI      *=  *+1        ; DENTRY
DEK      *=  *+1
DEF      *=  *+1
DLI      *=  *+1        ; DLIST
MCNT     *=  *+1        ; MARKED: how many,
MSIZE    *=  *+4        ; their size
CURK     *=  *+1        ; CURENT's entry
DPS      *=  *+1        ; DPANE: side,
DPC      *=  *+1        ; column,
DPW      *=  *+1        ; width,
DPP      *=  *+2        ; the path shown
FERR     *=  *+1        ; CIO or FTP error
RRS      *=  *+1        ; REREAD's side
ASKQ     *=  *+2        ; ASK: question,
ASKB     *=  *+2        ; string edited
AFLG     *=  *+1        ; AFTERI's flags
DLK      *=  *+1        ; DELETE
DLEND    *=  *+1
MVI      *=  *+1        ; MOVETO
MVOLD    *=  *+1
MVTOP    *=  *+1
GUOFF    *=  *+1        ; GOUP
MKALL    *=  *+1        ; MARK
MKANY    *=  *+1
JKEY     *=  *+1        ; JUMP
JN       *=  *+1
JI       *=  *+1
JJ       *=  *+1
HROW     *=  *+1        ; HELP
XONLY    *=  *+1        ; SENDF: cursor only
;
; The transfers
;
XDOWN    *=  *+1        ; 1: to the Atari
XMODE    *=  *+1        ; the site's Files
XTEXT    *=  *+1        ; this one is text
XCOUNT   *=  *+1        ; in XQUEUE
XCUR     *=  *+1        ; the one going
XFIRST   *=  *+1        ; first row shown
XSTOP    *=  *+1        ; ESC: stop
XOK      *=  *+1        ; files sent
XRES     *=  *+1
XSECS    *=  *+1        ; time taken
XMINS    *=  *+2
XST      *=  *+1        ; CIO status
XN       *=  *+2        ; bytes in a block
XCNT     *=  *+2        ; bytes left in BUF
TDONE    *=  *+4        ; bytes in all
XT0      *=  *+4        ; clock at the start
XT       *=  *+4        ; ticks taken
FSIZEB   *=  *+4        ; the file's size
FDONEB   *=  *+4        ; and bytes done
ADOT     *=  *+1        ; LASTDOT
DRI      *=  *+1        ; DROW
DRJ      *=  *+1
DRF      *=  *+1
DRFILL   *=  *+1
DQR      *=  *+1        ; DQUEUE's row
MRN      *=  *+2        ; MAYREP's name
EXTB     *=  *+8        ; " EXT " for ISTEXT
ANAME    *=  *+14       ; an 8.3 name, DOS
XQUEUE   *=  *+MAXE     ; the entries to send
XQST     *=  *+MAXE     ; EDONE, EFAIL, ESKIP
XNF      *=  *+1        ; files tried
XWALK    *=  *+1        ; in a folder (XTREE)
XTFAIL   *=  *+1        ; XTREE: failures,
XDEPTH   *=  *+1        ; depth now
XIDX     *=  *+XDEEP    ; next entry, by depth
XFN      *=  *+96       ; XTREE folder name
XCURS    *=  *+2        ; the cursors before
XTOPS    *=  *+2        ; a folder went
XLINE    *=  *+48       ; a transfer's line
XERROR   *=  *+40       ; why it failed
SUMMARY  *=  *+40       ; "2 of 3 files, ..."
;
; The sites
;
SCOUNT   *=  *+1        ; how many
SFI      *=  *+1        ; a field, by number
SSI      *=  *+1        ; SSAVE's site
SMD      *=  *+1        ; SHMODE
SMI      *=  *+1
SHS      *=  *+1        ; SHFLD
SCUR     *=  *+1        ; Sites cursor
SCUR2    *=  *+1        ; SHLIST
SLI      *=  *+1
SEDI     *=  *+1        ; SEDIT's site
SLINE    *=  *+200      ; a line of EFTPXL.CFG
SCOPY    *=  *+SITESZ   ; the site edited
SITES    *=  *+SITESZ*MAXSITES
;
BSSEND   =   *
