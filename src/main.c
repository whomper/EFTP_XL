/*
 * EFTP_XL - file transfer for 8-bit Ataris over FujiNet
 *
 * Step 1: smoke test. Shows the FujiNet adapter info, asks for a server,
 * and lists a remote directory over SFTP or FTP.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <conio.h>
#include <atari.h>

#include <fujinet-fuji.h>
#include <fujinet-network.h>

/* the last release; a release build (RELEASE=1) shows it as it is,
   any other "0.2-dev" */
#define VERSION     "0.2"
#ifdef RELEASE
#define APP_VERSION VERSION
#else
#define APP_VERSION VERSION "-dev"
#endif

#define MODE_DIR    6       /* aux1: open as directory */
#define DIR_LONG    0x80    /* aux2: long names with sizes, '/' after dirs */


#define MAX_INPUT   100     /* largest field below; keeps url under 256 */

#define MEMLO       (*(unsigned int *)0x02E7)

static char url[MAX_FILENAME_LEN];
static char proto[8];
static char host[64];
static char port[8];
static char user[32];
static char pass[32];
static char path[100];
static unsigned char buf[128];
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

static const char *errtext(unsigned char err)
{
    switch (err) {
    case 136: return "end of file";
    case 138: return "timeout";
    case 144: return "general error";
    case 146: return "not implemented";
    case 165: return "bad URL";
    case 167: return "access denied";
    case 170: return "not found";
    case 200: return "connection refused";
    case 201: return "network unreachable";
    case 202: return "socket timeout";
    case 207: return "not connected";
    case 212: return "bad username/password";
    default:  return "";
    }
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

/* Build N1:PROTO://user:pass@host:port/path/ into url. */
static unsigned char build_url(void)
{
    unsigned char plen;

    if (strpbrk(user, "@:/") || strpbrk(pass, "@:/")) {
        printf("Username/password can't contain @ : /\n");
        return 0;
    }

    plen = strlen(path);
    if (plen == 0 || path[plen - 1] != '/')
        strcat(path, "/");

    memset(url, 0, sizeof(url));
    strcpy(url, "N1:");
    strcat(url, proto);
    strcat(url, "://");
    if (*user) {
        strcat(url, user);
        if (*pass) {
            strcat(url, ":");
            strcat(url, pass);
        }
        strcat(url, "@");
    }
    strcat(url, host);
    if (*port) {
        strcat(url, ":");
        strcat(url, port);
    }
    if (path[0] != '/')
        strcat(url, "/");
    strcat(url, path);
    return 1;
}

static void list_dir(void)
{
    int16_t n;
    uint16_t bw;
    uint8_t conn, err;

    if (network_open(url, MODE_DIR, DIR_LONG) != FN_ERR_OK) {
        network_status(url, &bw, &conn, &err);
        printf("Open failed: %u %s\n", err, errtext(err));
        network_close(url);
        return;
    }

    putchar('\n');
    while ((n = network_read(url, buf, sizeof(buf))) > 0)
        fwrite(buf, 1, n, stdout);

    err = fn_network_error;
    if (n < 0 && err != 136 && err != 1)
        printf("\nRead error: %u %s\n", err, errtext(err));

    network_close(url);
}

int main(void)
{
    char c;

    printf("\x7D");     /* clear screen */
    printf("EFTP_XL %s - FujiNet smoke test\n", APP_VERSION);
    printf("MEMLO $%04X\n\n", MEMLO);

    show_adapter();
    strcpy(proto, "SFTP");

    for (;;) {
        printf("\nESC at any prompt quits.\n");
        printf("Protocol S=SFTP F=FTP [%c]: ", proto[0]);
        c = cgetc();
        if (c == CH_ESC)
            break;
        if (c == 'F' || c == 'f')
            strcpy(proto, "FTP");
        else if (c == 'S' || c == 's')
            strcpy(proto, "SFTP");
        printf("%s\n", proto);

        if (ask("Host", host, sizeof(host), host, 0) < 0
            || ask("Port (blank=default)", port, sizeof(port), NULL, 0) < 0
            || ask("Username", user, sizeof(user), user, 0) < 0
            || ask("Password", pass, sizeof(pass), NULL, 1) < 0
            || ask("Path", path, sizeof(path) - 1, path[0] ? path : "/", 0) < 0)
            break;

        if (!*host) {
            printf("Need a host.\n");
            continue;
        }
        if (!build_url())
            continue;

        printf("Listing %s://%s%s%s ...\n", proto, host,
               path[0] == '/' ? "" : "/", path);
        list_dir();
        memset(pass, 0, sizeof(pass));
        memset(url, 0, sizeof(url));
    }

    return EXIT_SUCCESS;
}
