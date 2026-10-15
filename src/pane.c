/*
 * EFTP_XL - the panes' entries
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "pane.h"

char *e_name[NE + 1];
unsigned long e_size[NE + 1];
unsigned char e_flags[NE + 1];
stamp_t e_when[NE + 1];

unsigned char p_count[2], p_top[2], p_cur[2];
unsigned char p_dirs[2], p_files[2], p_full[2];
char p_path[2][PATH_LEN];

unsigned char side, base;

unsigned long new_size;
unsigned char new_flags;
stamp_t new_when;

/* the names, a pool for each pane */
static char pool0[1024], pool1[1280];
static char *const pool[2] = { pool0, pool1 };
static const unsigned int pool_size[2] = { sizeof(pool0), sizeof(pool1) };
static unsigned int pool_used[2];

void __fastcall__ pane_use(unsigned char s)
{
    side = s;
    base = s ? MAXE : 0;
}

void pane_clear(void)
{
    p_count[side] = p_top[side] = p_cur[side] = 0;
    p_dirs[side] = p_files[side] = p_full[side] = 0;
    pool_used[side] = 0;
}

void __fastcall__ pane_add(const char *name)
{
    unsigned int n = strlen(name) + 1;
    unsigned char k = base + p_count[side];

    if (p_count[side] == MAXE || pool_used[side] + n > pool_size[side]) {
        p_full[side] = 1;
        return;
    }
    ++p_count[side];
    e_name[k] = pool[side] + pool_used[side];
    memcpy(e_name[k], name, n);
    pool_used[side] += n;
    e_size[k] = new_size;
    e_when[k] = new_when;
    e_flags[k] = new_flags;
    if (new_flags & E_DIR)
        ++p_dirs[side];
    else if (!(new_flags & E_UP))
        ++p_files[side];
    new_when.day = 0;
    new_size = 0;
    new_flags = 0;
}

static unsigned char rank(unsigned char k)
{
    return (e_flags[k] & E_UP) ? 0 : (e_flags[k] & E_DIR) ? 1 : 2;
}

/* entry a goes after entry b? */
static unsigned char after(unsigned char a, unsigned char b)
{
    const unsigned char *s = (const unsigned char *)e_name[a];
    const unsigned char *t = (const unsigned char *)e_name[b];
    unsigned char c, d;

    if (rank(a) != rank(b))
        return rank(a) > rank(b);
    for (;; ++s, ++t) {
        c = toupper(*s);
        d = toupper(*t);
        if (c != d || !c)
            return c > d;
    }
}

static void copy(unsigned char to, unsigned char from)
{
    e_name[to] = e_name[from];
    e_size[to] = e_size[from];
    e_flags[to] = e_flags[from];
    e_when[to] = e_when[from];
}

void pane_sort(void)
{
    unsigned char i, j, end = base + p_count[side];

    for (i = base + 1; i < end; ++i) {
        copy(NE, i);
        for (j = i; j > base && after(j - 1, NE); --j)
            copy(j, j - 1);
        copy(j, NE);
    }
}

unsigned char __fastcall__ pane_find(const char *name)
{
    unsigned char k, end = base + p_count[side];

    for (k = base; k < end; ++k)
        if (!strcmp(e_name[k], name))
            return k;
    return NO;
}

unsigned long fmt_n;

void __fastcall__ fmt_size(char *s)
{
    unsigned long n = fmt_n;
    const char *unit = "";

    if (n >= 1000) {
        n = (n + 1023) >> 10;
        unit = "K";
        if (n >= 1000) {
            n = (n + 512) >> 10;
            unit = "M";
        }
    }
    utoa((unsigned int)n, s, 10);
    strcat(s, unit);
}

static char *sb;

void __fastcall__ sb_start(char *s)
{
    sb = s;
    *s = '\0';
}

void __fastcall__ sb_add(const char *s)
{
    while ((*sb = *s++) != '\0')
        ++sb;
}

void __fastcall__ sb_num(unsigned int n)
{
    utoa(n, sb, 10);
    sb += strlen(sb);
}

void __fastcall__ sb_size(unsigned long n)
{
    fmt_n = n;
    fmt_size(sb);
    sb += strlen(sb);
}

static void __fastcall__ sb_2(unsigned char n)
{
    if (n < 10)
        sb_add("0");
    sb_num(n);
}

void __fastcall__ sb_stamp(unsigned char k)
{
    stamp_t *w = &e_when[k];

    if (!w->day)
        return;
    sb_2(w->day);
    sb_add(".");
    sb_2(w->mon);
    if (w->year != NO) {
        sb_add(".");
        sb_2(w->year);
    } else if (w->hour != NO) {
        sb_add(" ");
        sb_2(w->hour);
        sb_add(":");
        sb_2(w->min);
    }
}
