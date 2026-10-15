/*
 * EFTP_XL - the Atari side: directories through CIO, so any DOS works
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef LOCAL_H
#define LOCAL_H

#include "pane.h"

/* CIO on IOCB 5 (cc65's files use the lowest free IOCB, from 1 up) */
#define LOCAL_IOCB  0x50

extern unsigned int local_free;     /* free sectors, from the listing */
extern unsigned int cio_got;        /* bytes cio_read read */

unsigned char __fastcall__ cio(unsigned char x);
unsigned char cio_open(const char *spec, unsigned char aux1);
/* Read a line (without its EOL) into buf; returns the CIO status. */
unsigned char cio_getline(char *buf, unsigned int len);
unsigned char __fastcall__ cio_putline(const char *s);
/* Bytes: cio_got is how many came (also with 136, the end of the file). */
unsigned char cio_read(void *buf, unsigned int len);
unsigned char cio_write(const void *buf, unsigned int len);
/* XIO cmd (32 rename, 33 delete, ...) on spec, with the IOCB closed. */
unsigned char cio_xio(unsigned char cmd, const char *spec);
void cio_close(void);

/* Read p_path[LOCAL] ("D1:" or "D1:>GAMES>") into the Atari's pane.
   Returns 1 or a CIO error number. */
unsigned char local_read(void);
void __fastcall__ local_into(const char *dir);
/* Returns 0 at the top of the drive. */
unsigned char local_up(void);
void __fastcall__ local_drive(unsigned char n);

#endif
