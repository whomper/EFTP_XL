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
    new_when.mon = f && *m ? (f - months) / 3 + 1 : 0;
    new_when.day = atoi(day);
    if (t[2] == ':') {
        new_when.year = NO;
        new_when.hour = atoi(t);
        new_when.min = atoi(t + 3);
    } else {
        new_when.year = atoi(t) % 100;
        new_when.hour = NO;
    }
}

void __fastcall__ remote_add_line(char *s)
{
    char *f[9], *name, *arrow;
    unsigned char i;

    if (s[0] >= '0' && s[0] <= '9') {
        /* DOS: date, time, <DIR> or size, name */
        f[0] = s;
        for (i = 1; i < 4; ++i)
            if (!(f[i] = skip(f[i - 1])))
                return;
        name = f[3];
        if (!strncmp(f[2], "<DIR>", 5))
            new_flags = E_DIR;
        else
            new_size = atol(f[2]);
        /* "10-15-26": month first */
        new_when.mon = atoi(f[0]);
        new_when.day = atoi(f[0] + 3);
        new_when.year = atoi(f[0] + 6);
        new_when.hour = NO;
    } else if (s[0] == '-' || s[0] == 'd' || s[0] == 'l') {
        f[0] = s;
        for (i = 1; i < 9; ++i)
            if (!(f[i] = skip(f[i - 1])))
                return;
        name = f[8];
        if (s[0] == 'd')
            new_flags = E_DIR;
        else
            new_size = atol(f[4]);
        unix_date(f[5], f[6], f[7]);
        if (s[0] == 'l' && (arrow = strstr(name, " -> ")) != NULL)
            *arrow = '\0';          /* the link, not where it points */
    } else
        return;

    if (!strcmp(name, ".") || !strcmp(name, "..")) {
        new_flags = 0;
        new_size = 0;
        new_when.day = 0;
        return;
    }
    pane_add(name);
}

int remote_read(void)
{
    int r;

    pane_use(REMOTE);
    pane_clear();
    if ((r = ftp_pwd(p_path[REMOTE], PATH_LEN)) != 0)
        return r;
    if (strcmp(p_path[REMOTE], "/")) {
        new_flags = E_UP;
        pane_add("..");
    }
    r = ftp_list(remote_add_line);
    pane_use(REMOTE);
    pane_sort();
    return r;
}
