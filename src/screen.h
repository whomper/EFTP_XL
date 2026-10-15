/*
 * EFTP_XL - the screen: GRAPHICS 0 in EDOS's font and colours, drawn
 * straight into screen memory, and the keyboard
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * Drawing goes at scr_row, scr_col (AT sets both), in inverse when
 * scr_inv is 1; the functions take one argument, which cc65 turns into
 * the least code.
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

extern unsigned char scr_row, scr_col, scr_inv, scr_w;
#define AT(r, c)    (scr_row = (r), scr_col = (c))

void scr_init(void);
void scr_done(void);

/* text at scr_row, scr_col; scr_col moves on past it */
void __fastcall__ scr_puts(const char *s);
/* the same, cut or padded with spaces to exactly scr_w columns */
void __fastcall__ scr_putw(const char *s);
void __fastcall__ scr_char(unsigned char c);
/* c, scr_w times */
void __fastcall__ scr_rep(unsigned char c);
void __fastcall__ scr_clear(unsigned char row);
void __fastcall__ scr_rule(unsigned char row);
/* a box over rows 3..22, title in inverse in its top line */
void __fastcall__ scr_box(const char *title);
/* the key bar on row 23: "KEY\0label\0KEY\0label\0\0", keys in inverse */
void __fastcall__ scr_keys(const char *list);

unsigned char key_get(void);

/* Edit s (at most edit_max - 1 characters; '*' for each when
   edit_mask) in scr_w columns at scr_row, scr_col. Returns the key that
   ended it: RETURN, ESC, up, down or TAB. */
extern unsigned char edit_max, edit_mask;
unsigned char __fastcall__ scr_edit(char *s);

#endif
