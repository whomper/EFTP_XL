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
 *
 * Most functions work on the pane in `side` (pane_use), where its
 * entries start at `base`; `active` is the pane with the keyboard.
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
#include "xfer.h"
#include "ui.h"

/* the last release, which every build shows */
#define VERSION     "0.2"
#define APP_VERSION VERSION

#define DIV         19          /* the line between the panes */
#define HEAD_ROW    3
#define COUNT_ROW   4
#define LIST_ROW    5
#define VIS         11          /* files shown in a pane */
#define DETAIL_ROW  17
#define NAME_W      (DIV - SCR_L - 6)

static unsigned char active;
static unsigned char connected;
static signed char site = -1;

static char msg[100];           /* a reply (79) or a path (80), and words */
static char tmp[PATH_LEN];
static char pass[20];
static char size[6];

static const unsigned char col0[2] = { SCR_L, DIV + 1 };
static const unsigned char width[2] = { DIV - SCR_L, SCR_R - DIV };

static const char main_keys[] =
    "^K\0Sites\0^T\0Send\0TAB\0Pane\0HELP\0Keys\0";

/* -- drawing */

void ui_info(const char *s)
{
    AT(1, SCR_L);
    scr_w = SCR_W - 1;
    scr_putw(s);
    scr_char(connected ? CH_DOT : ' ');
}

/* the info line when nothing is going on */
static void idle(void)
{
    ui_info(connected ? sites[site].name : "Not connected");
}

static void draw_frame(void)
{
    unsigned char r;

    for (r = 2; r <= 22; ++r)
        scr_clear(r);
    scr_rule(2);
    scr_rule(16);
    for (r = 2; r <= 16; ++r) {
        AT(r, DIV);
        scr_char(r == 2 ? CH_TT : r == 16 ? CH_BT : CH_VLINE);
    }
    scr_rule(XFER_ROW);
    AT(XFER_ROW, SCR_L + 1);
    scr_puts(" Transfers ");
    scr_rule(22);
    xfer_draw();
}

/* entry i of the pane in side, on its row */
static void __fastcall__ draw_entry(unsigned char i)
{
    unsigned char k = base + i, f = e_flags[k], n;

    AT(LIST_ROW + i - p_top[side], col0[side]);
    if (i >= p_count[side]) {
        scr_w = width[side];
        scr_rep(' ');
        return;
    }
    scr_inv = side == active && i == p_cur[side];
    scr_char((f & E_UP) ? CH_UP : (f & E_MARK) ? CH_MARK
             : (f & E_DIR) ? CH_FOLDER : CH_FILE);
    scr_w = NAME_W + side;
    if (strlen(e_name[k]) > scr_w) {
        --scr_w;
        scr_putw(e_name[k]);
        scr_char(CH_MORE);
    } else
        scr_putw(e_name[k]);
    size[0] = '\0';
    if (!(f & (E_DIR | E_UP))) {
        fmt_n = e_size[k];
        fmt_size(size);
    }
    n = strlen(size);
    scr_w = 5 - n;
    scr_rep(' ');
    scr_puts(size);
    scr_inv = 0;
}

static void draw_list(void)
{
    unsigned char i;

    for (i = p_top[side]; i < p_top[side] + VIS; ++i)
        draw_entry(i);
}

/* How many are marked in the active pane; their size in marked_size. */
static unsigned long marked_size;

static unsigned char marked(void)
{
    unsigned char k, end, n = 0;

    pane_use(active);
    end = base + p_count[side];
    marked_size = 0;
    for (k = base; k < end; ++k)
        if (e_flags[k] & E_MARK) {
            ++n;
            marked_size += e_size[k];
        }
    return n;
}

static void draw_details(void)
{
    unsigned char n, k;

    scr_clear(DETAIL_ROW);
    AT(DETAIL_ROW, SCR_L);
    if ((n = marked()) != 0) {
        sb_start(msg);
        sb_num(n);
        sb_add(" marked, ");
        sb_size(marked_size);
        scr_puts(msg);
        return;
    }
    if (!p_count[side])
        return;
    k = base + p_cur[side];
    if (e_flags[k] & E_UP) {
        scr_puts("The folder above");
        return;
    }
    scr_w = strlen(e_name[k]) < 22 ? strlen(e_name[k]) : 22;
    scr_putw(e_name[k]);
    sb_start(msg);
    sb_add(" ");
    if (e_flags[k] & E_DIR)
        sb_add("folder");
    else
        sb_size(e_size[k]);
    sb_add(" ");
    sb_stamp(k);
    if (scr_col + strlen(msg) <= SCR_R + 1)
        scr_puts(msg);
}

static void __fastcall__ draw_pane(unsigned char s)
{
    unsigned char c = col0[s], w = width[s], n;
    const char *path = p_path[s];

    pane_use(s);
    AT(HEAD_ROW, c);
    scr_w = w;
    if (s == REMOTE && !connected) {
        scr_putw("Server");
        for (n = COUNT_ROW; n < LIST_ROW + VIS; ++n) {
            AT(n, c);
            scr_rep(' ');
        }
        AT(LIST_ROW + 2, c + 1);
        scr_puts("Not connected.");
        AT(LIST_ROW + 4, c + 1);
        scr_puts("Press ^K to pick");
        AT(LIST_ROW + 5, c + 1);
        scr_puts("a site, or to add");
        AT(LIST_ROW + 6, c + 1);
        scr_puts("one with ^N.");
        return;
    }
    /* the folder, its end if it's too long */
    scr_inv = s == active;
    n = strlen(path);
    if (n > w) {
        scr_char(CH_MORE);
        path += n - w + 1;
        --scr_w;
    }
    scr_putw(path);
    scr_inv = 0;
    sb_start(msg);
    sb_num(p_dirs[s]);
    sb_add(p_dirs[s] == 1 ? " dir " : " dirs ");
    sb_num(p_files[s]);
    sb_add(p_files[s] == 1 ? " file" : " files");
    if (p_full[s])
        sb_add("+");
    AT(COUNT_ROW, c);
    scr_w = w;
    scr_putw(msg);
    draw_list();
}

static void draw_panes(void)
{
    draw_pane(LOCAL);
    draw_pane(REMOTE);
    draw_details();
}

static void draw_all(void)
{
    AT(0, SCR_L);
    scr_w = SCR_W;
    scr_inv = 1;
    scr_rep(' ');
    AT(0, SCR_L + 1);
    scr_puts("EFTP_XL " APP_VERSION);
    AT(0, SCR_R - 13);
    scr_puts("(C) AERA 2026");
    scr_inv = 0;
    idle();
    draw_frame();
    draw_panes();
    scr_keys(main_keys);
}

/* -- reading the panes */

static void __fastcall__ report(const char *what, int r)
{
    sb_start(msg);
    sb_add(what);
    sb_add(": ");
    if (r == FTP_ERR_TIMEOUT)
        sb_add("no answer");
    else if (r == FTP_ERR_CLOSED)
        sb_add("connection closed");
    else
        sb_add(ftp_msg);
    ui_info(msg);
    if (r == FTP_ERR_CLOSED || r == FTP_ERR_TIMEOUT)
        connected = 0;
}

static void read_local(void)
{
    unsigned char st;

    ui_info("Reading the disk...");
    st = local_read();
    if (st >= 128) {
        sb_start(msg);
        sb_add(p_path[LOCAL]);
        sb_add(" error ");
        sb_num(st);
        ui_info(msg);
    } else
        idle();
}

static void read_remote(void)
{
    int r;

    ui_info("Reading the server's folder...");
    if ((r = remote_read()) != 0)
        report("List", r);
    else
        idle();
}

/* Put the cursor of the pane in side on name, if it's there. */
static void __fastcall__ find(const char *name)
{
    unsigned char k = pane_find(name), i;

    if (k == NO)
        return;
    i = k - base;
    p_cur[side] = i;
    p_top[side] = i >= VIS ? i - VIS / 2 : 0;
}

/* Read a pane again, keeping the cursor on the same name. */
static void __fastcall__ reread(unsigned char s)
{
    pane_use(s);
    tmp[0] = '\0';
    if (p_count[s])
        strcpy(tmp, e_name[base + p_cur[s]]);
    if (s == LOCAL)
        local_read();
    else
        remote_read();
    find(tmp);
}

/* Ask on the info line, editing buf; 0 when left with ESC. */
static unsigned char ask(const char *q, char *buf)
{
    ui_info(q);
    AT(1, SCR_L + strlen(q) + 1);
    scr_w = SCR_R - scr_col;
    return scr_edit(buf) != K_ESC;
}

/* -- connecting */

static void disconnect(void)
{
    if (connected)
        ftp_quit();
    connected = 0;
    pane_use(REMOTE);
    pane_clear();
    active = LOCAL;
}

static void __fastcall__ connect(unsigned char i)
{
    site_t *s = &sites[i];
    int r;

    disconnect();
    site = i;
    draw_all();
    strcpy(pass, s->pass);
    if (!pass[0]) {
        sb_start(msg);
        sb_add("Password for ");
        sb_add(s->name);
        sb_add(":");
        edit_max = sizeof(pass);
        edit_mask = 1;
        r = ask(msg, pass);
        edit_mask = 0;
        if (!r) {
            idle();
            return;
        }
    }
    sb_start(msg);
    sb_add("Connecting to ");
    sb_add(s->name);
    sb_add("...");
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
        strcpy(p_path[LOCAL], s->ldir);
        read_local();
    }
    read_remote();
    active = connected ? REMOTE : LOCAL;
}

/* -- sending */

static void __fastcall__ send(unsigned char cursor_only)
{
    if (!connected) {
        ui_info("Not connected: ^K picks a site");
        return;
    }
    if (xfer_send(active == REMOTE, sites[site].mode, cursor_only)) {
        reread(LOCAL);
        reread(REMOTE);
        draw_frame();
        draw_panes();
    }
}

/* -- new folder, rename, delete: on the server FTP's MKD, RNFR/RNTO,
   DELE and RMD; on the Atari the DOS's XIO 42 (SpartaDOS), 32, 33, 43 */

#define spec ((char *)ftp_buf)      /* free while nothing is sent */

/* spec = the Atari pane's folder + name */
static void __fastcall__ local_spec(const char *name)
{
    sb_start(spec);
    sb_add(p_path[LOCAL]);
    sb_add(name);
}

/* Done: say so, or why not; then read the pane again, the cursor on
   tmp. err is a CIO status (Atari) or an ftp error (server). */
static void after(const char *what, int err)
{
    if (active == LOCAL && err >= 128) {
        sb_start(msg);
        sb_add(what);
        sb_add(err == 146 ? ": this DOS has no folders"
                          : err == 170 ? ": not found" : ": error ");
        if (err != 146 && err != 170)
            sb_num(err);
        ui_info(msg);
    } else if (active == REMOTE && err)
        report(what, err);
    else
        idle();
    if (active == LOCAL)
        local_read();
    else
        remote_read();
    pane_use(active);
    find(tmp);
    draw_pane(active);
    draw_details();
}

/* the entry under the cursor of the active pane */
static unsigned char cursor_entry(void)
{
    pane_use(active);
    return base + p_cur[side];
}

static void upper(void)
{
    char *s;

    for (s = tmp; *s; ++s)
        *s = toupper(*s);
}

static void new_folder(void)
{
    tmp[0] = '\0';
    edit_max = active == LOCAL ? 9 : 64;
    if (!ask("New folder:", tmp) || !tmp[0])
        return;
    if (active == LOCAL) {
        upper();
        local_spec(tmp);
        after("New folder", cio_xio(42, spec));
    } else
        after("New folder", ftp_do("MKD", tmp));
}

static void rename_entry(void)
{
    unsigned char k = cursor_entry();
    int r;

    if (!p_count[side] || (e_flags[k] & E_UP))
        return;
    strcpy(tmp, e_name[k]);
    edit_max = active == LOCAL ? 13 : 64;
    if (!ask("Rename to:", tmp) || !tmp[0] || !strcmp(tmp, e_name[k]))
        return;
    if (active == LOCAL) {
        upper();
        local_spec(e_name[k]);
        sb_add(",");
        sb_add(tmp);
        r = cio_xio(32, spec);
    } else if ((r = ftp_do("RNFR", e_name[k])) == 0)
        r = ftp_do("RNTO", tmp);
    after("Rename", r);
}

/* the marked files and folders, or the one under the cursor */
static void delete_entries(void)
{
    unsigned char n = marked(), k = cursor_entry(), end, key;
    int r = active == LOCAL ? 1 : 0;

    if (!n && (!p_count[side] || (e_flags[k] & E_UP)))
        return;
    sb_start(msg);
    sb_add("Delete ");
    if (n) {
        sb_num(n);
        sb_add(" marked");
    } else
        sb_add(e_name[k]);
    sb_add("? Y/N");
    ui_info(msg);
    key = key_get();
    if (key != 'Y' && key != 'y') {
        idle();
        return;
    }
    /* a folder has to be empty first, as DOS and FTP want */
    end = base + p_count[side];
    for (k = n ? base : k; k < end; ++k) {
        if (n && !(e_flags[k] & E_MARK))
            continue;
        if (active == LOCAL) {
            local_spec(e_name[k]);
            r = cio_xio(e_flags[k] & E_DIR ? 43 : 33, spec);
            if (r >= 128)
                break;
        } else if ((r = ftp_do(e_flags[k] & E_DIR ? "RMD" : "DELE",
                               e_name[k])) != 0)
            break;
        if (!n)
            break;
    }
    tmp[0] = '\0';
    after("Delete", r);
}

/* -- moving about */

static void __fastcall__ move_to(unsigned char i)
{
    unsigned char old, top;

    pane_use(active);
    if (!p_count[side])
        return;
    old = p_cur[side];
    top = p_top[side];
    if (i >= p_count[side])
        i = p_count[side] - 1;
    p_cur[side] = i;
    if (i < top)
        p_top[side] = i;
    else if (i >= top + VIS)
        p_top[side] = i - VIS + 1;
    if (p_top[side] != top)
        draw_list();
    else {
        draw_entry(old);
        draw_entry(i);
    }
    draw_details();
}

static void go_up(void)
{
    char *s;
    int r;

    if (active == LOCAL) {
        /* remember the folder we're leaving: "D1:>A>B>" -> "B" */
        strcpy(tmp, p_path[LOCAL]);
        tmp[strlen(tmp) - 1] = '\0';
        s = strrchr(tmp, '>');
        if (!local_up())
            return;
        read_local();
    } else {
        s = strrchr(p_path[REMOTE], '/');
        strcpy(tmp, s ? s : "/");
        s = tmp;
        if ((r = ftp_cwd("..")) != 0) {
            report("Folder", r);
            return;
        }
        read_remote();
    }
    pane_use(active);
    if (s)
        find(s + 1);
    draw_pane(active);
    draw_details();
}

static void open_entry(void)
{
    unsigned char k = cursor_entry();
    int r;

    if (!p_count[side])
        return;
    if (e_flags[k] & E_UP) {
        go_up();
        return;
    }
    if (!(e_flags[k] & E_DIR)) {
        send(1);
        return;
    }
    strcpy(tmp, e_name[k]);
    if (active == LOCAL) {
        local_into(tmp);
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

static void __fastcall__ mark(unsigned char all)
{
    unsigned char k = cursor_entry(), end = base + p_count[side], any = 0;

    if (!p_count[side])
        return;
    if (!all) {
        if (!(e_flags[k] & E_UP))
            e_flags[k] ^= E_MARK;
        draw_entry(p_cur[side]);
        move_to(p_cur[side] + 1);
        return;
    }
    for (k = base; k < end; ++k)
        if (!(e_flags[k] & (E_UP | E_DIR | E_MARK)))
            any = 1;
    for (k = base; k < end; ++k)
        if (!(e_flags[k] & (E_UP | E_DIR))) {
            if (any)
                e_flags[k] |= E_MARK;
            else
                e_flags[k] &= ~E_MARK;
        }
    draw_list();
    draw_details();
}

/* A letter jumps to the next name starting with it. */
static void __fastcall__ jump(unsigned char key)
{
    unsigned char i, n, j;

    pane_use(active);
    n = p_count[side];
    key = toupper(key);
    for (i = 1; i <= n; ++i) {
        j = (p_cur[side] + i) % n;
        if (toupper(e_name[base + j][0]) == key) {
            move_to(j);
            return;
        }
    }
}

static void help(void)
{
    static const char keys[] =
        "^K ^D\0sites / disconnect\0"
        "RETURN\0open folder, send file\0"
        "SPACE\0mark file and move on\0"
        "^A\0mark all\0"
        "^T\0send what is marked\0"
        "BKSP\0folder up\0"
        "TAB\0other pane\0"
        "^N ^E\0new folder / rename\0"
        "DEL\0delete\0"
        "^R\0read lists again\0"
        "1-8\0drive D1:-D8:\0"
        "ESC\0stop transfer\0"
        "^Q\0quit to DOS\0";
    const char *p = keys;
    unsigned char r;

    scr_box("Keys");
    for (r = 4; *p; ++r) {
        AT(r, SCR_L + 2);
        scr_inv = 1;
        scr_puts(p);
        scr_inv = 0;
        p += strlen(p) + 1;
        AT(r, SCR_L + 10);
        scr_puts(p);
        p += strlen(p) + 1;
    }
    AT(18, SCR_L + 2);
    scr_puts("The same keys as EFTP on the ST.");
    AT(21, SCR_L + 2);
    scr_inv = 1;
    scr_puts("Any key");
    scr_inv = 0;
    ++scr_col;
    scr_puts("back");
    key_get();
    draw_all();
}

/* -- start */

int main(void)
{
    unsigned char k;
    signed char s;

    strcpy(p_path[LOCAL], "D1:");
    scr_init();
    draw_all();
    sites_load();
    read_local();
    draw_pane(LOCAL);
    draw_details();

    for (;;) {
        k = key_get();
        pane_use(active);
        switch (k) {
        case K_UP: case '-':
            if (p_cur[side])
                move_to(p_cur[side] - 1);
            break;
        case K_DOWN: case '=':
            move_to(p_cur[side] + 1);
            break;
        case K_LEFT: case '+':
            move_to(p_cur[side] > VIS ? p_cur[side] - VIS : 0);
            break;
        case K_RIGHT: case '*':
            move_to(p_cur[side] + VIS);
            break;
        case K_TAB:
            if (!connected) {
                ui_info("Not connected: ^K picks a site");
                break;
            }
            active ^= 1;
            draw_panes();
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
            if (s >= 0) {
                connect(s);
                /* the panes, but the info line keeps what connect said */
                draw_panes();
            }
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
        case CTRL('T'):
            send(0);
            break;
        case CTRL('N'):
            new_folder();
            break;
        case CTRL('E'):
            rename_entry();
            break;
        case K_DEL: case K_DEL2:
            delete_entries();
            break;
        default:
            if (k >= '1' && k <= '8' && active == LOCAL) {
                local_drive(k - '0');
                read_local();
                draw_pane(LOCAL);
                draw_details();
            } else if (isalpha(k))
                jump(k);
        }
    }
}
