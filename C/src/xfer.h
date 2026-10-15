/*
 * EFTP_XL - sending files between the Atari and the server
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef XFER_H
#define XFER_H

#include "pane.h"

/* The marked files of a pane (or, with none marked or with cursor_only,
   the one under the cursor) go to the other side: down from the server's
   pane when down, else up from the Atari's. mode is the site's MODE_*.
   Returns 1 when something was sent (the panes need reading again). */
unsigned char xfer_send(unsigned char down, unsigned char mode,
                        unsigned char cursor_only);

/* The transfers area: what the last transfer did. */
void xfer_draw(void);

#endif
