/*
 * EFTP_XL - a pane: the files of one folder, on the Atari or the server
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef PANE_H
#define PANE_H

#define E_UP        0x01    /* ".." */
#define E_DIR       0x02
#define E_MARK      0x04
#define E_QUEUED    0x08    /* in the transfer being made */
#define E_DONE      0x10
#define E_FAIL      0x20
#define E_SKIP      0x40

#define PATH_LEN    80

/* when a file was changed: day 0 for not known; year NO when the time
   is known instead (a server's recent files), hour NO when it isn't */
#define NO          0xFF
typedef struct {
    unsigned char day, mon, year, hour, min;
} stamp_t;

typedef struct {
    char *name;
    unsigned long size;
    stamp_t when;
    unsigned char flags;
} entry_t;

typedef struct {
    entry_t *ent;
    unsigned char max, count;
    unsigned char top, cur;         /* first row shown, cursor */
    char *pool;                     /* the names */
    unsigned int pool_size, pool_used;
    unsigned char dirs, files;
    unsigned char full;             /* entries left out: no room */
    char path[PATH_LEN];
} pane_t;

void pane_clear(pane_t *p);
/* Add an entry; returns it, or 0 when the pane is full. */
entry_t *pane_add(pane_t *p, const char *name, unsigned long size,
                  const stamp_t *when, unsigned char flags);
/* ".." first, then folders, then files, by name. */
void pane_sort(pane_t *p);

/* "244K" and the like, at most 4 characters, into s */
void fmt_size(unsigned long n, char *s);

/* Building a line of text: sb_start(buf), then sb_add / sb_num /
   sb_size append to it. */
void sb_start(char *s);
void sb_add(const char *s);
void sb_num(unsigned int n);
void sb_size(unsigned long n);
/* "15.10.26", or "15.10 16:42" for a recent file on the server */
void sb_stamp(const stamp_t *w);

#endif
