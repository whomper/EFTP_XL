/*
 * EFTP_XL - the server side
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * LIST has no standard format; the two seen in practice are
 *
 *   Unix   "drwxr-xr-x  2 user group  4096 Oct 15 15:20 games"
 *          "-rw-r--r--  1 user group 249856 Apr 22  2024 STinG 1.26.zip"
 *   DOS    "10-15-26  03:33PM       <DIR>          games"
 *          "10-15-26  03:33PM               14336 index.html"
 *
 * Anything else is left out.
 */

#include <stdlib.h>
#include <string.h>

#include "ftp.h"
#include "remote.h"

static pane_t *target;
static stamp_t when;

static const char months[] = "JanFebMarAprMayJunJulAugSepOctNovDec";

/* The start of the next word after s, or 0. */
static char *skip(char *s)
{
    while (*s && *s != ' ')
        ++s;
    while (*s == ' ')
        ++s;
    return *s ? s : 0;
}

static void word(char *dst, const char *s, unsigned char max)
{
    while (*s && *s != ' ' && --max)
        *dst++ = *s++;
    *dst = '\0';
}

/* "Oct 15 15:20" (this year) or "Apr 22 2024" */
static void unix_date(char *mon, char *day, char *t)
{
    char m[4], *f;

    word(m, mon, sizeof(m));
    f = strstr(months, m);
    when.mon = f && *m ? (f - months) / 3 + 1 : 0;
    when.day = atoi(day);
    if (t[2] == ':') {
        when.year = NO;
        when.hour = atoi(t);
        when.min = atoi(t + 3);
    } else {
        when.year = atoi(t) % 100;
        when.hour = NO;
    }
}

void remote_add_line(pane_t *p, char *s)
{
    char *f[9], *name, *arrow;
    unsigned char i, flags = 0;
    unsigned long size = 0;

    if (s[0] >= '0' && s[0] <= '9') {
        /* DOS: date, time, <DIR> or size, name */
        f[0] = s;
        for (i = 1; i < 4; ++i)
            if (!(f[i] = skip(f[i - 1])))
                return;
        name = f[3];
        if (!strncmp(f[2], "<DIR>", 5))
            flags = E_DIR;
        else
            size = atol(f[2]);
        /* "10-15-26": month first */
        when.mon = atoi(f[0]);
        when.day = atoi(f[0] + 3);
        when.year = atoi(f[0] + 6);
        when.hour = NO;
    } else if (s[0] == '-' || s[0] == 'd' || s[0] == 'l') {
        f[0] = s;
        for (i = 1; i < 9; ++i)
            if (!(f[i] = skip(f[i - 1])))
                return;
        name = f[8];
        if (s[0] == 'd')
            flags = E_DIR;
        else
            size = atol(f[4]);
        unix_date(f[5], f[6], f[7]);
        if (s[0] == 'l' && (arrow = strstr(name, " -> ")) != NULL)
            *arrow = '\0';          /* the link, not where it points */
    } else
        return;

    if (!strcmp(name, ".") || !strcmp(name, ".."))
        return;
    pane_add(p, name, size, &when, flags);
}

static void add(char *line)
{
    remote_add_line(target, line);
}

int remote_read(pane_t *p)
{
    int r;

    pane_clear(p);
    if ((r = ftp_pwd(p->path, PATH_LEN)) != 0)
        return r;
    if (strcmp(p->path, "/"))
        pane_add(p, "..", 0, 0, E_UP);
    target = p;
    r = ftp_list(add);
    pane_sort(p);
    return r;
}
