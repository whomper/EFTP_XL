;
; EFTP_XL - the sites
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; D:EFTPXL.CFG has a line for each site, its fields separated by '|':
;   name|host|port|user|password|server folder|Atari folder|mode
; D: is the drive (and on SpartaDOS the folder) EFTP_XL was run from.
;
; A site is SITESZ bytes: its text fields at FOFF (FSIZE long, the 0
; in them), then the mode (MODEBIN, MODETEXT, MODETYPE).
;
SITESZ   =   159
SMODE    =   158
SLROW    =   4          ; the list
SEPROW   =   SLROW+MAXSITES
FROW     =   SEPROW+1   ; the fields
LABCOL   =   SCRL+2
VALCOL   =   SCRL+13
VALW     =   SCRR-VALCOL
;
FOFF     .BYTE 0,16,48,54,74,94,134
FSIZE    .BYTE 16,32,6,20,20,40,24
SITEL    .BYTE <SITES,<[SITES+SITESZ],<[SITES+SITESZ*2]
         .BYTE <[SITES+SITESZ*3],<[SITES+SITESZ*4],<[SITES+SITESZ*5]
         .BYTE <[SITES+SITESZ*6],<[SITES+SITESZ*7]
SITEH    .BYTE >SITES,>[SITES+SITESZ],>[SITES+SITESZ*2]
         .BYTE >[SITES+SITESZ*3],>[SITES+SITESZ*4],>[SITES+SITESZ*5]
         .BYTE >[SITES+SITESZ*6],>[SITES+SITESZ*7]
;
; SSEL: SITEP = site X; SFIELD: A/Y = field X of it
;
SSEL     LDA SITEL,X
         STA SITEP
         LDA SITEH,X
         STA SITEP+1
         RTS
SFIELD   LDA FOFF,X
         CLC
         ADC SITEP
         PHA
         LDA SITEP+1
         ADC #0
         TAY
         PLA
         RTS
;
; SCLEAR: site X all 0
;
SCLEAR   JSR SSEL
         LDY #0
         TYA
SCLEAR1  STA (SITEP),Y
         INY
         CPY #SITESZ
         BNE SCLEAR1
         RTS
;
SLOAD    LDA #0
         STA SCOUNT
         LDA #<CFG
         LDY #>CFG
         LDX #4
         JSR COPEN
         BCS SLOAD9
SLOAD1   LDA SCOUNT
         CMP #MAXSITES
         BEQ SLOAD9
         LDA #<SLINE
         LDY #>SLINE
         LDX #200
         JSR CGETLN
         BCS SLOAD9
         LDA SLINE
         BEQ SLOAD1
         LDX SCOUNT
         JSR SCLEAR
         INC SCOUNT
         LDA #<SLINE
         STA PTR
         LDA #>SLINE
         STA PTR+1
         LDA #0
         STA SFI
SLOAD2   LDX SFI
         CPX #7
         BEQ SLOAD6
         LDA FOFF,X
         STA TMP
         LDA FSIZE,X
         STA TMP2
         DEC TMP2           ; with room for its 0
SLOAD3   LDY #0
         LDA (PTR),Y
         BEQ SLOAD1
         CMP #'|
         BEQ SLOAD5
         LDX TMP2
         BEQ SLOAD4
         DEC TMP2
         LDY TMP
         STA (SITEP),Y
         INC TMP
SLOAD4   JSR INCPTR
         JMP SLOAD3
SLOAD5   JSR INCPTR
         INC SFI
         JMP SLOAD2
SLOAD6   LDY #0
         LDA (PTR),Y
         AND #$0F
         CMP #MODETYPE+1
         BCC SLOAD7
         LDA #MODEBIN
SLOAD7   LDY #SMODE
         STA (SITEP),Y
         JMP SLOAD1
SLOAD9   JMP CCLOSE
;
; SSAVE: the sites into the file; the carry set when it failed (A why)
;
SSAVE    LDA #<CFG
         LDY #>CFG
         LDX #8
         JSR COPEN
         BCS SSAVE4
         LDA #0
         STA SSI
SSAVE1   LDA SSI
         CMP SCOUNT
         BCS SSAVE3
         TAX
         JSR SSEL
         LDA #<SLINE
         LDY #>SLINE
         JSR SBSTART
         LDA #0
         STA SFI
SSAVE2   LDX SFI
         JSR SFIELD
         JSR SBADD
         LDA #'|
         JSR SBCH
         INC SFI
         LDA SFI
         CMP #7
         BNE SSAVE2
         LDY #SMODE
         LDA (SITEP),Y
         ORA #'0
         JSR SBCH
         LDA #<SLINE
         LDY #>SLINE
         JSR CPUTLN
         BCS SSAVE4
         INC SSI
         JMP SSAVE1
SSAVE3   JMP CCLOSE
SSAVE4   PHA
         JSR CCLOSE
         PLA
         SEC
         RTS
;
SSAVEUI  JSR SSAVE
         BCC SSAVEU1
         STA FERR
         JSR MSGSTART
         JSR SBI
         .BYTE "Could not save ",0
         LDA #<CFG
         LDY #>CFG
         JSR SBADD
         JSR SBI
         .BYTE ": error ",0
         LDA FERR
         JSR SBBYTE
         JSR INFOMSG
         JSR KEYGET
SSAVEU1  RTS
;
; SHMODE: the mode A, in inverse among the three
;
SHMODE   STA SMD
         LDX #FROW+7
         LDY #VALCOL
         JSR AT
         LDA #<MODES
         STA PTR3
         LDA #>MODES
         STA PTR3+1
         LDA #0
         STA SMI
SHMODE1  LDA SMI
         CMP SMD
         BNE SHMODE2
         JSR INVON
SHMODE2  JSR KEYB2
         JSR INVOFF
         INC SCOL
         INC SMI
         LDA SMI
         CMP #3
         BNE SHMODE1
         RTS
;
; SHFLD: the fields of the site at SITEP (A not 0), or blank (A 0)
;
SHFLD    STA SHS
         LDA #<LABELS
         STA PTR3
         LDA #>LABELS
         STA PTR3+1
         LDA #0
         STA SFI
SHFLD1   LDA SFI
         CLC
         ADC #FROW
         TAX
         LDY #LABCOL
         JSR AT
         LDA #10
         STA SW
         LDA #<NOTHING
         LDY #>NOTHING
         LDX SHS
         BEQ SHFLD2
         LDA PTR3
         LDY PTR3+1
SHFLD2   JSR PUTW
         LDA PTR3
         LDY PTR3+1
         JSR STRLEN
         SEC
         ADC PTR3
         STA PTR3
         BCC SHFLD3
         INC PTR3+1
SHFLD3   JSR SHFAT
         LDA #VALW
         STA SW
         JSR SPACES
         LDA SHS
         BEQ SHFLD6
         LDX SFI
         CPX #7
         BNE SHFLD4
         LDY #SMODE
         LDA (SITEP),Y
         JSR SHMODE
         JMP SHFLD6
SHFLD4   JSR SHFAT
         LDX SFI
         JSR SFIELD
         LDX SFI
         CPX #4
         BNE SHFLD5
         JSR STRLEN         ; the password: a * for each letter
         CMP #VALW
         BCC SHFLD4A
         LDA #VALW
SHFLD4A  STA SW
         LDA #'*
         JSR REP
         JMP SHFLD6
SHFLD5   JSR PUTW
SHFLD6   INC SFI
         LDA SFI
         CMP #8
         BNE SHFLD1
         LDA SHS
         BEQ SHFLD7
         LDX #4
         JSR SFIELD
         JSR STRLEN
         BNE SHFLD7
         LDX #FROW+4
         LDY #VALCOL
         JSR AT
         JSR PUTSI
         .BYTE "(asked for)",0
SHFLD7   RTS
;
; SHFAT: AT field SFI's value
;
SHFAT    LDA SFI
         CLC
         ADC #FROW
         TAX
         LDY #VALCOL
         JMP AT
;
; SHLIST: the sites, A the one with the cursor, and its fields
;
SHLIST   STA SCUR2
         LDA #0
         STA SLI
SHLIST1  LDA SLI
         CLC
         ADC #SLROW
         TAX
         LDY #SCRL+1
         JSR AT
         LDA #SCRW-2
         STA SW
         JSR SPACES
         LDA SLI
         CMP SCOUNT
         BCS SHLIST3
         LDA SLI
         CLC
         ADC #SLROW
         TAX
         LDY #SCRL+2
         JSR AT
         LDA SLI
         CMP SCUR2
         BNE SHLIST2
         JSR INVON
SHLIST2  JSR PUTSP
         LDA #SCRW-5
         STA SW
         LDX SLI
         JSR SSEL
         LDA SITEP
         LDY SITEP+1
         JSR PUTW
         JSR INVOFF
SHLIST3  INC SLI
         LDA SLI
         CMP #MAXSITES
         BNE SHLIST1
         LDA SCOUNT
         BNE SHLIST4
         LDX #SLROW+1
         JSR SHLAT
         JSR PUTSI
         .BYTE "No sites yet.",0
         LDX #SLROW+3
         JSR SHLAT
         JSR PUTSI
         .BYTE "^N adds one: a name, the",0
         LDX #SLROW+4
         JSR SHLAT
         JSR PUTSI
         .BYTE "server, your user and the",0
         LDX #SLROW+5
         JSR SHLAT
         JSR PUTSI
         .BYTE "folders to start in.",0
         LDA #0
         JMP SHFLD
SHLIST4  LDX SCUR2
         JSR SSEL
         LDA #1
         JMP SHFLD
SHLAT    LDY #SCRL+3
         JMP AT
;
SFRAME   LDX #2
         JSR RULE
         LDA #<STITLE
         LDY #>STITLE
         JSR BOX
         LDX #SEPROW
         LDY #SCRL
         JSR AT
         LDA #CHLT
         JSR PUTCH
         LDA #SCRW-2
         STA SW
         LDA #CHHLINE
         JSR REP
         LDA #CHRT
         JMP PUTCH
;
; SEDIT: edit site X (a copy of it); the carry set when it was saved,
; clear when left with ESC
;
SEDIT    STX SEDI
         JSR SSEL
         LDY #0
SEDIT0   LDA (SITEP),Y
         STA SCOPY,Y
         INY
         CPY #SITESZ
         BNE SEDIT0
         LDA #<SCOPY
         STA SITEP
         LDA #>SCOPY
         STA SITEP+1
         LDA #<EKEYS
         LDY #>EKEYS
         JSR KEYBAR
         LDA #1
         JSR SHFLD
         LDA #0
         STA SFI
SEDIT1   LDA SFI
         CMP #7
         BCS SEDIT5
         CMP #4
         BNE SEDIT2
         JSR INFOI
         .BYTE "Blank: asked for when connecting",0
         JMP SEDIT3
SEDIT2   JSR INFOI
         .BYTE "Type, then RETURN for the next one",0
SEDIT3   LDX SFI
         LDA FSIZE,X
         STA EDMAX
         LDA #0
         CPX #4
         BNE SEDIT4
         LDA #1
SEDIT4   STA EDMASK
         JSR SHFAT
         LDA #VALW
         STA SW
         LDX SFI
         JSR SFIELD
         JSR EDIT
         LDX #0
         STX EDMASK
         JMP SEDIT6
SEDIT5   JSR INFOI
         .BYTE "SPACE changes, RETURN saves",0
         JSR KEYGET
         LDX #1
         CMP #32
         BEQ SEDIT5A
         CMP #KRIGHT
         BEQ SEDIT5A
         LDX #2
         CMP #KLEFT
         BNE SEDIT6
SEDIT5A  STX TMP
         LDY #SMODE
         LDA (SITEP),Y
         CLC
         ADC TMP
         CMP #3
         BCC SEDIT5B
         SBC #3
SEDIT5B  STA (SITEP),Y
         JSR SHMODE
         JMP SEDIT1
SEDITJ   JMP SEDIT1
SEDIT6   CMP #KESC
         BNE SEDIT7
         CLC
         RTS
SEDIT7   CMP #KUP
         BNE SEDIT8
         LDA SFI
         BEQ SEDITJ
         DEC SFI
         JMP SEDIT1
SEDIT8   LDX SFI
         CPX #7
         BCS SEDIT9
         INC SFI
         JMP SEDIT1
SEDIT9   CMP #KRETURN
         BNE SEDITJ
         LDA SCOPY+48       ; no port: 21
         BNE SEDIT10
         LDA #'2
         STA SCOPY+48
         LDA #'1
         STA SCOPY+49
         LDA #0
         STA SCOPY+50
SEDIT10  LDA SCOPY          ; no name: the server's
         BNE SEDIT12
         LDX #0
SEDIT11  LDA SCOPY+16,X
         STA SCOPY,X
         BEQ SEDIT12
         INX
         CPX #15
         BNE SEDIT11
         LDA #0
         STA SCOPY,X
SEDIT12  LDX SEDI
         JSR SSEL
         LDY #0
SEDIT13  LDA SCOPY,Y
         STA (SITEP),Y
         INY
         CPY #SITESZ
         BNE SEDIT13
         SEC
         RTS
;
; SITESCR: the Sites screen; the site to connect to in A, or NO
;
SITESCR  LDA #0
         STA SCUR
         JSR SFRAME
SITES1   LDA SCUR
         JSR SHLIST
         LDA #<LKEYS
         LDY #>LKEYS
         JSR KEYBAR
         JSR INFOI
         .BYTE "Pick a site. ESC goes back.",0
         JSR KEYGET
         CMP #KESC
         BNE SITES2
         LDA #NO
         RTS
SITES2   CMP #KUP
         BEQ SITES2A
         CMP #'-
         BNE SITES3
SITES2A  LDA SCUR
         BEQ SITES1
         DEC SCUR
         JMP SITES1
SITES3   CMP #KDOWN
         BEQ SITES3A
         CMP #'=
         BNE SITES4
SITES3A  LDX SCUR
         INX
         CPX SCOUNT
         BCS SITES1
         STX SCUR
         JMP SITES1
SITES4   CMP #KRETURN
         BNE SITES5
         LDA SCOUNT
         BEQ SITES1
         LDA SCUR
         RTS
SITESJ   JMP SITES1
SITES5   CMP #14            ; ^N
         BNE SITES7
         LDA SCOUNT
         CMP #MAXSITES
         BNE SITES6
         JSR INFOI
         .BYTE "No room: 8 sites at most.",0
         JSR KEYGET
         JMP SITES1
SITES6   TAX
         JSR SCLEAR
         LDA SCOUNT
         JSR SHLIST
         LDX SCOUNT
         JSR SEDIT
         BCC SITESJ
         LDA SCOUNT
         STA SCUR
         INC SCOUNT
         JSR SSAVEUI
         JMP SITES1
SITES7   CMP #5             ; ^E
         BNE SITES8
         LDA SCOUNT
         BEQ SITESJ
         LDX SCUR
         JSR SEDIT
         BCC SITESJ
         JSR SSAVEUI
         JMP SITES1
SITESK   JMP SITES1
SITES8   CMP #KDEL
         BEQ SITES8A
         CMP #KDEL2
         BNE SITESK
SITES8A  LDA SCOUNT
         BEQ SITESK
         JSR MSGSTART
         JSR SBI
         .BYTE "Delete ",0
         LDX SCUR
         JSR SSEL
         LDA SITEP
         LDY SITEP+1
         JSR SBADD
         JSR SBI
         .BYTE "? Y/N",0
         JSR INFOMSG
         JSR KEYGET
         AND #$DF
         CMP #'Y
         BNE SITESK
         LDX SCUR
SITES9   INX
         CPX SCOUNT
         BCS SITES10
         DEX
         JSR SMOVE
         INX
         BNE SITES9
SITES10  DEC SCOUNT
         LDA SCUR
         BEQ SITES11
         CMP SCOUNT
         BNE SITES11
         DEC SCUR
SITES11  JSR SSAVEUI
         JMP SITES1
;
; SMOVE: site X+1 to site X (X is kept)
;
SMOVE    LDA SITEL,X
         STA PTR2
         LDA SITEH,X
         STA PTR2+1
         LDA SITEL+1,X
         STA PTR
         LDA SITEH+1,X
         STA PTR+1
         LDY #0
SMOVE1   LDA (PTR),Y
         STA (PTR2),Y
         INY
         CPY #SITESZ
         BNE SMOVE1
         RTS
;
CFG      .BYTE "D:EFTPXL.CFG",0
STITLE   .BYTE "Sites",0
NOTHING  .BYTE 0
LABELS   .BYTE "Name:",0,"Server:",0,"Port:",0,"User:",0,"Password:",0
         .BYTE "Folder:",0,"Atari:",0,"Files:",0
MODES    .BYTE "Binary",0,"Text",0,"By type",0
LKEYS    .BYTE "RETURN",0,"Connect",0,"^N",0,"New",0,"^E",0,"Edit",0
         .BYTE "DEL",0,"Del",0,0
EKEYS    .BYTE "RETURN",0,"Next",0,"ESC",0,"Cancel",0,0
