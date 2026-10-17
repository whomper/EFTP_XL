;
; XTREE.M65 - EFTP_XL 0.9
; Folder transfers, depth first
; Copyright (C) 2026 AERA | Erez Yaary
;
XDEEP    =   8          ; max folder depth
;
; XTREE - send folder K and all in it
; to the other pane's side
; Exit: A=EDONE, or EFAIL if any
;       part of it failed
;
XTREE    LDX #1             ; save both cursors
XTREEC   LDA PCUR,X
         STA XCURS,X
         LDA PTOP,X
         STA XTOPS,X
         DEX
         BPL XTREEC
         LDA #0
         STA XTFAIL
         STA XDEPTH
         STA XIDX
         LDX #3             ; clear the totals
XTREE0   STA FSIZEB,X
         STA FDONEB,X
         DEX
         BPL XTREE0
         LDX K
         JSR XFOLDER        ; into the top folder
         BCC XTREE0A
         JMP XTREE8
XTREE0A  LDA #1
         STA XWALK
XTREE1   LDA XSTOP          ; ESC: back up and out
         BNE XTREE5
         LDA XDOWN          ; source pane
         JSR PUSE
         LDX XDEPTH
         LDA XIDX,X         ; next entry here
         LDY SIDE
         CMP PCOUNT,Y
         BCS XTREE5         ; folder done
         INC XIDX,X
         CLC
         ADC BASE
         STA K
         TAX
         LDA EFLAG,X
         AND #EUP           ; skip ".."
         BNE XTREE1
         LDA EFLAG,X
         AND #EDIR
         BEQ XTREE3
         LDA XDEPTH         ; folder: go in
         CMP #XDEEP-1
         BCS XTREE2         ; too deep
         JSR XFOLDER
         BCS XTREE2
         INC XDEPTH
         LDX XDEPTH
         LDA #0
         STA XIDX,X
         JMP XTREE1
XTREE2   INC XTFAIL
         JMP XTREE1
XTREE3   JSR XFILE          ; file: send it
         CMP #EFAIL
         BNE XTREE1
         INC XTFAIL
         JMP XTREE1
XTREE5   JSR XUP            ; up one level
         DEC XDEPTH
         BPL XTREE1
         LDA #0
         STA XWALK
         LDX #1             ; restore cursors
XTREE6   LDA XCURS,X
         STA PCUR,X
         LDA XTOPS,X
         STA PTOP,X
         DEX
         BPL XTREE6
         LDA XTFAIL
         BNE XTREE8
         LDA #EDONE
         RTS
XTREE8   LDA #EFAIL
         RTS
;
; XFOLDER - enter folder X of the
; source pane on both sides, making
; it on the other side first; reads
; both panes again
; Exit: C=1 failed (XERROR says why),
;       nothing changed
;
XFOLDER  JSR ENAME          ; XFN = its name
         LDX #<XFN
         STX PTR2
         LDX #>XFN
         STX PTR2+1
         JSR STRCPY
         LDA XDOWN
         BNE XFOLD3
;
; Atari to server: MKD, then CWD
;
         LDA #<XFN
         STA ARGP
         LDA #>XFN
         STA ARGP+1
         LDA #<VMKD
         LDY #>VMKD
         JSR FDO
         BCC XFOLD1
         CMP #EREPLY        ; exists: go in
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
; Server to Atari: XIO 42 (MKDIR)
; with an 8.3 name, then CWD
;
XFOLD3   LDA #<XFN
         LDY #>XFN
         JSR ANAMES         ; ANAME = 8.3 name
         LDA #<ANAME
         LDY #>ANAME
         JSR LSPECN
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #42
         JSR CXIO
         BCC XFOLD4         ; any other error:
         CMP #146           ; exists, go in
         BNE XFOLD4
         STA XST            ; 146: no folders
         JMP SAYCIO1        ; (DOS 2.5)
XFOLD4   LDA #<XFN
         LDY #>XFN
         JSR FCWD
         BCS XFOLD2
         LDA #<ANAME
         LDY #>ANAME
         JSR LINTO
;
; Read both sides; back up if
; either can't be read
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
; XUP - both sides up one folder,
; and read again
;
XUP      JSR LUP
         LDA #<DOTDOT       ; CWD ..
         LDY #>DOTDOT
         JSR FCWD
         JSR LREAD
         JMP RREAD
;
; SAYCIO1 - report CIO error XST
; Exit: C=1
;
SAYCIO1  JSR SAYCIO
         SEC
         RTS
;
; LSPECN0 - FSPEC = current Atari
; folder, for SAYCIO
;
LSPECN0  LDA #<NOTHING
         LDY #>NOTHING
         JMP LSPECN
