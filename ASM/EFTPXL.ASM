         .OPT NO LIST
;
; EFTPXL.M65 - EFTP_XL 0.9
; FTP client for FujiNet
; Copyright (C) 2026 AERA | Erez Yaary
; GPL-2.0-or-later, see COPYING
;
; Mac/65: LOAD #D:EFTPXL.M65, then
; ASM ,,#D:EFTPXL.PRG
;
         .INCLUDE #D:EQUATES.M65
;
LOAD     =   $4000      ; above DOS and EDOS
;
; CHECK - init segment, run before
; the program loads: MEMLO must be
; at most LOAD and MEMTOP above
; BSSEND, else say so and go to DOS
;
         *=  $9A00
CHECK    LDA MEMLO+1
         CMP #>LOAD
         BCC CHECK1
         BNE CHECK2
         LDA MEMLO
         BNE CHECK2
CHECK1   LDA MEMTOP         ; room up to BSSEND?
         CMP #<BSSEND
         LDA MEMTOP+1
         SBC #>BSSEND
         BCS CHECK3
         LDA #<NOROOM
         LDY #>NOROOM
         BNE CHECK4
CHECK2   LDA #<LOW          ; DOS too big
         LDY #>LOW
CHECK4   STA ICBAL0         ; print it on E:
         STY ICBAH0
         LDA #$FF
         STA ICBLL0
         LDA #0
         STA ICBLH0
         LDA #9
         STA ICCOM0
         LDX #0
         JSR CIOV
         JMP (DOSVEC)       ; back to DOS
CHECK3   RTS
LOW      .BYTE "EFTP_XL loads at $4000: MEMLO is above it",EOL
NOROOM   .BYTE "EFTP_XL: not enough memory",EOL
         *=  INITAD
         .WORD CHECK
;
; The program; the font first, as
; it must be 1K aligned
;
         *=  LOAD
         .INCLUDE #D:FONT.M65
;
; The last release; every build
; shows it
;
VERSION  .BYTE "EFTP_XL 0.9",0
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
