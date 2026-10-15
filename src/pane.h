/*
 * EFTP_XL - a pane: the files of one folder, on the Atari or the server
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef PANE_H
#define PANE_H

#define E_UP        0x01    /* ".." */
#define E_DIR       0x02
#define E_MARK      0x04

#define DATE_LEN    15      /* "15.10.26 12:04" */
#define PATH_LEN    80

typedef struct {
    char *name;
    unsigned long size;
    char date[DATE_LEN];
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
                  const char *date, unsigned char flags);
/* ".." first, then folders, then files, by name. */
void pane_sort(pane_t *p);

/* "244K" and the like, at most 4 characters, into s */
void fmt_size(unsigned long n, char *s);

#endif
