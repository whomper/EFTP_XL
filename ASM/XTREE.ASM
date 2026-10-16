;
; EFTP_XL - sending a folder, with all in it
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; The folder is walked depth first with the two panes: the source pane
; holds the folder being walked, the other pane the same folder on the
; other side (so a file already there is asked about, as at the top).
; Going into a folder makes it on the other side (one already there is
; gone into), then both sides go into it and are read; coming back up
; reads both again and the walk goes on from where it was in the
; folder above (XIDX, by depth). Going to the Atari, a folder gets an
; 8.3 name, as files do; DOS 2.5 has no folders, so it fails there.
;
XDEEP    =   8          ; folders in folders at most
;
; XTREE: folder K, with all in it, to the other side; A: EDONE, or
; EFAIL when any of it failed
;
XTREE    LDA #0
         STA XTFAIL
         STA XDEPTH
         STA XIDX
         LDX #3
XTREE0   STA FSIZEB,X
         STA FDONEB,X
         DEX
         BPL XTREE0
         LDX K
         JSR XFOLDER
         BCS XTREE8
         LDA #1
         STA XWALK
XTREE1   LDA XSTOP          ; ESC: back up and out
         BNE XTREE5
         LDA XDOWN          ; the source: the server going down
         JSR PUSE
         LDX XDEPTH
         LDA XIDX,X
         LDY SIDE
         CMP PCOUNT,Y
         BCS XTREE5         ; all of this folder done
         INC XIDX,X
         CLC
         ADC BASE
         STA K
         TAX
         LDA EFLAG,X
         AND #EUP
         BNE XTREE1
         LDA EFLAG,X
         AND #EDIR
         BEQ XTREE3
         LDA XDEPTH         ; a folder: into it
         CMP #XDEEP-1
         BCS XTREE2
         JSR XFOLDER
         BCS XTREE2
         INC XDEPTH
         LDX XDEPTH
         LDA #0
         STA XIDX,X
         JMP XTREE1
XTREE2   INC XTFAIL
         JMP XTREE1
XTREE3   JSR XFILE          ; a file
         CMP #EFAIL
         BNE XTREE1
         INC XTFAIL
         JMP XTREE1
XTREE5   JSR XUP
         DEC XDEPTH
         BPL XTREE1
         LDA #0
         STA XWALK
         LDA XTFAIL
         BNE XTREE8
         LDA #EDONE
         RTS
XTREE8   LDA #EFAIL
         RTS
;
; XFOLDER: into folder X (of the source pane) on both sides, made on
; the other side first; both panes read. The carry set when it failed
; (and XERROR says why); then nothing has changed.
;
XFOLDER  JSR ENAME
         LDX #<XFN
         STX PTR2
         LDX #>XFN
         STX PTR2+1
         JSR STRCPY
         LDA XDOWN
         BNE XFOLD3
;
; up: the Atari's folder XFN to the server
;
         LDA #<XFN
         STA ARGP
         LDA #>XFN
         STA ARGP+1
         LDA #<VMKD
         LDY #>VMKD
         JSR FDO            ; there already: it is gone into
         BCC XFOLD1
         CMP #EREPLY
         BNE XFOLD2
XFOLD1   LDA #<XFN
         LDY #>XFN
         JSR FCWD
         BCS XFOLD2
         LDA #<XFN
         LDY #>XFN
         JSR LINTO
         JMP XFOLD5
XFOLD2   STA FERR
         JSR XERRI
         .BYTE "Folder",0
         SEC
         RTS
;
; down: the server's folder XFN to the Atari, as ANAME
;
XFOLD3   LDA #<XFN
         LDY #>XFN
         JSR ANAMES
         LDA #<ANAME
         LDY #>ANAME
         JSR LSPECN
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #42
         JSR CXIO           ; there already: it is gone into
         BCC XFOLD4
         CMP #146           ; this DOS has no folders
         BNE XFOLD4
         STA XST
         JMP SAYCIO1
XFOLD4   LDA #<XFN
         LDY #>XFN
         JSR FCWD
         BCS XFOLD2
         LDA #<ANAME
         LDY #>ANAME
         JSR LINTO
;
; both: read both sides there; if one can't be read, back up
;
XFOLD5   JSR LREAD
         BCS XFOLD6
         JSR RREAD
         BCS XFOLD7
         CLC
         RTS
XFOLD6   STA XST
         JSR LSPECN0
         JSR SAYCIO
         JMP XFOLD8
XFOLD7   STA FERR
         JSR XERRI
         .BYTE "List",0
XFOLD8   JSR XUP
         SEC
         RTS
;
; XUP: both sides back up to the folder above, and read again
;
XUP      JSR LUP
         LDA #<DOTDOT
         LDY #>DOTDOT
         JSR FCWD
         JSR LREAD
         JMP RREAD
;
; SAYCIO1: XERROR why the folder can't be made (XST), and the carry set
;
SAYCIO1  JSR SAYCIO
         SEC
         RTS
;
; LSPECN0: FSPEC = the Atari's folder, for SAYCIO
;
LSPECN0  LDA #<NOTHING
         LDY #>NOTHING
         JMP LSPECN
