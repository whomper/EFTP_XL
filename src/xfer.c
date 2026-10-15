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

static unsigned char down, text, stop;
static unsigned char queue[MAX_QUEUE], count, cur, first;
static unsigned char k;         /* the entry going */
static unsigned long file_size, file_done, total_done;
static unsigned long t_start;

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

static unsigned char __fastcall__ is_text(unsigned char mode)
{
    const char *dot = strrchr(e_name[k], '.');
    char ext[7];
    unsigned char i;

    if (mode != MODE_BYTYPE)
        return mode == MODE_TEXT;
    if (!dot || !dot[1] || strlen(dot + 1) > 4)
        return 0;
    ext[0] = ' ';
    for (i = 1; dot[i]; ++i)
        ext[i] = toupper(dot[i]);
    ext[i++] = ' ';
    ext[i] = '\0';
    return strstr(text_types, ext) != NULL;
}

/* aname = a name DOS takes for entry j: up to 8 letters and digits, a
   letter first, and up to 3 for the extension, in capitals */
static void __fastcall__ atari_name(unsigned char j)
{
    const char *s = e_name[j], *dot = strrchr(s, '.');
    unsigned char n = 0, m = 0;

    if (!isalpha(*s))
        aname[n++] = 'F';
    for (; *s && s != dot && n < 8; ++s)
        if (isalnum(*s))
            aname[n++] = toupper(*s);
    if (dot) {
        aname[n++] = '.';
        for (++dot; *dot && m < 3; ++dot)
            if (isalnum(*dot))
                aname[n + m++] = toupper(*dot);
        if (!m)
            --n;
        n += m;
    }
    aname[n] = '\0';
}

/* the name entry j has on the screen: its Atari name going down */
static const char *__fastcall__ shown(unsigned char j)
{
    if (!down)
        return e_name[j];
    atari_name(j);
    return aname;
}

/* -- the line ends of text files */

/* server -> Atari, in place: CR LF -> EOL, TAB -> Atari TAB */
static unsigned int __fastcall__ to_atari(unsigned int n)
{
    unsigned char *in = buf, *out = buf, c;

    for (; n; --n) {
        c = *in++;
        if (c != CR)
            *out++ = c == LF ? EOL : c == TAB ? ATAB : c;
    }
    return out - buf;
}

/* Atari -> server: n bytes at buf + BUF/2 become CR LF text from buf */
static unsigned int __fastcall__ to_server(unsigned int n)
{
    unsigned char *in = buf + BUF / 2, *out = buf, c;

    for (; n; --n) {
        c = *in++;
        if (c == EOL) {
            *out++ = CR;
            *out++ = LF;
        } else
            *out++ = c == ATAB ? TAB : c;
    }
    return out - buf;
}

/* -- showing it */

static void __fastcall__ draw_row(unsigned char i)
{
    unsigned char j = queue[i], f = e_flags[j], fill;
    char size[6];

    AT(XFER_ROW + 1 + i - first, SCR_L);
    scr_clear(scr_row);
    scr_char(down ? CH_DOWN : CH_UP);
    ++scr_col;
    scr_w = 12;
    scr_putw(shown(j));
    ++scr_col;
    if (i == cur && !(f & (E_DONE | E_FAIL | E_SKIP))) {
        fill = file_size ? (unsigned char)(file_done * BAR / file_size) : 0;
        if (fill > BAR)
            fill = BAR;
        scr_w = fill;
        scr_inv = 1;
        scr_rep(' ');
        scr_inv = 0;
        scr_w = BAR - fill;
        scr_rep(CH_SHADE);
        fill = file_size ? (unsigned char)(file_done * 100 / file_size) : 0;
        utoa(fill > 99 ? 99 : fill, size, 10);
        strcat(size, "%");
    } else {
        scr_puts((f & E_DONE) ? "Done"
                 : (f & E_FAIL) ? (stop && i == cur ? "Stopped" : "Failed")
                 : (f & E_SKIP) ? "Skipped" : "Waiting");
        fmt_n = e_size[j];
        fmt_size(size);
    }
    scr_col = SCR_R + 1 - strlen(size);
    scr_puts(size);
}

static void draw_queue(void)
{
    unsigned char r;

    first = cur ? cur - 1 : 0;
    if (count <= XFER_ROWS)
        first = 0;
    else if (first > count - XFER_ROWS)
        first = count - XFER_ROWS;
    for (r = first; r < first + XFER_ROWS; ++r)
        if (r < count)
            draw_row(r);
        else
            scr_clear(XFER_ROW + 1 + r - first);
    sb_start(line);
    sb_add(" ");
    sb_num(cur + 1 > count ? count : cur + 1);
    sb_add(" of ");
    sb_num(count);
    sb_add(" ");
    AT(XFER_ROW, SCR_R - 10);
    scr_w = 11;
    scr_rep(CH_HLINE);
    scr_col = SCR_R + 1 - strlen(line);
    scr_puts(line);
}

/* "3K/s" so far */
static void sb_rate(void)
{
    unsigned long t = ticks() - t_start;
    unsigned long r = total_done * hz() / (t ? t : 1);

    sb_size(r);
    sb_add(r < 1000 ? "B/s" : "/s");
}

static void progress(void)
{
    sb_start(line);
    sb_add(down ? "\x1D " : "\x1C ");
    sb_add(shown(k));
    sb_add(" ");
    sb_size(file_done);
    sb_add("/");
    sb_size(file_size);
    sb_add(" ");
    sb_rate();
    ui_info(line);
    draw_row(cur);
}

/* the bytes of a block moved: count them, show them; 1 when ESC */
static unsigned char __fastcall__ moved(unsigned int n)
{
    file_done += n;
    total_done += n;
    progress();
    if (kbhit() && key_get() == K_ESC)
        stop = 1;
    return stop;
}

static void __fastcall__ say_error(const char *what, int r)
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

static void __fastcall__ say_cio(unsigned char st)
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

/* Is name in pane s? Then ask; 0: leave it (or ESC: stop). */
static unsigned char may_replace(unsigned char s, const char *name)
{
    unsigned char key;

    pane_use(s);
    if (pane_find(name) == NO)
        return 1;
    sb_start(line);
    sb_add(name);
    sb_add(" is there. Replace? Y/N");
    ui_info(line);
    key = key_get();
    if (key == K_ESC)
        stop = 1;
    return key == 'Y' || key == 'y';
}

/* spec = the Atari's folder + name */
static void __fastcall__ make_spec(const char *name)
{
    sb_start(spec);
    sb_add(p_path[LOCAL]);
    sb_add(name);
}

/* -- one file each way; they return E_DONE, E_FAIL or E_SKIP */

static unsigned char get_file(void)
{
    int n = 0, r;
    unsigned char st = 1;

    atari_name(k);
    if (!may_replace(LOCAL, aname))
        return E_SKIP;
    make_spec(aname);
    if ((r = ftp_retr(e_name[k])) != 0) {
        say_error("Download", r);
        return E_FAIL;
    }
    if ((st = cio_open(spec, 8)) >= 128) {
        cio_close();
        ftp_abort();
        say_cio(st);
        return E_FAIL;
    }
    while ((n = ftp_read(buf, BUF)) > 0) {
        r = text ? to_atari(n) : n;
        if (r && (st = cio_write(buf, r)) >= 128)
            break;
        if (moved(n))
            break;
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

static unsigned char put_file(void)
{
    unsigned char st;
    int r = 0;

    if (!may_replace(REMOTE, e_name[k]))
        return E_SKIP;
    make_spec(e_name[k]);
    if ((st = cio_open(spec, 4)) >= 128) {
        cio_close();
        say_cio(st);
        return E_FAIL;
    }
    if ((r = ftp_stor(e_name[k])) != 0) {
        cio_close();
        say_error("Upload", r);
        return E_FAIL;
    }
    for (;;) {
        st = cio_read(text ? buf + BUF / 2 : buf, text ? BUF / 2 : BUF);
        if (cio_got) {
            if ((r = ftp_write(buf, text ? to_server(cio_got) : cio_got)) != 0)
                break;
            if (moved(cio_got))
                break;
        }
        if (st >= 128)
            break;
    }
    cio_close();
    if (st == 136 && !r && !stop) {
        if ((r = ftp_done()) == 0)
            return E_DONE;
        say_error("Upload", r);
        return E_FAIL;
    }
    ftp_abort();
    if (r)
        say_error("Upload", r);
    else if (st >= 128 && st != 136)
        say_cio(st);
    return E_FAIL;
}

unsigned char xfer_send(unsigned char to_atari_, unsigned char mode,
                        unsigned char cursor_only)
{
    unsigned char n_ok = 0, result, src, end;
    unsigned long secs;

    down = to_atari_;
    src = down ? REMOTE : LOCAL;
    pane_use(src);
    count = cur = stop = 0;
    error[0] = '\0';
    end = base + p_count[src];
    if (!cursor_only)
        for (k = base; k < end && count < MAX_QUEUE; ++k)
            if ((e_flags[k] & (E_MARK | E_DIR)) == E_MARK)
                queue[count++] = k;
    k = base + p_cur[src];
    if (!count && p_count[src] && !(e_flags[k] & (E_DIR | E_UP)))
        queue[count++] = k;
    if (!count) {
        ui_info("Mark files with SPACE, or put the cursor on one.");
        return 0;
    }

    total_done = 0;
    t_start = ticks();
    for (cur = 0; cur < count && !stop; ++cur) {
        k = queue[cur];
        file_size = e_size[k];
        file_done = 0;
        text = is_text(mode);
        draw_queue();
        progress();
        result = down ? get_file() : put_file();
        e_flags[k] = (e_flags[k] & ~E_MARK) | result;
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
    AT(XFER_ROW + 1, SCR_L);
    if (summary[0]) {
        scr_puts(summary);
        return;
    }
    scr_puts("Nothing yet. RETURN sends a file,");
    AT(XFER_ROW + 2, SCR_L);
    scr_puts("SPACE marks several, ^T sends them.");
}
