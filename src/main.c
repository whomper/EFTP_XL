/*
 * EFTP_XL - file transfer for 8-bit Ataris over FujiNet
 * Copyright (C) 2026 AERA | Erez Yaary. GPL-2.0-or-later, see COPYING.
 *
 * Step 1: shows the FujiNet adapter info, logs in to an FTP server and
 * lists a remote directory. The FTP client is our own (ftp.c), over
 * FujiNet TCP connections.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <conio.h>
#include <atari.h>

#include <fujinet-fuji.h>
#include <fujinet-network.h>

#include "ftp.h"

/* the last release; a release build (RELEASE=1) shows it as it is,
   any other "0.2-dev" */
#define VERSION     "0.2"
#ifdef RELEASE
#define APP_VERSION VERSION
#else
#define APP_VERSION VERSION "-dev"
#endif

#define MAX_INPUT   100     /* largest field below */
#define NAME_WIDTH  26      /* listing: name, then size, in 38 columns */

#define MEMLO       (*(unsigned int *)0x02E7)

static char host[64];
static char port[8];
static char user[32];
static char pass[32];
static char path[MAX_INPUT];
static AdapterConfig ac;

/* Read a line from the keyboard into s (max-1 chars). mask echoes '*'.
   Returns the length, or -1 if ESC was pressed. */
static int input(char *s, unsigned char max, unsigned char mask)
{
    unsigned char len = 0;
    char c;

    for (;;) {
        c = cgetc();
        if (c == CH_ENTER) {
            s[len] = '\0';
            putchar('\n');
            return len;
        }
        if (c == CH_ESC) {
            s[0] = '\0';
            putchar('\n');
            return -1;
        }
        if (c == CH_DEL) {
            if (len) {
                --len;
                putchar(CH_DEL);
            }
            continue;
        }
        if (c < 0x20 || c > 0x7A || len == max - 1)
            continue;
        s[len++] = c;
        putchar(mask ? '*' : c);
    }
}

/* Prompt with an optional default shown in brackets. */
static int ask(const char *prompt, char *s, unsigned char max,
               const char *def, unsigned char mask)
{
    static char tmp[MAX_INPUT];
    int n;

    if (def && *def)
        printf("%s [%s]: ", prompt, def);
    else
        printf("%s: ", prompt);
    n = input(tmp, max, mask);
    if (n > 0)
        strcpy(s, tmp);
    else if (n == 0)
        strcpy(s, def ? def : "");
    return n;
}

static void show_adapter(void)
{
    if (!fuji_get_adapter_config(&ac)) {
        printf("FujiNet not responding!\n");
        return;
    }
    ac.fn_version[sizeof(ac.fn_version) - 1] = '\0';
    printf("FujiNet %s\n", ac.fn_version);
    printf("IP %u.%u.%u.%u  SSID %s\n",
           ac.localIP[0], ac.localIP[1], ac.localIP[2], ac.localIP[3],
           ac.ssid);
}

/* Skip one whitespace-separated field; NULL at the end of the line. */
static char *next_field(char *p)
{
    while (*p && *p != ' ')
        ++p;
    while (*p == ' ')
        ++p;
    return *p ? p : NULL;
}

/* Show one LIST line. Unix format ("drwxr-xr-x 2 u g 4096 Oct 15 15:20
   NAME") becomes name and size; anything else is shown as it is. */
static void show_entry(char *line)
{
    char *p = line, *size = NULL, *end;
    unsigned char i;

    for (i = 0; i < 8 && p; ++i) {
        p = next_field(p);
        if (i == 3)
            size = p;
    }
    if (!p || !size || (line[0] != 'd' && line[0] != '-' && line[0] != 'l')) {
        printf("%.38s\n", line);
        return;
    }
    end = strchr(size, ' ');
    if (end)
        *end = '\0';
    printf("%-*.*s %10s\n", NAME_WIDTH, NAME_WIDTH, p,
           line[0] == 'd' ? "<DIR>" : size);
}

/* Report a failed step: our own error, or the server's reply. */
static void report(const char *what, int r)
{
    if (r == FTP_ERR_TIMEOUT)
        printf("%s: timed out\n", what);
    else if (r == FTP_ERR_CLOSED)
        printf("%s: connection closed\n", what);
    else
        printf("%s failed:\n%.38s\n", what, ftp_msg);
}

static void session(void)
{
    int r;

    printf("Connecting to %s...\n", host);
    if ((r = ftp_connect(host, port)) != 0) {
        report("Connect", r);
        ftp_quit();
        return;
    }
    if ((r = ftp_login(user, pass)) != 0) {
        report("Login", r);
        ftp_quit();
        return;
    }
    if ((r = ftp_cwd(path)) != 0) {
        report("Change directory", r);
        ftp_quit();
        return;
    }
    printf("%s\n", path);
    if ((r = ftp_list(show_entry)) != 0)
        report("List", r);
    ftp_quit();
}

int main(void)
{
    printf("\x7D");     /* clear screen */
    printf("EFTP_XL %s\n", APP_VERSION);
    printf("MEMLO $%04X\n\n", MEMLO);

    show_adapter();

    for (;;) {
        printf("\nESC at any prompt quits.\n");
        if (ask("Host", host, sizeof(host), host, 0) < 0
            || ask("Port", port, sizeof(port), port[0] ? port : "21", 0) < 0
            || ask("Username", user, sizeof(user), user, 0) < 0
            || ask("Password", pass, sizeof(pass), NULL, 1) < 0
            || ask("Path", path, sizeof(path), path[0] ? path : "/", 0) < 0)
            break;

        if (!*host) {
            printf("Need a host.\n");
            continue;
        }
        session();
        memset(pass, 0, sizeof(pass));
    }

    return EXIT_SUCCESS;
}
