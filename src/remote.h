/*
 * EFTP_XL - the server side: a folder's LIST into a pane
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef REMOTE_H
#define REMOTE_H

#include "pane.h"

/* Read the server's current folder into p (p->path from PWD).
   Returns 0 or an ftp error. */
int remote_read(pane_t *p);

/* Take one LIST line apart into p; exported for the host tests. */
void remote_add_line(pane_t *p, char *line);

#endif
