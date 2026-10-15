/*
 * EFTP_XL - FTP client over FujiNet TCP connections
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <atari.h>

#include <fujinet-fuji.h>
#include <fujinet-network.h>

#include "ftp.h"

#define CTL         "N1:"
#define DAT         "N2:"
#define MODE_RW     12

/* cc65 maps '\n' to the ATASCII EOL ($9B); FTP needs real CR LF. */
#define CR          0x0D
#define LF          0x0A
#define CRLF        "\x0D\x0A"

/* RTCLOK ticks: 50 or 60 a second */
#define TIMEOUT     (20 * 60)

char ftp_msg[FTP_MSG_LEN];

static char spec[MAX_FILENAME_LEN];     /* network_open sends 256 bytes */
static char host_name[64];
static char line[160];                  /* LIST lines can be long */
static char cmd[FTP_MSG_LEN + 8];

/* A buffered reader for one connection. */
typedef struct {
    const char *dev;
    unsigned char buf[128];
    unsigned char pos, len;
} conn_t;

static conn_t ctl = { CTL };
static conn_t dat = { DAT };

static unsigned int ticks(void)
{
    return OS.rtclok[2] | (OS.rtclok[1] << 8);
}

/* Next byte from c, or a negative FTP_ERR_* code. */
static int conn_getc(conn_t *c)
{
    unsigned int start;
    uint16_t avail;
    uint8_t connected, err;
    int16_t n;

    if (c->pos < c->len)
        return c->buf[c->pos++];

    start = ticks();
    for (;;) {
        if (network_status(c->dev, &avail, &connected, &err) != FN_ERR_OK)
            return -FTP_ERR_CLOSED;
        if (avail) {
            n = network_read_nb(c->dev, c->buf,
                                avail < sizeof(c->buf) ? avail : sizeof(c->buf));
            if (n <= 0)
                return -FTP_ERR_CLOSED;
            c->pos = 1;
            c->len = n;
            return c->buf[0];
        }
        if (!connected)
            return -FTP_ERR_CLOSED;
        if ((unsigned int)(ticks() - start) > TIMEOUT)
            return -FTP_ERR_TIMEOUT;
    }
}

/* Read one line (without CR LF) into s, max len-1 chars kept.
   Returns 0, or an FTP_ERR_* code. */
static int conn_gets(conn_t *c, char *s, unsigned char len)
{
    unsigned char n = 0;
    int ch;

    for (;;) {
        ch = conn_getc(c);
        if (ch < 0) {
            s[n] = '\0';
            return (ch == -FTP_ERR_CLOSED && n) ? 0 : -ch;
        }
        if (ch == LF)
            break;
        if (ch != CR && n < len - 1)
            s[n++] = ch;
    }
    s[n] = '\0';
    return 0;
}

static int conn_open(conn_t *c, const char *port)
{
    memset(spec, 0, sizeof(spec));
    strcpy(spec, c->dev);
    strcat(spec, "TCP://");
    strcat(spec, host_name);
    strcat(spec, ":");
    strcat(spec, port);
    c->pos = c->len = 0;
    return network_open(spec, MODE_RW, OPEN_TRANS_NONE) == FN_ERR_OK
        ? 0 : FTP_ERR_OPEN;
}

/* Read a full reply, multi-line ones included. Returns the reply code
   (100..599), or an FTP_ERR_* code. The last line is left in ftp_msg. */
static int reply(void)
{
    int err;
    char code[4];

    if ((err = conn_gets(&ctl, ftp_msg, sizeof(ftp_msg))) != 0)
        return err;
    if (strlen(ftp_msg) < 3 || ftp_msg[0] < '1' || ftp_msg[0] > '5')
        return FTP_ERR_REPLY;

    if (ftp_msg[3] == '-') {
        /* multi-line: ends with a line "ddd " of the same code */
        memcpy(code, ftp_msg, 3);
        code[3] = ' ';
        do {
            if ((err = conn_gets(&ctl, line, sizeof(line))) != 0)
                return err;
        } while (strncmp(line, code, 4) != 0);
        strcpy(ftp_msg, line);
    }
    return atoi(ftp_msg);
}

static int send_cmd(const char *verb, const char *arg)
{
    strcpy(cmd, verb);
    if (arg) {
        strcat(cmd, " ");
        strncat(cmd, arg, FTP_MSG_LEN - 1);
    }
    strcat(cmd, CRLF);
    if (network_write(CTL, cmd, strlen(cmd)) != FN_ERR_OK)
        return FTP_ERR_CLOSED;
    return reply();
}

int ftp_connect(const char *host, const char *port)
{
    int r;

    strncpy(host_name, host, sizeof(host_name) - 1);
    if (conn_open(&ctl, *port ? port : "21") != 0) {
        strcpy(ftp_msg, "Could not connect.");
        return FTP_ERR_OPEN;
    }
    r = reply();
    return r == 220 ? 0 : r;
}

int ftp_login(const char *user, const char *pass)
{
    int r;

    r = send_cmd("USER", *user ? user : "anonymous");
    if (r == 331)
        r = send_cmd("PASS", pass);
    if (r != 230)
        return r;
    r = send_cmd("TYPE", "I");
    return r == 200 ? 0 : r;
}

int ftp_cwd(const char *path)
{
    int r = send_cmd("CWD", path);
    return r == 250 ? 0 : r;
}

int ftp_pwd(char *buf, unsigned char len)
{
    int r = send_cmd("PWD", NULL);
    char *a, *b;

    if (r != 257)
        return r;
    /* 257 "/pub/atari" is the current directory */
    a = strchr(ftp_msg, '"');
    b = a ? strchr(a + 1, '"') : NULL;
    if (!b)
        return FTP_ERR_REPLY;
    *b = '\0';
    strncpy(buf, a + 1, len - 1);
    buf[len - 1] = '\0';
    return 0;
}

/* Ask for passive mode; return the data port as text in port. */
static int passive(char *port)
{
    int r;
    char *p;
    unsigned char i;
    unsigned int hi, lo;

    r = send_cmd("EPSV", NULL);
    if (r == 229 && (p = strstr(ftp_msg, "|||")) != NULL) {
        utoa((unsigned int)atol(p + 3), port, 10);
        return 0;
    }

    /* 227 Entering Passive Mode (h1,h2,h3,h4,p1,p2) */
    r = send_cmd("PASV", NULL);
    if (r != 227)
        return r;
    p = strchr(ftp_msg, '(');
    if (!p)
        for (p = ftp_msg + 4; *p && (*p < '0' || *p > '9'); ++p)
            ;
    else
        ++p;
    for (i = 0; i < 4; ++i) {
        p = strchr(p, ',');
        if (!p)
            return FTP_ERR_REPLY;
        ++p;
    }
    hi = atoi(p);
    p = strchr(p, ',');
    if (!p)
        return FTP_ERR_REPLY;
    lo = atoi(p + 1);
    utoa(hi * 256 + lo, port, 10);
    return 0;
}

int ftp_list(void (*show)(char *line))
{
    int r;
    char port[6];

    if ((r = passive(port)) != 0)
        return r;
    if (conn_open(&dat, port) != 0) {
        strcpy(ftp_msg, "Could not open data connection.");
        return FTP_ERR_OPEN;
    }

    r = send_cmd("LIST", NULL);
    if (r != 125 && r != 150) {
        network_close(DAT);
        return r;
    }

    while (conn_gets(&dat, line, sizeof(line)) == 0)
        if (line[0])
            show(line);
    network_close(DAT);

    r = reply();
    return r == 226 || r == 250 ? 0 : r;
}

void ftp_quit(void)
{
    send_cmd("QUIT", NULL);
    network_close(CTL);
}
