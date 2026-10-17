;
; XSHOW.M65 - EFTP_XL 1.1
; Transfers area, progress, each file
; Copyright (C) 2026 AERA | Erez Yaary
;
;
; XRATIO - the file's done * A / its
; size
; Exit: A, 255 at most (0 if size 0)
;
XRATIO   PHA                ; A, for MUL8
         LDA FSIZEB         ; size 0?
         ORA FSIZEB+1
         ORA FSIZEB+2
         ORA FSIZEB+3
         BNE XRATIO1
         PLA                ; size 0
         LDA #0
         RTS
XRATIO1  LDA #<FDONEB       ; NUM = done
         LDY #>FDONEB
         JSR GETL
         PLA
         JSR MUL8           ; * A
         LDA #<FSIZEB
         LDY #>FSIZEB
         JSR NUM2L
         JSR DIV32          ; / size
         LDA NUM+1
         ORA NUM+2
         ORA NUM+3
         BEQ XRATIO2
         LDA #255           ; over a byte
         RTS
XRATIO2  LDA NUM
         RTS
;
; DROW - queue entry A on its row:
; arrow, name, then a bar and % for
; the one going, else how it went
; and its size
;
DROW     STA DRI            ; DRI: queue index
         SEC
         SBC XFIRST         ; its screen row:
         CLC                ; XROW+1 + A-XFIRST
         ADC #XROW+1
         TAX
         JSR CLRROW
         LDY #SCRL
         JSR AT
         LDA #CHUP          ; arrow: which way
         LDX XDOWN
         BEQ DROW1          ; 0: to the server
         LDA #CHDOWN
DROW1    JSR PUTCH
         INC SCOL           ; a space
         LDA #12            ; name: 12 columns
         STA SW
;
; In a folder walk the pane holds the
; inner folder, so the row going
; shows file K (only XPROG draws then)
;
         LDX DRI
         LDA XQST,X         ; how it went
         STA DRF
         LDA XQUEUE,X       ; its entry
         LDY XWALK          ; in a folder walk
         BEQ DROW1A
         CPX XCUR           ; the one going
         BNE DROW1A
         LDA K              ; shows file K
DROW1A   STA DRJ            ; DRJ = entry
         TAX
         JSR SHOWN          ; 8.3 if to the Atari
         JSR PUTW
         INC SCOL
         JSR SIZESTART      ; build in SIZEB
         LDA DRI
         CMP XCUR
         BNE DROW3          ; not the one going
         LDA DRF
         AND #EDONE+EFAIL+ESKIP
         BNE DROW3          ; or it has ended
;
; The bar: done in inverse spaces,
; the rest shaded; then "42%"
;
         LDA #16            ; the bar, 16 wide
         JSR XRATIO         ; done*16/size
         CMP #17
         BCC DROW2
         LDA #16            ; 16 at most
DROW2    STA DRFILL
         STA SW
         JSR INVON          ; done: inverse
         JSR SPACES
         JSR INVOFF
         LDA #16
         SEC
         SBC DRFILL         ; 16 - done
         STA SW
         LDA #CHSHADE       ; to go: shaded
         JSR REP
         LDA #100
         JSR XRATIO         ; done*100/size
         CMP #100
         BCC DROW2A
         LDA #99            ; not 100% yet
DROW2A   JSR SBBYTE         ; into SIZEB
         LDA #'%
         JSR SBCH
         JMP DROW8
;
; Ended or waiting: its word from
; STATES (X = where), then its size
;
DROW3    LDA DRF            ; X = in STATES
         LDX #0
         AND #EDONE
         BNE DROW7          ; Done
         LDX #5
         LDA DRF
         AND #ESKIP
         BNE DROW7          ; Skipped
         LDX #13
         LDA DRF
         AND #EFAIL
         BEQ DROW7          ; Waiting
         LDX #21
         LDA XSTOP
         BEQ DROW7          ; Failed
         LDA DRI
         CMP XCUR
         BNE DROW7
         LDX #28            ; Stopped by ESC
DROW7    TXA                ; A/Y = STATES+X
         CLC
         ADC #<STATES
         LDY #>STATES
         BCC DROW7A
         INY                ; next page
DROW7A   JSR PUTS
         LDX DRJ
         LDA EFLAG,X        ; a folder has no size
         AND #EDIR
         BNE DROW8
         JSR ESIZE          ; NUM = its size
         JSR SBSIZE         ; into SIZEB
DROW8    LDA #<SIZEB        ; SIZEB at the right
         LDY #>SIZEB
         JSR STRLEN
         EOR #$FF           ; -length-1, and C
         SEC                ; adds the 1:
         ADC #SCRR+1        ; SCRR+1 - length
         STA SCOL
         LDA #<SIZEB
         LDY #>SIZEB
         JMP PUTS
;
; At 0, 5, 13, 21 and 28 (DROW3)
;
STATES   .BYTE "Done",0,"Skipped",0,"Waiting",0,"Failed",0,"Stopped",0
;
; DQUEUE - draw the queue: XROWS rows
; from the one before the one going,
; and " 2 of 5 " on the line above
;
DQUEUE   LDA XCUR
         BEQ DQUEUE1
         SEC
         SBC #1             ; one done above it
DQUEUE1  STA XFIRST
         LDA XCOUNT
         CMP #XROWS+1
         BCS DQUEUE2        ; more than XROWS
         LDA #0             ; all fit: from 0
         STA XFIRST
         BEQ DQUEUE3        ; always
DQUEUE2  SBC #XROWS         ; else keep the
         CMP XFIRST         ; rows full: C=1
         BCS DQUEUE3        ; here, so A = the
         STA XFIRST         ; last first row
DQUEUE3  LDA XFIRST
         STA DQR            ; DQR: entry drawn
DQUEUE4  LDA DQR            ; each row
         CMP XCOUNT
         BCS DQUEUE5        ; past the end
         JSR DROW
         JMP DQUEUE6
DQUEUE5  SEC                ; blank row
         SBC XFIRST         ; (A = DQR: its row)
         CLC
         ADC #XROW+1
         TAX
         JSR CLRROW
DQUEUE6  INC DQR
         LDA XFIRST
         CLC
         ADC #XROWS
         CMP DQR
         BNE DQUEUE4        ; XROWS rows done?
         LDA #<XLINE        ; " 2 of 5 "
         LDY #>XLINE
         JSR SBSTART
         JSR SBSP
         LDA XCUR
         CLC
         ADC #1             ; from 1, up to
         CMP XCOUNT         ; XCOUNT (XCUR is
         BCC DQUEUE7        ; XCOUNT at the end)
         LDA XCOUNT
DQUEUE7  JSR SBBYTE
         JSR SBI
         .BYTE " of ",0
         LDA XCOUNT
         JSR SBBYTE
         JSR SBSP
         LDX #XROW          ; the line above:
         LDY #SCRR-10       ; clear its end
         JSR AT
         LDA #11            ; columns 28 to 38
         STA SW
         LDA #CHHLINE
         JSR REP
         LDA #<XLINE        ; then XLINE at
         LDY #>XLINE        ; the right
         JSR STRLEN
         EOR #$FF           ; SCRR+1 - length,
         SEC                ; as in DROW8
         ADC #SCRR+1
         STA SCOL
         LDA #<XLINE
         LDY #>XLINE
         JMP PUTS
;
; XPROG - show the file going: arrow,
; name, done/size and speed on the
; info line, and its queue row
;
XPROG    LDA #<XLINE        ; XLINE, as
         LDY #>XLINE        ; "^ NAME 12K/40K 3K/s"
         JSR SBSTART
         LDA #CHUP
         LDX XDOWN
         BEQ XPROG1         ; 0: to the server
         LDA #CHDOWN
XPROG1   JSR SBCH
         JSR SBSP
         LDX K
         JSR SHOWN
         JSR SBADD
         JSR SBSP
         LDA #<FDONEB
         LDY #>FDONEB
         JSR GETL
         JSR SBSIZE         ; done
         LDA #'/
         JSR SBCH
         LDA #<FSIZEB
         LDY #>FSIZEB
         JSR GETL
         JSR SBSIZE         ; of its size
         JSR SBSP
         JSR SBRATE         ; speed so far
         LDA #<XLINE
         LDY #>XLINE
         JSR INFO
         LDA XCUR
         JMP DROW           ; and its row
;
; XMOVED - XN bytes of a block went:
; count them, show them, look for ESC
; Exit: A=XSTOP, Z=0 to stop
;
XMOVED   LDA XN             ; NUM = XN
         STA NUM
         LDA XN+1
         STA NUM+1
         LDA #0
         STA NUM+2
         STA NUM+3
         LDA #<FDONEB       ; the file's done
         LDY #>FDONEB
         JSR ADDTO
         LDA #<TDONE        ; and the total
         LDY #>TDONE
         JSR ADDTO
         JSR XPROG
         JSR KEYHIT
         BEQ XMOVED1        ; no key
         JSR KEYGET
         CMP #KESC
         BNE XMOVED1        ; others: dropped
         LDA #1             ; ESC: stop
         STA XSTOP
XMOVED1  LDA XSTOP          ; Z from XSTOP
         RTS
;
; XERRI - XERROR = "what: why" on the
; info line; what: the string after
; the JSR, why: from FERR
; Returns past the string (INLINE)
;
XERRI    JSR INLINE         ; A/Y = "what"
         PHA                ; keep A/Y
         TYA
         PHA
         LDA #<XERROR
         LDY #>XERROR
         JSR SBSTART
         PLA
         TAY
         PLA
         JSR SBADD
         JSR SBI
         .BYTE ": ",0
         LDA FERR
         CMP #ETIME
         BNE XERR1
         JSR SBI
         .BYTE "no answer",0
         JMP XERR3
XERR1    CMP #ECLOSED
         BNE XERR2
         JSR SBI
         .BYTE "connection lost",0
         JMP XERR3
XERR2    LDA #0             ; else the reply,
         STA FTPMSG+27      ; cut to fit: 27
         LDA #<FTPMSG       ; and "Download: "
         LDY #>FTPMSG       ; fill the 37
         JSR SBADD
XERR3    LDA #<XERROR
         LDY #>XERROR
         JMP INFO
;
; SAYCIO - XERROR = "NAME.EXT: error
; 144" on the info line: CIO status
; XST, name from FSPEC
;
SAYCIO   LDA #<XERROR
         LDY #>XERROR
         JSR SBSTART
;
; The name: back from the end of
; "D1:>GAMES>DIGDUG.XEX" to the last
; > or :, and take what is after it
;
         LDA #<FSPEC
         LDY #>FSPEC
         JSR STRLEN         ; after last > or :
SAYCIO4  DEY                ; Y = length, back
         BMI SAYCIO5        ; none: all of it
         LDA FSPEC,Y
         CMP #'>
         BEQ SAYCIO5
         CMP #':
         BNE SAYCIO4
SAYCIO5  INY                ; just past it
         TYA
         CLC
         ADC #<FSPEC        ; A/Y = FSPEC+Y
         TAX                ; (X: low byte)
         LDA #>FSPEC
         ADC #0
         TAY
         TXA
         JSR SBADD
         JSR SBI
         .BYTE ": error ",0
         LDA XST
         JSR SBBYTE         ; "144"
         JMP XERR3          ; show XERROR
;
; MAYREP - if A/Y is in pane X, ask to
; replace it (ESC also stops it all)
; Exit: C=1 leave it, C=0 go on
;
MAYREP   STA MRN            ; MRN = the name
         STY MRN+1
         TXA
         JSR PUSE           ; look in pane X
         LDA MRN
         LDY MRN+1
         JSR PFIND
         BCC MAYREP1        ; there: ask
         CLC                ; not there: go on
         RTS
MAYREP1  JSR MSGSTART
         LDA MRN
         LDY MRN+1
         JSR SBADD
         JSR SBI
         .BYTE " is there. Replace? Y/N",0
         JSR INFOMSG
         JSR KEYGET
         CMP #KESC
         BNE MAYREP2
         LDA #1             ; ESC: stop
         STA XSTOP
MAYREP2  AND #$DF           ; to capitals
         CMP #'Y
         BEQ MAYREP3        ; Y: replace
         SEC                ; any other (ESC too)
         RTS
MAYREP3  CLC
         RTS
;
; One file each way
;
; GETF - file K, server to Atari
; Exit: A=EDONE, EFAIL or ESKIP
;
GETF     LDX K
         JSR ANAMEX         ; its 8.3 name
         LDA #<ANAME
         LDY #>ANAME
         LDX #LOCAL         ; on the Atari yet?
         JSR MAYREP
         BCC GETF1
         LDA #ESKIP         ; leave it
         RTS
GETF1    LDA #<ANAME
         LDY #>ANAME
         JSR LSPECN         ; FSPEC = its path
         LDX K
         JSR ENAME          ; RETR by the
         JSR FRETR          ; server's name
         BCC GETF2
         STA FERR
         JSR XERRI
         .BYTE "Download",0
         LDA #EFAIL
         RTS
GETF2    LDA #<FSPEC
         LDY #>FSPEC
         LDX #8             ; write
         JSR COPEN
         BCC GETF3
         STA XST            ; could not open
         JSR CCLOSE
         JSR FABORT         ; drop the data link
         JSR SAYCIO
         LDA #EFAIL
         RTS
;
; Each block: FREAD into BUF, to
; Atari text if text, CWRITE; XN
; counts what came, XLEN is written
;
GETF3    JSR FREAD          ; next block
         BCS GETF6          ; ETIME or ECLOSED
         LDA NLEN
         ORA NLEN+1
         BEQ GETF5          ; end of file
         LDA NLEN
         STA XLEN           ; XLEN to write,
         STA XN             ; XN to count
         LDA NLEN+1
         STA XLEN+1
         STA XN+1
         LDA XTEXT
         BEQ GETF4
         JSR TOATARI        ; XLEN = bytes now
GETF4    LDA XLEN
         ORA XLEN+1
         BEQ GETF4A         ; none to write
         LDA #<BUF
         LDY #>BUF
         JSR CWRITE
         BCS GETF7
GETF4A   JSR XMOVED
         BEQ GETF3          ; no ESC: more
         JSR CCLOSE         ; stopped
         JSR FABORT
         JMP GETF9
;
; The ends: all came (EDONE), or a
; failure or ESC: the half file is
; deleted (EFAIL)
;
GETF5    JSR CCLOSE         ; all of it came
         BCS GETF7A         ; close failed
         JSR FDONE          ; 226 or 250?
         BCS GETF5B
         LDA #EDONE
         RTS
GETF5B   STA FERR           ; for XERRI
         BCS GETF8          ; always
GETF6    STA FERR           ; the connection failed
         JSR CCLOSE
         JSR FABORT
GETF8    JSR XERRI
         .BYTE "Download",0
         JMP GETF9
GETF7    STA XST            ; the disk failed
         JSR CCLOSE
         JMP GETF7B
GETF7A   STA XST
GETF7B   JSR FABORT
         JSR SAYCIO
GETF9    LDA #<FSPEC        ; no half files
         LDY #>FSPEC
         LDX #33            ; XIO 33: delete
         JSR CXIO
         LDA #EFAIL
         RTS
;
; PUTF - file K, Atari to server
; Exit: A=EDONE, EFAIL or ESKIP
;
PUTF     LDX K
         JSR ENAME
         LDX #REMOTE        ; on the server yet?
         JSR MAYREP
         BCC PUTF1
         LDA #ESKIP         ; leave it
         RTS
PUTF1    LDX K
         JSR ENAME
         JSR LSPECN         ; FSPEC = its path
         LDA #<FSPEC
         LDY #>FSPEC
         LDX #4             ; read
         JSR COPEN
         BCC PUTF2
         STA XST            ; could not open
         JSR CCLOSE
         JSR SAYCIO
         LDA #EFAIL
         RTS
PUTF2    LDX K
         JSR ENAME
         JSR FSTOR          ; STOR, same name
         BCC PUTF3
         STA FERR
         JSR CCLOSE         ; the Atari file
         JSR XERRI
         .BYTE "Upload",0
         LDA #EFAIL
         RTS
;
; Each block: CREAD, to CR LF if
; text, FWRITE. The last bytes may
; come with 136 (end of file)
;
PUTF3    LDA #0             ; no net error yet
         STA FERR
PUTF4    LDA XTEXT
         BEQ PUTF5
         LDA #<[BUF+256]    ; text: 1 page at
         LDY #>[BUF+256]    ; BUF+256, as CR LF
         LDX #1             ; can double it
         BNE PUTF6          ; always
PUTF5    LDA #<BUF          ; else 2 pages
         LDY #>BUF
         LDX #2
PUTF6    JSR CREAD
         STA XST            ; CIO status
         LDA CGOT
         ORA CGOT+1
         BEQ PUTF8          ; none came
         LDA CGOT
         STA XLEN           ; XLEN to send,
         STA XN             ; XN to count
         LDA CGOT+1
         STA XLEN+1
         STA XN+1
         LDA XTEXT
         BEQ PUTF7
         JSR TOSERV         ; XLEN = CR LF bytes
PUTF7    JSR FWRITE
         BCS PUTF10         ; net failed
         JSR XMOVED
         BNE PUTF9          ; ESC
PUTF8    LDA XST
         CMP #128
         BCC PUTF4          ; no error: more
;
; Out of the loop: whole only at
; 136, with no net error and no ESC
;
PUTF9    JSR CCLOSE
         LDA XST
         CMP #136           ; end of file,
         BNE PUTF11
         LDA FERR           ; no net error
         BNE PUTF11
         LDA XSTOP          ; and no ESC:
         BNE PUTF11
         JSR FDONE          ; all of it went
         BCC PUTF13         ; 226 or 250
         STA FERR
         JSR XERRI
         .BYTE "Upload",0
         LDA #EFAIL
         RTS
PUTF10   STA FERR           ; ECLOSED
         JMP PUTF9
PUTF11   JSR FABORT         ; it failed
         LDA FERR
         BEQ PUTF12         ; not the net
         JSR XERRI
         .BYTE "Upload",0
         LDA #EFAIL
         RTS
PUTF12   LDA XST            ; a disk error?
         CMP #128
         BCC PUTF12A        ; no: it was ESC
         CMP #136
         BEQ PUTF12A        ; EOF is not one
         JSR SAYCIO
PUTF12A  LDA #EFAIL
         RTS
PUTF13   LDA #EDONE
         RTS
;
; XDRAW - the transfers area: what
; the last transfer did, or how to
; start one
;
XDRAW    LDX #XROW+1
         LDY #SCRL
         JSR AT
         LDA SUMMARY
         BEQ XDRAW1         ; none yet
         LDA #<SUMMARY
         LDY #>SUMMARY
         JMP PUTS
XDRAW1   JSR PUTSI
         .BYTE "Nothing yet. RETURN sends a file,",0
         LDX #XROW+2
         LDY #SCRL
         JSR AT
         JSR PUTSI
         .BYTE "SPACE marks several, ^T sends them.",0
         RTS
