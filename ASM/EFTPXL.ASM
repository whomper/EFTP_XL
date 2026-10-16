         .OPT NO LIST
;
; EFTP_XL - file transfer for 8-bit Ataris over FujiNet
; Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
;
; Mac/65 source: on the Atari, LOAD #D:EFTPXL.M65 from the source
; disk, then ASM ,,#D:EFTPXL.XEX (README.md says more); on another
; computer, make (ATasm). The program loads at LOAD, above DOS, EDOS ($1E00-$3752)
; and the MEMLO of DOS 2.5 and SpartaDOS 3, and ends below $9C00, so
; BASIC may be on.
;
         .INCLUDE #D:EQUATES.M65
;
LOAD     =   $4000
;
; First, loaded and run before the program: is there room for it?
;
         *=  $9A00
CHECK    LDA MEMLO+1
         CMP #>LOAD
         BCC CHECK1
         BNE CHECK2
         LDA MEMLO
         BNE CHECK2
CHECK1   LDA MEMTOP
         CMP #<BSSEND
         LDA MEMTOP+1
         SBC #>BSSEND
         BCS CHECK3
         LDA #<NOROOM
         LDY #>NOROOM
         BNE CHECK4
CHECK2   LDA #<LOW
         LDY #>LOW
CHECK4   STA ICBAL0
         STY ICBAH0
         LDA #$FF
         STA ICBLL0
         LDA #0
         STA ICBLH0
         LDA #9
         STA ICCOM0
         LDX #0
         JSR CIOV
         JMP (DOSVEC)
CHECK3   RTS
LOW      .BYTE "EFTP_XL loads at $4000: MEMLO is above it",EOL
NOROOM   .BYTE "EFTP_XL: not enough memory",EOL
         *=  INITAD
         .WORD CHECK
;
; The program, its font first (1K-aligned)
;
         *=  LOAD
         .INCLUDE #D:FONT.M65
;
; the last release, which every build shows
;
VERSION  .BYTE "EFTP_XL 0.7",0
;
         .INCLUDE #D:UI.M65
         .INCLUDE #D:CMDS.M65
         .INCLUDE #D:XFER.M65
         .INCLUDE #D:XSHOW.M65
         .INCLUDE #D:XTREE.M65
         .INCLUDE #D:SITES.M65
         .INCLUDE #D:FTP.M65
         .INCLUDE #D:REMOTE.M65
         .INCLUDE #D:LOCAL.M65
         .INCLUDE #D:PANE.M65
         .INCLUDE #D:SCREEN.M65
         .INCLUDE #D:TEXT.M65
         .INCLUDE #D:DATA.M65
;
         *=  RUNAD
         .WORD START
