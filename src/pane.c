/*
 * EFTP_XL - a pane's entries
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "pane.h"

void pane_clear(pane_t *p)
{
    p->count = p->top = p->cur = 0;
    p->pool_used = 0;
    p->dirs = p->files = 0;
    p->full = 0;
}

entry_t *pane_add(pane_t *p, const char *name, unsigned long size,
                  const stamp_t *when, unsigned char flags)
{
    entry_t *e;
    unsigned int n = strlen(name) + 1;

    if (p->count == p->max || p->pool_used + n > p->pool_size) {
        p->full = 1;
        return 0;
    }
    e = &p->ent[p->count++];
    e->name = p->pool + p->pool_used;
    memcpy(e->name, name, n);
    p->pool_used += n;
    e->size = size;
    if (when)
        e->when = *when;
    else
        e->when.day = 0;
    e->flags = flags;
    if (flags & E_DIR)
        ++p->dirs;
    else if (!(flags & E_UP))
        ++p->files;
    return e;
}

static unsigned char rank(const entry_t *e)
{
    return (e->flags & E_UP) ? 0 : (e->flags & E_DIR) ? 1 : 2;
}

static int compare(const void *a, const void *b)
{
    const entry_t *x = a, *y = b;
    const unsigned char *s, *t;
    unsigned char c, d;

    if (rank(x) != rank(y))
        return rank(x) - rank(y);
    for (s = (const unsigned char *)x->name,
         t = (const unsigned char *)y->name; ; ++s, ++t) {
        c = toupper(*s);
        d = toupper(*t);
        if (c != d || !c)
            return c - d;
    }
}

void pane_sort(pane_t *p)
{
    static entry_t e;
    unsigned char i, j;

    for (i = 1; i < p->count; ++i) {
        e = p->ent[i];
        for (j = i; j && compare(&p->ent[j - 1], &e) > 0; --j)
            p->ent[j] = p->ent[j - 1];
        p->ent[j] = e;
    }
}

void fmt_size(unsigned long n, char *s)
{
    unsigned int k;

    if (n < 1000) {
        utoa((unsigned int)n, s, 10);
        return;
    }
    k = (unsigned int)((n + 1023) >> 10);
    if (k < 1000) {
        utoa(k, s, 10);
        strcat(s, "K");
        return;
    }
    k = (unsigned int)((n + 524288UL) >> 20);
    utoa(k, s, 10);
    strcat(s, "M");
}

static char *sb;

void sb_start(char *s)
{
    sb = s;
    *s = '\0';
}

void sb_add(const char *s)
{
    while ((*sb = *s++) != '\0')
        ++sb;
}

void sb_num(unsigned int n)
{
    utoa(n, sb, 10);
    sb += strlen(sb);
}

void sb_size(unsigned long n)
{
    fmt_size(n, sb);
    sb += strlen(sb);
}

static void sb_2(unsigned char n)
{
    if (n < 10)
        sb_add("0");
    sb_num(n);
}

void sb_stamp(const stamp_t *w)
{
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
