/*
 * EFTP_XL - the screen and the keyboard
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#include <string.h>
#include <conio.h>
#include <atari.h>

#include "screen.h"

extern const unsigned char font[];

/* EDOS's colours: OS default blue, light text, black border */
#define BLUE        0x94
#define TEXT        0xCA
#define BORDER      0x00

static unsigned char *row_addr[SCR_ROWS];
static unsigned char old_chbas, old_c1, old_c2, old_c4;

/* ATASCII -> the screen's internal code */
static unsigned char internal(unsigned char a)
{
    unsigned char inv = a & 0x80;

    a &= 0x7F;
    if (a < 0x20)
        a += 0x40;
    else if (a < 0x60)
        a -= 0x20;
    return a | inv;
}

/* cc65's cgetc puts the E: cursor's cell back and clears its inverse
   bit; keep that cursor at row 0, column 0, where nothing is drawn. */
static void park_cursor(void)
{
    OS.rowcrs = 0;
    OS.colcrs = 0;
    OS.oldadr = OS.savmsc;
    OS.oldchr = 0;
}

void scr_init(void)
{
    unsigned char r;

    old_chbas = OS.chbas;
    old_c1 = OS.color1;
    old_c2 = OS.color2;
    old_c4 = OS.color4;

    for (r = 0; r < SCR_ROWS; ++r)
        row_addr[r] = OS.savmsc + r * 40;
    memset(OS.savmsc, 0, SCR_ROWS * 40);

    cursor(0);
    OS.crsinh = 1;
    park_cursor();
    OS.chbas = (unsigned int)font >> 8;
    OS.color1 = TEXT;
    OS.color2 = BLUE;
    OS.color4 = BORDER;
}

void scr_done(void)
{
    OS.chbas = old_chbas;
    OS.color1 = old_c1;
    OS.color2 = old_c2;
    OS.color4 = old_c4;
    memset(OS.savmsc, 0, SCR_ROWS * 40);
    OS.crsinh = 0;
    OS.rowcrs = 0;
    OS.colcrs = 2;
}

unsigned char scr_put(unsigned char row, unsigned char col,
                      const char *s, unsigned char inv)
{
    unsigned char *p = row_addr[row] + col;

    inv = inv ? 0x80 : 0;
    while (*s && col < 40) {
        *p++ = internal(*s++) ^ inv;
        ++col;
    }
    return col;
}

void scr_putw(unsigned char row, unsigned char col, const char *s,
              unsigned char w, unsigned char inv)
{
    unsigned char *p = row_addr[row] + col;
    unsigned char sp = inv ? 0x80 : 0;

    while (w--) {
        *p++ = (*s ? internal(*s++) : 0) ^ sp;
    }
}

void scr_ch(unsigned char row, unsigned char col, unsigned char c,
            unsigned char inv)
{
    row_addr[row][col] = internal(c) ^ (inv ? 0x80 : 0);
}

void scr_fill(unsigned char row, unsigned char col, unsigned char c,
              unsigned char n, unsigned char inv)
{
    memset(row_addr[row] + col, internal(c) ^ (inv ? 0x80 : 0), n);
}

void scr_clear(unsigned char r0, unsigned char r1)
{
    memset(row_addr[r0], 0, (r1 - r0 + 1) * 40);
}

void scr_rule(unsigned char row)
{
    scr_fill(row, SCR_L, CH_HLINE, SCR_W, 0);
}

void scr_box(unsigned char r0, unsigned char r1, const char *title)
{
    unsigned char r;

    scr_ch(r0, SCR_L, CH_TL, 0);
    scr_fill(r0, SCR_L + 1, CH_HLINE, SCR_W - 2, 0);
    scr_ch(r0, SCR_R, CH_TR, 0);
    scr_ch(r0, SCR_L + 2, ' ', 1);
    scr_ch(r0, scr_put(r0, SCR_L + 3, title, 1), ' ', 1);
    for (r = r0 + 1; r < r1; ++r) {
        scr_ch(r, SCR_L, CH_VLINE, 0);
        scr_fill(r, SCR_L + 1, ' ', SCR_W - 2, 0);
        scr_ch(r, SCR_R, CH_VLINE, 0);
    }
    scr_ch(r1, SCR_L, CH_BL, 0);
    scr_fill(r1, SCR_L + 1, CH_HLINE, SCR_W - 2, 0);
    scr_ch(r1, SCR_R, CH_BR, 0);
}

unsigned char scr_key(unsigned char row, unsigned char col,
                      const char *key, const char *label)
{
    col = scr_put(row, col, key, 1);
    if (*label)
        col = scr_put(row, col + 1, label, 0);
    return col + 1;
}

unsigned char key_get(void)
{
    for (;;) {
        if (OS.helpfg) {
            OS.helpfg = 0;
            return K_HELP;
        }
        if (kbhit()) {
            park_cursor();
            return cgetc();
        }
    }
}

unsigned char scr_edit(unsigned char row, unsigned char col, unsigned char w,
                       char *s, unsigned char max, unsigned char mask)
{
    unsigned char len = strlen(s), k, first, i;

    for (;;) {
        /* show the end of what fits, then the cursor block */
        first = len >= w ? len - w + 1 : 0;
        for (i = 0; i < w; ++i) {
            k = first + i < len ? (mask ? '*' : s[first + i]) : ' ';
            scr_ch(row, col + i, k, first + i == len);
        }
        k = key_get();
        switch (k) {
        case K_RETURN: case K_ESC: case K_UP: case K_DOWN:
        case K_TAB:
            scr_putw(row, col, mask ? "" : s + first, w, 0);
            if (mask)
                scr_fill(row, col, '*', len < w ? len : w, 0);
            return k;
        case K_BKSP:
            if (len)
                s[--len] = '\0';
            break;
        default:
            k &= 0x7F;      /* the inverse key doesn't belong in names */
            if (k >= 0x20 && k < 0x7B && len < max - 1) {
                s[len++] = k;
                s[len] = '\0';
            }
        }
    }
}
