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
                  const char *date, unsigned char flags)
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
    strncpy(e->date, date ? date : "", DATE_LEN - 1);
    e->date[DATE_LEN - 1] = '\0';
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
    qsort(p->ent, p->count, sizeof(entry_t), compare);
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
