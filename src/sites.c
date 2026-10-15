/*
 * EFTP_XL - the sites
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * D:EFTPXL.CFG has a line for each site, its fields separated by '|':
 *   name|host|port|user|password|server folder|Atari folder|mode
 * D: is the drive (and on SpartaDOS the folder) EFTP_XL was run from.
 */

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "screen.h"
#include "local.h"
#include "sites.h"
#include "ui.h"

#define CFG         "D:EFTPXL.CFG"

#define LIST_ROW    4
#define SEP_ROW     (LIST_ROW + MAX_SITES)
#define FIELD_ROW   (SEP_ROW + 1)
#define LABEL_COL   (SCR_L + 2)
#define VALUE_COL   (SCR_L + 13)
#define VALUE_W     (SCR_R - VALUE_COL)

site_t sites[MAX_SITES];
unsigned char site_count;

static char line[200];

static const char *const labels[] = {
    "Name:", "Server:", "Port:", "User:", "Password:", "Folder:", "Atari:",
    "Files:"
};
static const char *const modes[] = { "Binary", "Text", "By type" };

/* a site's text fields, in the order of the labels and the file */
static const unsigned char offs[7] = {
    offsetof(site_t, name), offsetof(site_t, host), offsetof(site_t, port),
    offsetof(site_t, user), offsetof(site_t, pass), offsetof(site_t, rdir),
    offsetof(site_t, ldir)
};
static const unsigned char sizes[7] = {
    sizeof(sites[0].name), sizeof(sites[0].host), sizeof(sites[0].port),
    sizeof(sites[0].user), sizeof(sites[0].pass), sizeof(sites[0].rdir),
    sizeof(sites[0].ldir)
};

static char *field(site_t *s, unsigned char i, unsigned char *max)
{
    *max = sizes[i];
    return (char *)s + offs[i];
}

void sites_load(void)
{
    site_t *s;
    char *p, *bar, *f;
    unsigned char i, max;

    site_count = 0;
    if (cio_open(CFG, 4, 0) >= 128) {
        cio_close();
        return;
    }
    while (site_count < MAX_SITES && cio_getline(line, sizeof(line)) < 128) {
        if (!line[0])
            continue;
        s = &sites[site_count++];
        memset(s, 0, sizeof(*s));
        p = line;
        for (i = 0; i < 8 && p; ++i) {
            bar = strchr(p, '|');
            if (bar)
                *bar = '\0';
            if (i < 7) {
                f = field(s, i, &max);
                strncpy(f, p, max - 1);
            } else
                s->mode = *p - '0';
            p = bar ? bar + 1 : 0;
        }
        if (s->mode > MODE_BYTYPE)
            s->mode = MODE_BINARY;
    }
    cio_close();
}

unsigned char sites_save(void)
{
    unsigned char i, j, max, st;
    site_t *s;

    if ((st = cio_open(CFG, 8, 0)) >= 128) {
        cio_close();
        return st;
    }
    for (i = 0; i < site_count && st < 128; ++i) {
        s = &sites[i];
        line[0] = '\0';
        for (j = 0; j < 7; ++j) {
            strcat(line, field(s, j, &max));
            strcat(line, "|");
        }
        j = strlen(line);
        line[j] = '0' + s->mode;
        line[j + 1] = '\0';
        st = cio_putline(line);
    }
    cio_close();
    return st;
}

static void show_mode(unsigned char row, unsigned char mode)
{
    unsigned char i, c = VALUE_COL;

    for (i = 0; i < 3; ++i) {
        c = scr_put(row, c, modes[i], i == mode);
        ++c;
    }
}

static void show_fields(site_t *s)
{
    unsigned char i, max;
    char *v;

    for (i = 0; i < 8; ++i) {
        scr_putw(FIELD_ROW + i, LABEL_COL, s ? labels[i] : "", 10, 0);
        scr_fill(FIELD_ROW + i, VALUE_COL, ' ', VALUE_W, 0);
        if (!s)
            continue;
        if (i == 7) {
            show_mode(FIELD_ROW + i, s->mode);
            continue;
        }
        v = field(s, i, &max);
        if (i == 4)
            scr_fill(FIELD_ROW + i, VALUE_COL, '*',
                     strlen(v) < VALUE_W ? strlen(v) : VALUE_W, 0);
        else
            scr_putw(FIELD_ROW + i, VALUE_COL, v, VALUE_W, 0);
    }
    if (s && !s->pass[0])
        scr_put(FIELD_ROW + 4, VALUE_COL, "(asked for)", 0);
}

static void show_list(unsigned char cur)
{
    unsigned char i;

    for (i = 0; i < MAX_SITES; ++i) {
        scr_fill(LIST_ROW + i, SCR_L + 1, ' ', SCR_W - 2, 0);
        if (i < site_count) {
            scr_ch(LIST_ROW + i, SCR_L + 2, ' ', i == cur);
            scr_putw(LIST_ROW + i, SCR_L + 3, sites[i].name, SCR_W - 5,
                     i == cur);
        }
    }
    if (!site_count) {
        scr_put(LIST_ROW + 1, SCR_L + 3, "No sites yet.", 0);
        scr_put(LIST_ROW + 3, SCR_L + 3, "^N adds one: a name, the", 0);
        scr_put(LIST_ROW + 4, SCR_L + 3, "server, your user and the", 0);
        scr_put(LIST_ROW + 5, SCR_L + 3, "folders to start in.", 0);
    }
    show_fields(site_count ? &sites[cur] : 0);
}

static void frame(void)
{
    scr_rule(2);
    scr_box(3, 22, "Sites");
    scr_ch(SEP_ROW, SCR_L, CH_LT, 0);
    scr_fill(SEP_ROW, SCR_L + 1, CH_HLINE, SCR_W - 2, 0);
    scr_ch(SEP_ROW, SCR_R, CH_RT, 0);
}

static void list_keys(void)
{
    unsigned char c;

    scr_clear(23, 23);
    c = scr_key(23, SCR_L, "RETURN", "Connect");
    c = scr_key(23, c, "^N", "New");
    c = scr_key(23, c, "^E", "Edit");
    scr_key(23, c, "DEL", "Del");
    ui_info("Pick a site. ESC goes back.");
}

/* Edit s in place; returns 1 when saved, 0 when left with ESC. */
static unsigned char edit(site_t *s)
{
    static site_t copy;
    unsigned char i = 0, k, max;

    copy = *s;
    scr_clear(23, 23);
    scr_key(23, scr_key(23, SCR_L, "RETURN", "Next"), "ESC", "Cancel");
    show_fields(&copy);
    for (;;) {
        if (i < 7) {
            ui_info(i == 4 ? "Blank: asked for when connecting"
                           : "Type, then RETURN for the next one");
            k = scr_edit(FIELD_ROW + i, VALUE_COL, VALUE_W,
                         field(&copy, i, &max), max, i == 4);
        } else {
            ui_info("SPACE changes, RETURN saves");
            k = key_get();
            if (k == ' ' || k == K_RIGHT || k == K_LEFT) {
                copy.mode = k == K_LEFT ? (copy.mode + 2) % 3
                                          : (copy.mode + 1) % 3;
                show_mode(FIELD_ROW + 7, copy.mode);
                continue;
            }
        }
        if (k == K_ESC)
            return 0;
        if (k == K_UP) {
            if (i)
                --i;
            continue;
        }
        if (i < 7) {
            ++i;
            continue;
        }
        if (k == K_RETURN)
            break;
    }
    if (!copy.port[0])
        strcpy(copy.port, "21");
    if (!copy.name[0])
        strncpy(copy.name, copy.host, sizeof(copy.name) - 1);
    *s = copy;
    return 1;
}

static void save(void)
{
    unsigned char st = sites_save();

    if (st >= 128) {
        strcpy(line, "Could not save " CFG ": error ");
        utoa(st, line + strlen(line), 10);
        ui_info(line);
        key_get();
    }
}

signed char sites_screen(void)
{
    unsigned char cur = 0, k, i;

    frame();
    for (;;) {
        show_list(cur);
        list_keys();
        k = key_get();
        switch (k) {
        case K_ESC:
            return -1;
        case K_UP: case '-':
            if (cur)
                --cur;
            break;
        case K_DOWN: case '=':
            if (cur + 1 < site_count)
                ++cur;
            break;
        case K_RETURN:
            if (site_count)
                return cur;
            break;
        case CTRL('N'):
            if (site_count == MAX_SITES) {
                ui_info("No room: 8 sites at most.");
                key_get();
                break;
            }
            memset(&sites[site_count], 0, sizeof(site_t));
            show_list(site_count);
            if (edit(&sites[site_count])) {
                cur = site_count++;
                save();
            }
            break;
        case CTRL('E'):
            if (site_count && edit(&sites[cur]))
                save();
            break;
        case K_DEL: case K_DEL2:
            if (!site_count)
                break;
            strcpy(line, "Delete ");
            strcat(line, sites[cur].name);
            strcat(line, "? Y/N");
            ui_info(line);
            k = key_get();
            if (k == 'Y' || k == 'y') {
                for (i = cur; i + 1 < site_count; ++i)
                    sites[i] = sites[i + 1];
                --site_count;
                if (cur && cur == site_count)
                    --cur;
                save();
            }
            break;
        }
    }
}
