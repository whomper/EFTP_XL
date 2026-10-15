/*
 * EFTP_XL - FTP client over FujiNet TCP connections
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * The program speaks FTP itself: the control connection is N1:, the
 * passive-mode data connection N2:, both plain TCP. FujiNet's own FTP
 * protocol is not used (up to firmware 1.6.1 it always logs in as
 * anonymous on port 21). Only TCP open/read/write/status/close are
 * needed, so it works on firmware 1.3 and later.
 */

#ifndef FTP_H
#define FTP_H

#define FTP_MSG_LEN     80

/* Error codes below 100 are ours; others are the server's reply code. */
#define FTP_ERR_OPEN    1       /* could not open the TCP connection */
#define FTP_ERR_TIMEOUT 2       /* no reply in time */
#define FTP_ERR_CLOSED  3       /* server closed the connection */
#define FTP_ERR_REPLY   4       /* reply we could not understand */

/* 512 bytes for file data; ftp_* use it only while opening a
   connection (FujiNet takes the 256-byte N: spec from it). */
extern unsigned char ftp_buf[512];

/* Last reply line from the server, e.g. "530 Login incorrect." */
extern char ftp_msg[FTP_MSG_LEN];

/* Each returns 0 on success, else an error code (see above). */
int ftp_connect(const char *host, const char *port);
int ftp_login(const char *user, const char *pass);
int ftp_cwd(const char *path);
/* One command and its reply, as MKD, DELE, RMD, RNFR, RNTO: 0 when the
   server took it (a 2xx or 3xx reply). */
int ftp_do(const char *verb, const char *arg);
/* The server's current folder, from PWD, into buf. */
int ftp_pwd(char *buf, unsigned char len);

/* List the current directory, calling show() for each line received. */
int ftp_list(void (*show)(char *line));

/* A file: ftp_retr or ftp_stor opens it, ftp_read / ftp_write move the
   bytes, ftp_done ends it (0, or the server's reply), ftp_abort stops
   it early. ftp_read returns the bytes read, 0 at the end of the file,
   or a negative FTP_ERR_*. */
int ftp_retr(const char *name);
int ftp_stor(const char *name);
int ftp_read(unsigned char *buf, unsigned int len);
int ftp_write(const unsigned char *buf, unsigned int len);
int ftp_done(void);
void ftp_abort(void);

void ftp_quit(void);

#endif
