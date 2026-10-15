/*
 * EFTP_XL - the screen: GRAPHICS 0 in EDOS's font and colours, drawn
 * straight into screen memory, and the keyboard
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef SCREEN_H
#define SCREEN_H

#define SCR_ROWS    24
#define SCR_L       1       /* columns 1..38: a column of margin each side */
#define SCR_R       38
#define SCR_W       38

/* ATASCII characters the interface draws */
#define CH_HLINE    0x12
#define CH_VLINE    0x7C
#define CH_TL       0x11
#define CH_TR       0x05
#define CH_BL       0x1A
#define CH_BR       0x03
#define CH_LT       0x01    /* |- */
#define CH_RT       0x04    /* -| */
#define CH_TT       0x17    /* T */
#define CH_BT       0x18    /* upside-down T */
#define CH_DOT      0x14    /* filled circle: connected */
#define CH_MARK     0x60    /* diamond: marked file */
#define CH_UP       0x1C
#define CH_DOWN     0x1D
#define CH_FOLDER   0x00    /* EFTP_XL's own characters (tools/mkfont.py) */
#define CH_FILE     0x10
#define CH_MORE     0x06
#define CH_SHADE    0x7B

/* keys */
#define K_RETURN    0x9B
#define K_ESC       0x1B
#define K_BKSP      0x7E
#define K_TAB       0x7F
#define K_UP        0x1C
#define K_DOWN      0x1D
#define K_LEFT      0x1E
#define K_RIGHT     0x1F
#define K_DEL       0x9C    /* Shift+Delete; Ctrl+Delete is $FE */
#define K_DEL2      0xFE
#define K_HELP      0xFF
#define CTRL(c)     ((c) & 0x1F)

void scr_init(void);
void scr_done(void);

/* Draw text (ATASCII) at row, col; returns the column after it. */
unsigned char scr_put(unsigned char row, unsigned char col,
                      const char *s, unsigned char inv);
/* The same, cut or padded with spaces to exactly w columns. */
void scr_putw(unsigned char row, unsigned char col, const char *s,
              unsigned char w, unsigned char inv);
void scr_ch(unsigned char row, unsigned char col, unsigned char c,
            unsigned char inv);
void scr_fill(unsigned char row, unsigned char col, unsigned char c,
              unsigned char n, unsigned char inv);
void scr_clear(unsigned char r0, unsigned char r1);
void scr_rule(unsigned char row);
void scr_box(unsigned char r0, unsigned char r1, const char *title);
/* Inverse key name, then its label: returns the column after both. */
unsigned char scr_key(unsigned char row, unsigned char col,
                      const char *key, const char *label);

unsigned char key_get(void);

/* Edit s (max chars, shown in w columns) at row, col. Returns the key
   that ended it: RETURN, ESC, up or down, or TAB. */
unsigned char scr_edit(unsigned char row, unsigned char col, unsigned char w,
                       char *s, unsigned char max, unsigned char mask);

#endif
