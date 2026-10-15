/*
 * EFTP_XL - the panes: the files of a folder on the Atari and on the
 * server
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * The entries of both panes are kept in arrays of their fields: the
 * Atari's at 0..63, the server's at 64..127, so an entry is one byte
 * (side * MAXE + i) and a field one indexed load; per pane, arrays by
 * side. This is what cc65 makes the least code of.
 */

#ifndef PANE_H
#define PANE_H

#define LOCAL       0
#define REMOTE      1

#define MAXE        64      /* entries in a pane */
#define NE          (2 * MAXE)

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

/* the entries (one more, for sorting) */
extern char *e_name[NE + 1];
extern unsigned long e_size[NE + 1];
extern unsigned char e_flags[NE + 1];
extern stamp_t e_when[NE + 1];

/* the panes */
extern unsigned char p_count[2], p_top[2], p_cur[2];
extern unsigned char p_dirs[2], p_files[2], p_full[2];
extern char p_path[2][PATH_LEN];

/* the pane being worked on, and its first entry */
extern unsigned char side, base;
void __fastcall__ pane_use(unsigned char s);

/* the next entry's fields, for pane_add */
extern unsigned long new_size;
extern unsigned char new_flags;
extern stamp_t new_when;

void pane_clear(void);
/* Add name with new_size, new_flags and new_when to the pane being worked
   on (no room: p_full set). new_when.day goes back to 0. */
void __fastcall__ pane_add(const char *name);
/* ".." first, then folders, then files, by name. */
void pane_sort(void);
/* the entry called name in the pane being worked on, or NO */
unsigned char __fastcall__ pane_find(const char *name);

/* "244K" and the like, at most 4 characters, into s */
void __fastcall__ fmt_size(char *s);
extern unsigned long fmt_n;

/* Building a line of text: sb_start(buf), then the others append. */
void __fastcall__ sb_start(char *s);
void __fastcall__ sb_add(const char *s);
void __fastcall__ sb_num(unsigned int n);
void __fastcall__ sb_size(unsigned long n);
/* "15.10.26", or "15.10 16:42" for a recent file on the server */
void __fastcall__ sb_stamp(unsigned char k);

#endif
