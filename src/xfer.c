/*
 * EFTP_XL - sending files
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * As in EFTP: the files go one after the other, the transfers area
 * shows them (Done, Waiting, a progress bar for the one going), the info
 * line what is happening, and ESC stops. A file going to the Atari gets
 * an 8.3 name (STinG 1.26.zip -> STING126.ZIP); one already there is
 * replaced only when you say so. Text files have their line ends
 * changed (CR LF on the server, EOL on the Atari) when the site says
 * Text, or By type and the name ends in one of EFTP's text types.
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <conio.h>
#include <atari.h>

#include "screen.h"
#include "pane.h"
#include "local.h"
#include "ftp.h"
#include "sites.h"
#include "ui.h"
#include "xfer.h"

#define BUF         512
#define BAR         16      /* progress bar cells */
#define MAX_QUEUE   64

#define CR          0x0D
#define LF          0x0A
#define TAB         0x09
#define EOL         0x9B
#define ATAB        0x7F

#define buf ftp_buf
static char spec[PATH_LEN + 13];
static char aname[13];
static char line[40];
static char summary[39];
static char error[39];          /* why the last file that failed did */

static pane_t *src;
static unsigned char down;
static unsigned char queue[MAX_QUEUE], count, cur, first;
static unsigned long file_size, file_done, total_done;
static unsigned long t_start;
static unsigned char stop;

/* EFTP's text types, and BASIC listings */
static const char text_types[] = " TXT ASC DOC ME NFO DIZ HTM HTML INF LST ";

static unsigned long ticks(void)
{
    return OS.rtclok[2] | (OS.rtclok[1] << 8)
         | ((unsigned long)OS.rtclok[0] << 16);
}

static unsigned char hz(void)
{
    return (GTIA_READ.pal & 0x0E) ? 60 : 50;
}

static unsigned char is_text(const char *name, unsigned char mode)
{
    const char *dot = strrchr(name, '.');
    char ext[7];
    unsigned char i;

    if (mode != MODE_BYTYPE)
        return mode == MODE_TEXT;
    if (!dot || strlen(dot + 1) > 4 || !dot[1])
        return 0;
    ext[0] = ' ';
    for (i = 1; dot[i]; ++i)
        ext[i] = toupper(dot[i]);
    ext[i++] = ' ';
    ext[i] = '\0';
    return strstr(text_types, ext) != NULL;
}

/* A name DOS takes: up to 8 letters and digits, a letter first, and up
   to 3 for the extension, in capitals. */
static void atari_name(const char *s, char *out)
{
    const char *dot = strrchr(s, '.');
    unsigned char n = 0, m = 0;

    if (!isalpha(*s))
        out[n++] = 'F';
    for (; *s && s != dot && n < 8; ++s)
        if (isalnum(*s))
            out[n++] = toupper(*s);
    if (dot) {
        out[n++] = '.';
        for (++dot; *dot && m < 3; ++dot)
            if (isalnum(*dot))
                out[n + m++] = toupper(*dot);
        if (!m)
            --n;
        n += m;
    }
    out[n] = '\0';
}

/* -- the line ends of text files */

/* server -> Atari, in place: CR LF -> EOL, TAB -> Atari TAB */
static unsigned int to_atari(unsigned int n)
{
    unsigned int i, o = 0;
    unsigned char c;

    for (i = 0; i < n; ++i) {
        c = buf[i];
        if (c == CR)
            continue;
        buf[o++] = c == LF ? EOL : c == TAB ? ATAB : c;
    }
    return o;
}

/* Atari -> server: n bytes at buf + BUF/2 become CR LF text from buf */
static unsigned int to_server(unsigned int n)
{
    unsigned char *in = buf + BUF / 2;
    unsigned int i, o = 0;
    unsigned char c;

    for (i = 0; i < n; ++i) {
        c = in[i];
        if (c == EOL) {
            buf[o++] = CR;
            buf[o++] = LF;
        } else
            buf[o++] = c == ATAB ? TAB : c;
    }
    return o;
}

/* -- showing it */

static const char *shown_name(entry_t *e)
{
    if (!down)
        return e->name;
    atari_name(e->name, aname);
    return aname;
}

static void draw_row(unsigned char row, unsigned char i)
{
    entry_t *e = &src->ent[queue[i]];
    unsigned char c = SCR_L + 15, fill;
    char size[6];

    scr_clear(row, row);
    scr_ch(row, SCR_L, down ? CH_DOWN : CH_UP, 0);
    scr_putw(row, SCR_L + 2, shown_name(e), 12, 0);
    if (i == cur && !(e->flags & (E_DONE | E_FAIL | E_SKIP))) {
        fill = file_size ? (unsigned char)(file_done * BAR / file_size) : 0;
        if (fill > BAR)
            fill = BAR;
        scr_fill(row, c, ' ', fill, 1);
        scr_fill(row, c + fill, CH_SHADE, BAR - fill, 0);
        fill = file_size ? (unsigned char)(file_done * 100 / file_size) : 0;
        utoa(fill > 99 ? 99 : fill, size, 10);
        strcat(size, "%");
        scr_put(row, SCR_R - 3, size, 0);
        return;
    }
    scr_put(row, c, (e->flags & E_DONE) ? "Done"
                  : (e->flags & E_FAIL) ? (stop && i == cur ? "Stopped"
                                                            : "Failed")
                  : (e->flags & E_SKIP) ? "Skipped" : "Waiting", 0);
    fmt_size(e->size, size);
    scr_put(row, SCR_R + 1 - strlen(size), size, 0);
}

static void draw_queue(void)
{
    unsigned char r;

    first = cur ? cur - 1 : 0;
    if (count > XFER_ROWS && first > count - XFER_ROWS)
        first = count - XFER_ROWS;
    if (count <= XFER_ROWS)
        first = 0;
    for (r = 0; r < XFER_ROWS; ++r) {
        if (first + r < count)
            draw_row(XFER_ROW + 1 + r, first + r);
        else
            scr_clear(XFER_ROW + 1 + r, XFER_ROW + 1 + r);
    }
    sb_start(line);
    sb_add(" ");
    sb_num(cur + 1 > count ? count : cur + 1);
    sb_add(" of ");
    sb_num(count);
    sb_add(" ");
    scr_fill(XFER_ROW, SCR_R - 10, CH_HLINE, 11, 0);
    scr_put(XFER_ROW, SCR_R - strlen(line) + 1, line, 0);
}

/* "3K/s" so far */
static void sb_rate(void)
{
    unsigned long t = ticks() - t_start;

    sb_size(total_done * hz() / (t ? t : 1));
    sb_add(total_done * hz() / (t ? t : 1) < 1000 ? "B/s" : "/s");
}

static void progress(entry_t *e)
{
    sb_start(line);
    sb_add(down ? "\x1D " : "\x1C ");
    sb_add(shown_name(e));
    sb_add(" ");
    sb_size(file_done);
    sb_add("/");
    sb_size(file_size);
    sb_add(" ");
    sb_rate();
    ui_info(line);
    draw_row(XFER_ROW + 1 + cur - first, cur);
}

/* ESC pressed? */
static unsigned char esc(void)
{
    return kbhit() && key_get() == K_ESC;
}

static void say_error(const char *what, int r)
{
    sb_start(error);
    sb_add(what);
    sb_add(": ");
    if (r == FTP_ERR_TIMEOUT)
        sb_add("no answer");
    else if (r == FTP_ERR_CLOSED)
        sb_add("connection lost");
    else {
        ftp_msg[sizeof(error) - 12] = '\0';
        sb_add(ftp_msg);
    }
    ui_info(error);
}

static void say_cio(unsigned char st)
{
    const char *n = strrchr(spec, '>');

    if (!n)
        n = strchr(spec, ':');
    sb_start(error);
    sb_add(n ? n + 1 : spec);
    sb_add(": error ");
    sb_num(st);
    ui_info(error);
}

/* Is name in p? Then ask; 0: leave it (or ESC: stop). */
static unsigned char may_replace(pane_t *p, const char *name)
{
    unsigned char i, k;

    for (i = 0; i < p->count; ++i)
        if (!strcmp(p->ent[i].name, name))
            break;
    if (i == p->count)
        return 1;
    sb_start(line);
    sb_add(name);
    sb_add(" is there. Replace? Y/N");
    ui_info(line);
    k = key_get();
    if (k == K_ESC)
        stop = 1;
    return k == 'Y' || k == 'y';
}

/* -- one file each way; they return E_DONE, E_FAIL or E_SKIP */

static unsigned char get_file(entry_t *e, pane_t *local, unsigned char text)
{
    int n = 0, r;
    unsigned char st = 1;
    unsigned int out;

    atari_name(e->name, aname);
    if (!may_replace(local, aname))
        return E_SKIP;
    strcpy(spec, local->path);
    strcat(spec, aname);
    if ((r = ftp_retr(e->name)) != 0) {
        say_error("Download", r);
        return E_FAIL;
    }
    if ((st = cio_open(spec, 8, 0)) >= 128) {
        cio_close();
        ftp_abort();
        say_cio(st);
        return E_FAIL;
    }
    for (;;) {
        n = ftp_read(buf, BUF);
        if (n <= 0)
            break;
        out = text ? to_atari(n) : n;
        if (out && (st = cio_write(buf, out)) >= 128)
            break;
        file_done += n;
        total_done += n;
        progress(e);
        if (esc()) {
            stop = 1;
            break;
        }
    }
    cio_close();
    if (n == 0 && st < 128) {
        if ((r = ftp_done()) == 0)
            return E_DONE;
        say_error("Download", r);
    } else {
        ftp_abort();
        if (st >= 128)
            say_cio(st);
        else if (n < 0)
            say_error("Download", -n);
    }
    cio_xio(33, spec);          /* no half files on the disk */
    return E_FAIL;
}

static unsigned char put_file(entry_t *e, pane_t *local, pane_t *remote,
                              unsigned char text)
{
    unsigned char st;
    unsigned int got, n;
    int r = 0;

    if (!may_replace(remote, e->name))
        return E_SKIP;
    strcpy(spec, local->path);
    strcat(spec, e->name);
    if ((st = cio_open(spec, 4, 0)) >= 128) {
        cio_close();
        say_cio(st);
        return E_FAIL;
    }
    if ((r = ftp_stor(e->name)) != 0) {
        cio_close();
        say_error("Upload", r);
        return E_FAIL;
    }
    for (;;) {
        st = cio_read(text ? buf + BUF / 2 : buf, text ? BUF / 2 : BUF, &got);
        if (got) {
            n = text ? to_server(got) : got;
            if ((r = ftp_write(buf, n)) != 0)
                break;
            file_done += got;
            total_done += got;
            progress(e);
        }
        if (st >= 128)
            break;
        if (esc()) {
            stop = 1;
            break;
        }
    }
    cio_close();
    if (st == 136 && !r) {
        if ((r = ftp_done()) == 0)
            return E_DONE;
        say_error("Upload", r);
        return E_FAIL;
    }
    ftp_abort();
    if (r)
        say_error("Upload", r);
    else if (st >= 128)
        say_cio(st);
    return E_FAIL;
}

unsigned char xfer_send(pane_t *local, pane_t *remote, unsigned char to_atari_,
                        unsigned char mode, unsigned char cursor_only)
{
    unsigned char i, n_ok = 0, result;
    unsigned long secs;
    entry_t *e;

    down = to_atari_;
    src = down ? remote : local;
    count = cur = 0;
    stop = 0;
    error[0] = '\0';
    for (i = 0; i < src->count && count < MAX_QUEUE && !cursor_only; ++i)
        if ((src->ent[i].flags & (E_MARK | E_DIR)) == E_MARK)
            queue[count++] = i;
    if (!count && src->count
        && !(src->ent[src->cur].flags & (E_DIR | E_UP)))
        queue[count++] = src->cur;
    if (!count) {
        ui_info("Mark files with SPACE, or put the cursor on one.");
        return 0;
    }
    for (i = 0; i < count; ++i)
        src->ent[queue[i]].flags |= E_QUEUED;

    total_done = 0;
    t_start = ticks();
    for (cur = 0; cur < count && !stop; ++cur) {
        e = &src->ent[queue[cur]];
        file_size = e->size;
        file_done = 0;
        draw_queue();
        progress(e);
        result = down ? get_file(e, local, is_text(e->name, mode))
                      : put_file(e, local, remote, is_text(e->name, mode));
        e->flags = (e->flags & ~E_MARK) | result;
        if (result == E_DONE)
            ++n_ok;
        draw_queue();
    }
    if (cur > count)
        cur = count;

    /* "2 of 3 files, 260K in 0:42 (6K/s)" */
    secs = (ticks() - t_start) / hz();
    sb_start(summary);
    if (n_ok != count) {
        sb_num(n_ok);
        sb_add(" of ");
    }
    sb_num(count);
    sb_add(count == 1 ? " file, " : " files, ");
    sb_size(total_done);
    sb_add(" in ");
    sb_num(secs / 60);
    sb_add(secs % 60 < 10 ? ":0" : ":");
    sb_num(secs % 60);
    sb_add(" (");
    sb_rate();
    sb_add(")");
    /* the reason a file failed is worth more than the sums */
    ui_info(stop ? "Stopped." : error[0] ? error : summary);
    return 1;
}

void xfer_draw(void)
{
    if (summary[0]) {
        scr_put(XFER_ROW + 1, SCR_L, summary, 0);
        return;
    }
    scr_put(XFER_ROW + 1, SCR_L, "Nothing yet. RETURN sends a file,", 0);
    scr_put(XFER_ROW + 2, SCR_L, "SPACE marks several, ^T sends them.", 0);
}
