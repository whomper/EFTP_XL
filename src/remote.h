/*
 * EFTP_XL - the server side: a folder's LIST into a pane
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef REMOTE_H
#define REMOTE_H

#include "pane.h"

/* Read the server's current folder into the server's pane (its path
   from PWD). Returns 0 or an ftp error. */
int remote_read(void);

/* Take one LIST line apart into the server's pane. */
void __fastcall__ remote_add_line(char *line);

#endif
