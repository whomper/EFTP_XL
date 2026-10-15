/*
 * EFTP_XL - the sites: servers to connect to, kept in D:EFTPXL.CFG
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef SITES_H
#define SITES_H

#define MAX_SITES   8

#define MODE_BINARY 0
#define MODE_TEXT   1
#define MODE_BYTYPE 2

typedef struct {
    char name[20];
    char host[40];
    char port[6];
    char user[24];
    char pass[24];          /* blank: asked for when connecting */
    char rdir[48];          /* folder on the server */
    char ldir[32];          /* folder on the Atari, e.g. D1:>DOWNLOAD> */
    unsigned char mode;
} site_t;

extern site_t sites[MAX_SITES];
extern unsigned char site_count;

void sites_load(void);
unsigned char sites_save(void);

/* The Sites screen. Returns the site to connect to, or -1. */
signed char sites_screen(void);

#endif
