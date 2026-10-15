/*
 * EFTP_XL - the Atari side
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * A directory is read the way DOS's own DIR does, opening "Dn:...*.*"
 * with aux1 = 6 and reading the lines:
 *
 *   DOS 2.5    "* NAME     EXT 012"    (lock flag, name, sectors)
 *              "609 FREE SECTORS"
 *   SpartaDOS  "Volume:    ..."  "Directory: ..."  (header)
 *              "NAME     EXT    1234 12-03-89 12:00"   (bytes)
 *              "GAMES        <DIR>  12-03-89 12:00"
 *              "  708 FREE SECTORS"
 *
 * The lines are taken apart by words, so small differences between DOS
 * versions don't matter.
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <atari.h>

#include "local.h"

#define IO      ((iocb_t *)(0x340 + LOCAL_IOCB))
#define SECTOR  125         /* data bytes in a DOS 2 sector */

unsigned int local_free;

static char line[64];
static char spec[PATH_LEN + 4];
static char name[13];
static stamp_t when;

unsigned char cio_open(const char *s, unsigned char aux1, unsigned char aux2)
{
    cio_close();
    IO->command = 3;
    IO->buffer = (void *)s;
    IO->buflen = strlen(s);
    IO->aux1 = aux1;
    IO->aux2 = aux2;
    return cio(LOCAL_IOCB);
}

unsigned char cio_getline(char *buf, unsigned int len)
{
    unsigned char st;
    unsigned int n;

    IO->command = 5;
    IO->buffer = buf;
    IO->buflen = len - 1;
    st = cio(LOCAL_IOCB);
    n = IO->buflen;
    if (n && buf[n - 1] == (char)0x9B)
        --n;
    buf[n] = '\0';
    return st;
}

unsigned char cio_putline(const char *s)
{
    static char out[200];
    unsigned int n = strlen(s);

    if (n > sizeof(out) - 1)
        n = sizeof(out) - 1;
    memcpy(out, s, n);
    out[n] = (char)0x9B;
    IO->command = 9;
    IO->buffer = out;
    IO->buflen = n + 1;
    return cio(LOCAL_IOCB);
}

unsigned char cio_read(void *buf, unsigned int len, unsigned int *got)
{
    unsigned char st;

    IO->command = 7;
    IO->buffer = buf;
    IO->buflen = len;
    st = cio(LOCAL_IOCB);
    *got = IO->buflen;
    return st;
}

unsigned char cio_write(const void *buf, unsigned int len)
{
    IO->command = 11;
    IO->buffer = (void *)buf;
    IO->buflen = len;
    return cio(LOCAL_IOCB);
}

unsigned char cio_xio(unsigned char cmd, const char *spec)
{
    cio_close();
    IO->command = cmd;
    IO->buffer = (void *)spec;
    IO->buflen = strlen(spec);
    IO->aux1 = IO->aux2 = 0;
    return cio(LOCAL_IOCB);
}

void cio_close(void)
{
    IO->command = 12;
    cio(LOCAL_IOCB);
}

/* Split s into words (in place); returns how many, at most max. */
static unsigned char words(char *s, char **w, unsigned char max)
{
    unsigned char n = 0;

    for (;;) {
        while (*s == ' ')
            ++s;
        if (!*s || n == max)
            return n;
        w[n++] = s;
        while (*s && *s != ' ')
            ++s;
        if (*s)
            *s++ = '\0';
    }
}

static void add_line(pane_t *p, char *s, unsigned char sparta)
{
    char *w[6];
    unsigned char n, i = 1, flags = 0;
    unsigned long size = 0;

    if (!strncmp(s, "Volume", 6) || !strncmp(s, "Directory", 9))
        return;
    if (strstr(s, "FREE SECTORS")) {
        while (*s == ' ')
            ++s;
        local_free = atoi(s);
        return;
    }
    if (!sparta) {
        /* DOS 2: lock flag, space, name in 8 columns, extension in 3
           right after it, space, sectors: "* STARRAIDXEX 012" */
        if (strlen(s) < 14 || s[1] != ' ')
            return;
        for (n = 0; n < 8 && s[2 + n] != ' '; ++n)
            name[n] = s[2 + n];
        name[n] = '\0';
        if (s[10] != ' ') {
            i = strlen(name);
            name[i++] = '.';
            for (n = 0; n < 3 && s[10 + n] != ' '; ++n)
                name[i++] = s[10 + n];
            name[i] = '\0';
        }
        pane_add(p, name, atol(s + 14) * SECTOR, 0, 0);
        return;
    }
    n = words(s, w, 6);
    if (!n)
        return;

    strncpy(name, w[0], 8);
    name[8] = '\0';
    if (i < n && strcmp(w[i], "<DIR>") && !isdigit(w[i][0])) {
        strcat(name, ".");
        strncat(name, w[i], 3);
        ++i;
    }
    when.day = 0;
    if (i < n && !strcmp(w[i], "<DIR>")) {
        flags = E_DIR;
        ++i;
    } else if (i < n) {
        size = atol(w[i++]);
        if (!sparta)
            size *= SECTOR;
    }
    if (i < n) {
        /* "12-03-89" */
        when.day = atoi(w[i]);
        when.mon = atoi(w[i] + 3);
        when.year = atoi(w[i] + 6);
        when.hour = NO;
    }
    pane_add(p, name, size, &when, flags);
}

unsigned char local_read(pane_t *p)
{
    unsigned char st, sparta = 0, first = 1;

    pane_clear(p);
    local_free = 0;
    if (strchr(p->path, '>'))
        pane_add(p, "..", 0, 0, E_UP);

    strcpy(spec, p->path);
    strcat(spec, "*.*");
    st = cio_open(spec, 6, 0);
    if (st >= 128) {
        cio_close();
        return st;
    }
    while ((st = cio_getline(line, sizeof(line))) < 128) {
        if (first && !strncmp(line, "Volume", 6))
            sparta = 1;
        first = 0;
        add_line(p, line, sparta);
    }
    cio_close();
    pane_sort(p);
    return st == 136 ? 1 : st;
}

void local_into(pane_t *p, const char *dir)
{
    if (!strchr(p->path, '>'))
        strcat(p->path, ">");
    if (strlen(p->path) + strlen(dir) + 2 < PATH_LEN) {
        strcat(p->path, dir);
        strcat(p->path, ">");
    }
}

unsigned char local_up(pane_t *p)
{
    char *s = p->path + strlen(p->path) - 1;   /* the trailing '>' */

    if (!strchr(p->path, '>'))
        return 0;
    while (s > p->path && *--s != '>')
        ;
    if (s[-1] == ':')
        s[0] = '\0';        /* back to "D1:" */
    else
        s[1] = '\0';
    return 1;
}

void local_drive(pane_t *p, unsigned char n)
{
    p->path[0] = 'D';
    p->path[1] = '0' + n;
    p->path[2] = ':';
    p->path[3] = '\0';
}
