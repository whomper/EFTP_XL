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

unsigned char scr_row, scr_col, scr_inv, scr_w;
unsigned char edit_max, edit_mask;

static unsigned char *row_addr[SCR_ROWS];
static unsigned char old_chbas, old_c1, old_c2, old_c4;

/* ATASCII -> the screen's internal code, by the top 2 bits of 7 */
static const unsigned char adjust[4] = { 0x40, 0xE0, 0xE0, 0x00 };

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

void __fastcall__ scr_char(unsigned char c)
{
    row_addr[scr_row][scr_col++] =
        (c + adjust[(c >> 5) & 3]) ^ (scr_inv ? 0x80 : 0);
}

void __fastcall__ scr_puts(const char *s)
{
    while (*s && scr_col < 40)
        scr_char(*s++);
}

void __fastcall__ scr_putw(const char *s)
{
    unsigned char n = scr_w;

    while (n--)
        scr_char(*s ? *s++ : ' ');
}

void __fastcall__ scr_rep(unsigned char c)
{
    unsigned char n = scr_w;

    while (n--)
        scr_char(c);
}

void __fastcall__ scr_clear(unsigned char row)
{
    memset(row_addr[row], 0, 40);
}

void __fastcall__ scr_rule(unsigned char row)
{
    AT(row, SCR_L);
    scr_w = SCR_W;
    scr_rep(CH_HLINE);
}

void __fastcall__ scr_box(const char *title)
{
    unsigned char r;

    scr_w = SCR_W - 2;
    for (r = 3; r <= 22; ++r) {
        AT(r, SCR_L);
        scr_char(r == 3 ? CH_TL : r == 22 ? CH_BL : CH_VLINE);
        scr_rep(r == 3 || r == 22 ? CH_HLINE : ' ');
        scr_char(r == 3 ? CH_TR : r == 22 ? CH_BR : CH_VLINE);
    }
    AT(3, SCR_L + 2);
    scr_inv = 1;
    scr_char(' ');
    scr_puts(title);
    scr_char(' ');
    scr_inv = 0;
}

void __fastcall__ scr_keys(const char *list)
{
    scr_clear(23);
    AT(23, SCR_L);
    while (*list) {
        scr_inv = 1;
        scr_puts(list);
        scr_inv = 0;
        list += strlen(list) + 1;
        if (*list) {
            ++scr_col;
            scr_puts(list);
        }
        list += strlen(list) + 1;
        ++scr_col;
    }
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

unsigned char __fastcall__ scr_edit(char *s)
{
    unsigned char len = strlen(s), k, first, i, w = scr_w, col = scr_col;

    for (;;) {
        /* show the end of what fits, then the cursor block */
        first = len >= w ? len - w + 1 : 0;
        scr_col = col;
        for (i = first; i < first + w; ++i) {
            scr_inv = i == len;
            scr_char(i < len ? (edit_mask ? '*' : s[i]) : ' ');
        }
        scr_inv = 0;
        k = key_get();
        switch (k) {
        case K_RETURN: case K_ESC: case K_UP: case K_DOWN: case K_TAB:
            scr_col = col;
            for (i = first; i < first + w; ++i)
                scr_char(i < len ? (edit_mask ? '*' : s[i]) : ' ');
            return k;
        case K_BKSP:
            if (len)
                s[--len] = '\0';
            break;
        default:
            k &= 0x7F;      /* the inverse key doesn't belong in names */
            if (k >= 0x20 && k < 0x7B && len < edit_max - 1) {
                s[len++] = k;
                s[len] = '\0';
            }
        }
    }
}
