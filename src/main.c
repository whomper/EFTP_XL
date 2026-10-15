/*
 * EFTP_XL - file transfer for 8-bit Ataris over FujiNet
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * The main screen, after EFTP on the ST: the Atari on the left, the
 * server on the right, the transfers below, the keys at the bottom;
 * in EDOS's font and colours.
 *
 *   0  title bar                         13  ...
 *   1  info line                    (o)  16  -------+-------
 *   2  -------------+------------        17  details of the cursor's file
 *   3  D1:>GAMES>   | /pub/atari         18  --- Transfers -------
 *   4  2 dirs 5 files| 2 dirs 5 files    19-21 transfers
 *   5-15 the files   | the files         22  ---------------
 *                                        23  keys
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "screen.h"
#include "pane.h"
#include "local.h"
#include "remote.h"
#include "ftp.h"
#include "sites.h"
#include "ui.h"

/* the last release; a release build (RELEASE=1) shows it as it is,
   any other "0.2-dev" */
#define VERSION     "0.2"
#ifdef RELEASE
#define APP_VERSION VERSION
#else
#define APP_VERSION VERSION "-dev"
#endif

#define DIV         19          /* the line between the panes */
#define HEAD_ROW    3
#define COUNT_ROW   4
#define LIST_ROW    5
#define VIS         11          /* files shown in a pane */
#define DETAIL_ROW  17
#define XFER_ROW    18
#define KEYS_ROW    23

#define MAX_LOCAL   64
#define MAX_REMOTE  64

#define LOCAL       0
#define REMOTE      1

static entry_t local_ent[MAX_LOCAL], remote_ent[MAX_REMOTE];
static char local_pool[1024], remote_pool[2048];
static pane_t pane[2];
static unsigned char active;
static unsigned char connected;
static signed char site = -1;

static char msg[64];
static char tmp[PATH_LEN];
static char pass[24];

static const unsigned char col0[2] = { SCR_L, DIV + 1 };
static const unsigned char width[2] = { DIV - SCR_L, SCR_R - DIV };

/* -- drawing */

void ui_info(const char *s)
{
    scr_putw(1, SCR_L, s, SCR_W - 1, 0);
    scr_ch(1, SCR_R, connected ? CH_DOT : ' ', 0);
}

static void draw_title(void)
{
    scr_fill(0, SCR_L, ' ', SCR_W, 1);
    scr_put(0, SCR_L + 1, "EFTP_XL " APP_VERSION, 1);
    scr_put(0, SCR_R - 13, "(C) AERA 2026", 1);
}

static void draw_keys(void)
{
    unsigned char c;

    scr_clear(KEYS_ROW, KEYS_ROW);
    c = scr_key(KEYS_ROW, SCR_L, "^K", "Sites");
    c = scr_key(KEYS_ROW, c, "^T", "Send");
    c = scr_key(KEYS_ROW, c, "TAB", "Pane");
    scr_key(KEYS_ROW, c, "HELP", "Keys");
}

static void draw_frame(void)
{
    unsigned char r;

    scr_clear(2, 22);
    scr_rule(2);
    scr_ch(2, DIV, CH_TT, 0);
    for (r = HEAD_ROW; r < LIST_ROW + VIS; ++r)
        scr_ch(r, DIV, CH_VLINE, 0);
    scr_rule(16);
    scr_ch(16, DIV, CH_BT, 0);
    scr_rule(XFER_ROW);
    scr_put(XFER_ROW, SCR_L + 1, " Transfers ", 0);
    scr_rule(22);
    scr_put(19, SCR_L, "Nothing yet. Sending files comes", 0);
    scr_put(20, SCR_L, "in the next version.", 0);
}

/* Fit s into w columns: the end of it if it's too long, after "..." */
static void put_tail(unsigned char row, unsigned char col, const char *s,
                     unsigned char w, unsigned char inv)
{
    unsigned char n = strlen(s);

    if (n <= w) {
        scr_putw(row, col, s, w, inv);
        return;
    }
    scr_ch(row, col, CH_MORE, inv);
    scr_putw(row, col + 1, s + n - (w - 1), w - 1, inv);
}

static void draw_entry(unsigned char side, unsigned char i)
{
    pane_t *p = &pane[side];
    unsigned char row = LIST_ROW + i - p->top;
    unsigned char c = col0[side], w = width[side], nw = w - 6, n, icon;
    unsigned char cur = side == active && i == p->cur;
    entry_t *e;
    char size[6];

    if (i >= p->count) {
        scr_fill(row, c, ' ', w, 0);
        return;
    }
    e = &p->ent[i];
    icon = (e->flags & E_UP) ? CH_UP : (e->flags & E_MARK) ? CH_MARK
         : (e->flags & E_DIR) ? CH_FOLDER : CH_FILE;
    scr_ch(row, c, icon, cur);
    n = strlen(e->name);
    if (n > nw) {
        scr_putw(row, c + 1, e->name, nw - 1, cur);
        scr_ch(row, c + nw, CH_MORE, cur);
    } else
        scr_putw(row, c + 1, e->name, nw, cur);
    size[0] = '\0';
    if (!(e->flags & (E_DIR | E_UP)))
        fmt_size(e->size, size);
    n = strlen(size);
    scr_fill(row, c + 1 + nw, ' ', 5 - n, cur);
    scr_putw(row, c + 6 + nw - n, size, n, cur);
}

static void draw_list(unsigned char side)
{
    pane_t *p = &pane[side];
    unsigned char i;

    for (i = p->top; i < p->top + VIS; ++i)
        draw_entry(side, i);
}

static void draw_details(void)
{
    pane_t *p = &pane[active];
    entry_t *e;
    unsigned char i, n = 0, c;
    unsigned long total = 0;
    char size[6];

    scr_clear(DETAIL_ROW, DETAIL_ROW);
    for (i = 0; i < p->count; ++i)
        if (p->ent[i].flags & E_MARK) {
            ++n;
            total += p->ent[i].size;
        }
    if (n) {
        utoa(n, msg, 10);
        strcat(msg, " marked, ");
        fmt_size(total, size);
        strcat(msg, size);
        scr_put(DETAIL_ROW, SCR_L, msg, 0);
        return;
    }
    if (!p->count)
        return;
    e = &p->ent[p->cur];
    if (e->flags & E_UP) {
        scr_put(DETAIL_ROW, SCR_L, "The folder above", 0);
        return;
    }
    scr_putw(DETAIL_ROW, SCR_L, e->name, 22, 0);
    c = SCR_L + (strlen(e->name) < 22 ? strlen(e->name) : 22) + 1;
    if (e->flags & E_DIR)
        c = scr_put(DETAIL_ROW, c, "folder", 0) + 1;
    else {
        fmt_size(e->size, size);
        c = scr_put(DETAIL_ROW, c, size, 0) + 1;
    }
    if (c + strlen(e->date) <= SCR_R + 1)
        scr_put(DETAIL_ROW, c, e->date, 0);
}

static void draw_pane(unsigned char side)
{
    pane_t *p = &pane[side];
    unsigned char c = col0[side], w = width[side], r;

    if (side == REMOTE && !connected) {
        scr_putw(HEAD_ROW, c, "Server", w, 0);
        for (r = COUNT_ROW; r < LIST_ROW + VIS; ++r)
            scr_fill(r, c, ' ', w, 0);
        scr_put(LIST_ROW + 2, c + 1, "Not connected.", 0);
        scr_put(LIST_ROW + 4, c + 1, "Press ^K to pick", 0);
        scr_put(LIST_ROW + 5, c + 1, "a site, or to add", 0);
        scr_put(LIST_ROW + 6, c + 1, "one with ^N.", 0);
        return;
    }
    put_tail(HEAD_ROW, c, p->path, w, side == active);
    utoa(p->dirs, msg, 10);
    strcat(msg, p->dirs == 1 ? " dir " : " dirs ");
    utoa(p->files, msg + strlen(msg), 10);
    strcat(msg, p->files == 1 ? " file" : " files");
    if (p->full)
        strcat(msg, "+");
    scr_putw(COUNT_ROW, c, msg, w, 0);
    draw_list(side);
}

static void draw_all(void)
{
    draw_title();
    ui_info(connected ? sites[site].name : "Not connected");
    draw_frame();
    draw_pane(LOCAL);
    draw_pane(REMOTE);
    draw_details();
    draw_keys();
}

/* -- reading the panes */

static void report(const char *what, int r)
{
    strcpy(msg, what);
    strcat(msg, ": ");
    if (r == FTP_ERR_TIMEOUT)
        strcat(msg, "no answer");
    else if (r == FTP_ERR_CLOSED)
        strcat(msg, "connection closed");
    else
        strncat(msg, ftp_msg, sizeof(msg) - strlen(msg) - 1);
    ui_info(msg);
    if (r == FTP_ERR_CLOSED || r == FTP_ERR_TIMEOUT)
        connected = 0;
}

static void read_local(void)
{
    unsigned char st;

    ui_info("Reading the disk...");
    st = local_read(&pane[LOCAL]);
    if (st >= 128) {
        strcpy(msg, pane[LOCAL].path);
        strcat(msg, " error ");
        utoa(st, msg + strlen(msg), 10);
        ui_info(msg);
    } else
        ui_info(connected ? sites[site].name : "Not connected");
}

static void read_remote(void)
{
    int r;

    ui_info("Reading the server's folder...");
    r = remote_read(&pane[REMOTE]);
    if (r)
        report("List", r);
    else
        ui_info(sites[site].name);
}

/* Put the cursor on the entry called name, if it's there. */
static void find(pane_t *p, const char *name)
{
    unsigned char i;

    for (i = 0; i < p->count; ++i)
        if (!strcmp(p->ent[i].name, name)) {
            p->cur = i;
            p->top = i >= VIS ? i - VIS / 2 : 0;
            return;
        }
}

/* -- connecting */

static void disconnect(void)
{
    if (connected)
        ftp_quit();
    connected = 0;
    pane_clear(&pane[REMOTE]);
    active = LOCAL;
}

static void connect(unsigned char i)
{
    site_t *s = &sites[i];
    int r;

    disconnect();
    site = i;
    draw_all();
    strcpy(pass, s->pass);
    if (!pass[0]) {
        strcpy(msg, "Password for ");
        strcat(msg, s->name);
        strcat(msg, ":");
        ui_info(msg);
        if (scr_edit(1, SCR_L + strlen(msg) + 1, SCR_R - SCR_L - strlen(msg)
                     - 1, pass, sizeof(pass), 1) == K_ESC) {
            ui_info("Not connected");
            return;
        }
    }
    strcpy(msg, "Connecting to ");
    strcat(msg, s->name);
    strcat(msg, "...");
    ui_info(msg);
    if ((r = ftp_connect(s->host, s->port)) != 0) {
        report("Connect", r);
        ftp_quit();
        return;
    }
    r = ftp_login(s->user, pass);
    memset(pass, 0, sizeof(pass));
    if (r) {
        report("Login", r);
        ftp_quit();
        return;
    }
    connected = 1;
    if (s->rdir[0] && (r = ftp_cwd(s->rdir)) != 0)
        report("Folder", r);
    if (s->ldir[0]) {
        strcpy(pane[LOCAL].path, s->ldir);
        read_local();
    }
    read_remote();
    active = connected ? REMOTE : LOCAL;
}

/* -- moving about */

static void move_to(unsigned char i)
{
    pane_t *p = &pane[active];
    unsigned char old = p->cur, top = p->top;

    if (!p->count)
        return;
    if (i >= p->count)
        i = p->count - 1;
    p->cur = i;
    if (i < p->top)
        p->top = i;
    else if (i >= p->top + VIS)
        p->top = i - VIS + 1;
    if (p->top != top)
        draw_list(active);
    else {
        draw_entry(active, old);
        draw_entry(active, i);
    }
    draw_details();
}

static void go_up(void)
{
    pane_t *p = &pane[active];
    char *s;
    int r;

    if (active == LOCAL) {
        /* remember the folder we're leaving: "D1:>A>B>" -> "B" */
        strcpy(tmp, p->path);
        tmp[strlen(tmp) - 1] = '\0';
        s = strrchr(tmp, '>');
        if (!local_up(p))
            return;
        read_local();
    } else {
        s = strrchr(p->path, '/');
        strcpy(tmp, s ? s : "/");
        s = tmp;
        if ((r = ftp_cwd("..")) != 0) {
            report("Folder", r);
            return;
        }
        read_remote();
    }
    if (s)
        find(p, s + 1);
    draw_pane(active);
    draw_details();
}

static void open_entry(void)
{
    pane_t *p = &pane[active];
    entry_t *e;
    int r;

    if (!p->count)
        return;
    e = &p->ent[p->cur];
    if (e->flags & E_UP) {
        go_up();
        return;
    }
    if (!(e->flags & E_DIR)) {
        ui_info("Sending files comes next version.");
        return;
    }
    strcpy(tmp, e->name);
    if (active == LOCAL) {
        local_into(p, tmp);
        read_local();
    } else {
        if ((r = ftp_cwd(tmp)) != 0) {
            report("Folder", r);
            return;
        }
        read_remote();
    }
    draw_pane(active);
    draw_details();
}

static void mark(unsigned char all)
{
    pane_t *p = &pane[active];
    unsigned char i, any = 0;

    if (!p->count)
        return;
    if (!all) {
        if (!(p->ent[p->cur].flags & E_UP))
            p->ent[p->cur].flags ^= E_MARK;
        draw_entry(active, p->cur);
        move_to(p->cur + 1);
        return;
    }
    for (i = 0; i < p->count; ++i)
        if (!(p->ent[i].flags & (E_UP | E_DIR | E_MARK)))
            any = 1;
    for (i = 0; i < p->count; ++i)
        if (!(p->ent[i].flags & (E_UP | E_DIR))) {
            if (any)
                p->ent[i].flags |= E_MARK;
            else
                p->ent[i].flags &= ~E_MARK;
        }
    draw_list(active);
    draw_details();
}

/* A letter jumps to the next name starting with it. */
static void jump(unsigned char k)
{
    pane_t *p = &pane[active];
    unsigned char i, n = p->count;

    k = toupper(k);
    for (i = 1; i <= n; ++i)
        if (toupper(p->ent[(p->cur + i) % n].name[0]) == k) {
            move_to((p->cur + i) % n);
            return;
        }
}

static void help(void)
{
    static const char *const keys[] = {
        "^K ^D", "sites / disconnect",
        "RETURN", "open folder, send file",
        "SPACE", "mark file and move on",
        "^A", "mark all",
        "^T", "send what is marked",
        "BKSP", "folder up",
        "TAB", "other pane",
        "^N ^E", "new folder / rename",
        "DEL", "delete",
        "^R", "read lists again",
        "1-8", "drive D1:-D8:",
        "ESC", "stop transfer",
        "^Q", "quit to DOS",
    };
    unsigned char i;

    scr_box(3, 22, "Keys");
    for (i = 0; i < sizeof(keys) / sizeof(keys[0]); i += 2) {
        scr_put(4 + i / 2, SCR_L + 2, keys[i], 1);
        scr_put(4 + i / 2, SCR_L + 10, keys[i + 1], 0);
    }
    scr_put(18, SCR_L + 2, "The same keys as EFTP on the ST.", 0);
    scr_put(19, SCR_L + 2, "^N ^E ^T DEL: next version.", 0);
    scr_put(21, SCR_L + 2, "Any key", 1);
    scr_put(21, SCR_L + 10, "back", 0);
    key_get();
    draw_all();
}

/* -- start */

static void init(void)
{
    pane[LOCAL].ent = local_ent;
    pane[LOCAL].max = MAX_LOCAL;
    pane[LOCAL].pool = local_pool;
    pane[LOCAL].pool_size = sizeof(local_pool);
    strcpy(pane[LOCAL].path, "D1:");
    pane[REMOTE].ent = remote_ent;
    pane[REMOTE].max = MAX_REMOTE;
    pane[REMOTE].pool = remote_pool;
    pane[REMOTE].pool_size = sizeof(remote_pool);
}

int main(void)
{
    unsigned char k;
    signed char s;
    pane_t *p;

    init();
    scr_init();
    draw_all();
    sites_load();
    read_local();
    draw_pane(LOCAL);
    draw_details();

    for (;;) {
        p = &pane[active];
        k = key_get();
        switch (k) {
        case K_UP: case '-':
            if (p->cur)
                move_to(p->cur - 1);
            break;
        case K_DOWN: case '=':
            move_to(p->cur + 1);
            break;
        case K_LEFT: case '+':
            move_to(p->cur > VIS ? p->cur - VIS : 0);
            break;
        case K_RIGHT: case '*':
            move_to(p->cur + VIS);
            break;
        case K_TAB:
            if (!connected) {
                ui_info("Not connected: ^K picks a site");
                break;
            }
            active ^= 1;
            draw_pane(LOCAL);
            draw_pane(REMOTE);
            draw_details();
            break;
        case K_RETURN:
            open_entry();
            break;
        case K_BKSP:
            go_up();
            break;
        case ' ':
            mark(0);
            break;
        case CTRL('A'):
            mark(1);
            break;
        case CTRL('K'):
            s = sites_screen();
            draw_all();
            if (s >= 0)
                connect(s);
            draw_all();
            break;
        case CTRL('D'):
            disconnect();
            draw_all();
            break;
        case CTRL('R'):
            read_local();
            if (connected)
                read_remote();
            draw_all();
            break;
        case K_HELP: case '?':
            help();
            break;
        case CTRL('Q'):
            disconnect();
            scr_done();
            return EXIT_SUCCESS;
        case CTRL('T'): case CTRL('N'): case CTRL('E'): case K_DEL:
        case K_DEL2:
            ui_info("That comes in the next version.");
            break;
        default:
            if (k >= '1' && k <= '8' && active == LOCAL) {
                local_drive(&pane[LOCAL], k - '0');
                read_local();
                draw_pane(LOCAL);
                draw_details();
            } else if (isalpha(k))
                jump(k);
        }
    }
}
