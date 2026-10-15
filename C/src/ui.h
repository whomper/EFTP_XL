/*
 * EFTP_XL - shared parts of the main screen
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#ifndef UI_H
#define UI_H

/* rows of the main screen */
#define XFER_ROW    18      /* the "Transfers" rule; the list is under it */
#define XFER_ROWS   3

/* The info line under the title: what EFTP_XL is doing. */
void ui_info(const char *s);

#endif
