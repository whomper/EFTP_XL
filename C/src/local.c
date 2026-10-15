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
unsigned int cio_got;

static char line[64];
static char spec[PATH_LEN + 4];
static char name[13];
static unsigned char sparta;

static unsigned char __fastcall__ io(unsigned char command)
{
    IO->command = command;
    return cio(LOCAL_IOCB);
}

static void __fastcall__ io_buf(const void *buf)
{
    IO->buffer = (void *)buf;
}

unsigned char cio_open(const char *s, unsigned char aux1)
{
    cio_close();
    io_buf(s);
    IO->buflen = strlen(s);
    IO->aux1 = aux1;
    IO->aux2 = 0;
    return io(3);
}

unsigned char cio_getline(char *buf, unsigned int len)
{
    unsigned char st;
    unsigned int n;

    io_buf(buf);
    IO->buflen = len - 1;
    st = io(5);
    n = IO->buflen;
    if (n && buf[n - 1] == (char)0x9B)
        --n;
    buf[n] = '\0';
    return st;
}

unsigned char __fastcall__ cio_putline(const char *s)
{
    static char out[200];
    unsigned int n = strlen(s);

    if (n > sizeof(out) - 1)
        n = sizeof(out) - 1;
    memcpy(out, s, n);
    out[n] = (char)0x9B;
    io_buf(out);
    IO->buflen = n + 1;
    return io(9);
}

unsigned char cio_read(void *buf, unsigned int len)
{
    unsigned char st;

    io_buf(buf);
    IO->buflen = len;
    st = io(7);
    cio_got = IO->buflen;
    return st;
}

unsigned char cio_write(const void *buf, unsigned int len)
{
    io_buf(buf);
    IO->buflen = len;
    return io(11);
}

unsigned char cio_xio(unsigned char cmd, const char *s)
{
    cio_close();
    io_buf(s);
    IO->buflen = strlen(s);
    IO->aux1 = IO->aux2 = 0;
    return io(cmd);
}

void cio_close(void)
{
    io(12);
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

/* name = b (to a space, at most 8) "." ext (to a space, at most 3) */
static void make_name(const char *b, const char *ext)
{
    unsigned char n = 0, m = 0;

    while (n < 8 && b[n] > ' ')
        name[n] = b[n], ++n;
    if (ext && *ext > ' ') {
        name[n++] = '.';
        while (m < 3 && ext[m] > ' ')
            name[n++] = ext[m++];
    }
    name[n] = '\0';
}

static void __fastcall__ add_line(char *s)
{
    char *w[4];
    unsigned char n, i = 1;

    if (strstr(s, "FREE SECTORS")) {
        local_free = atoi(s);
        return;
    }
    if (!sparta) {
        /* DOS 2: lock flag, space, name in 8 columns, extension in 3
           right after it, space, sectors: "* STARRAIDXEX 012" */
        if (strlen(s) < 14 || s[1] != ' ')
            return;
        make_name(s + 2, s + 10);
        new_size = atol(s + 14) * SECTOR;
        pane_add(name);
        return;
    }
    if (!strncmp(s, "Volume", 6) || !strncmp(s, "Directory", 9)
        || !(n = words(s, w, 4)))
        return;
    /* SpartaDOS: NAME [EXT] size|<DIR> date */
    make_name(w[0], i < n && w[1][0] != '<' && !isdigit(w[1][0])
                    ? w[i++] : 0);
    if (i < n && w[i][0] == '<')
        new_flags = E_DIR;
    else if (i < n)
        new_size = atol(w[i]);
    if (++i < n) {
        /* "12-03-89" */
        new_when.day = atoi(w[i]);
        new_when.mon = atoi(w[i] + 3);
        new_when.year = atoi(w[i] + 6);
        new_when.hour = NO;
    }
    pane_add(name);
}

#define path p_path[LOCAL]

unsigned char local_read(void)
{
    unsigned char st, first = 1;

    pane_use(LOCAL);
    pane_clear();
    local_free = 0;
    sparta = 0;
    if (strchr(path, '>')) {
        new_flags = E_UP;
        pane_add("..");
    }
    strcpy(spec, path);
    strcat(spec, "*.*");
    st = cio_open(spec, 6);
    if (st >= 128) {
        cio_close();
        return st;
    }
    while ((st = cio_getline(line, sizeof(line))) < 128) {
        if (first && !strncmp(line, "Volume", 6))
            sparta = 1;
        first = 0;
        add_line(line);
    }
    cio_close();
    pane_sort();
    return st == 136 ? 1 : st;
}

void __fastcall__ local_into(const char *dir)
{
    if (!strchr(path, '>'))
        strcat(path, ">");
    if (strlen(path) + strlen(dir) + 2 < PATH_LEN) {
        strcat(path, dir);
        strcat(path, ">");
    }
}

unsigned char local_up(void)
{
    char *s = path + strlen(path) - 1;      /* the trailing '>' */

    if (!strchr(path, '>'))
        return 0;
    while (s > path && *--s != '>')
        ;
    if (s[-1] == ':')
        s[0] = '\0';        /* back to "D1:" */
    else
        s[1] = '\0';
    return 1;
}

void __fastcall__ local_drive(unsigned char n)
{
    path[0] = 'D';
    path[1] = '0' + n;
    path[2] = ':';
    path[3] = '\0';
}
