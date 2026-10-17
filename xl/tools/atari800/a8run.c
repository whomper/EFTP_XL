/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (C) 2026 AERA | Erez Yaary */
/* a8run: drive libatari800 from a script (from EFTP_XL's build machine).
   a8run SCRIPT -- atari800 options...
   script lines:
     type TEXT      type TEXT (\n RETURN, \e ESC), one key every few frames
     wait N         run N frames
     until TEXT N   run until TEXT is on the screen (checked every 10 frames,
                    at most N times; else exit 2)
     clear          press Shift+< (clear the screen)
     reset          press RESET (a warm start)
     dump FILE      write the 384x240 screen buffer
     screen         print the screen
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "libatari800.h"

static input_template_t in;

static void frames(int n) { while (n--) libatari800_next_frame(&in); }

static void screen_text(char *out) {
    UBYTE *m = libatari800_get_main_memory_ptr();
    int sav = m[0x58] | m[0x59] << 8, r, c;
    char *p = out;
    for (r = 0; r < 24; r++) {
        for (c = 0; c < 40; c++) {
            int ch = m[sav + r * 40 + c] & 0x7f;
            int a = ch < 0x40 ? ch + 0x20 : ch < 0x60 ? ch - 0x40 : ch;
            *p++ = (a >= 0x20 && a < 0x7b) ? a : '?';
        }
        while (p > out && p[-1] == ' ') p--;
        *p++ = '\n';
    }
    *p = 0;
}

static void key(int ch) {
    libatari800_clear_input_array(&in);
    if (ch == '\n') { in.keycode = AKEY_RETURN; in.special = 0; }
    else if (ch == 27) in.keycode = AKEY_ESCAPE;
    else in.keychar = ch;
    frames(3);
    libatari800_clear_input_array(&in);
    frames(4);
}

int main(int argc, char **argv) {
    FILE *f;
    char line[4096], scr[24 * 41 + 1];
    int i;
    if (argc < 3) return 1;
    f = fopen(argv[1], "r");
    if (!f) { perror(argv[1]); return 1; }
    if (!libatari800_init(argc - 3, argv + 3)) {
        fprintf(stderr, "init: %s\n", libatari800_error_message());
        return 1;
    }
    libatari800_clear_input_array(&in);
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        if (!strncmp(line, "type ", 5)) {
            for (i = 5; line[i]; i++) {
                if (line[i] == '\\' && line[i + 1] == 'n') { key('\n'); i++; }
                else if (line[i] == '\\' && line[i + 1] == 'e') { key(27); i++; }
                else key((unsigned char)line[i]);
            }
        } else if (!strncmp(line, "wait ", 5)) {
            frames(atoi(line + 5));
        } else if (!strncmp(line, "until ", 6)) {
            char *sp = strrchr(line, ' ');
            int n = atoi(sp + 1);
            *sp = 0;
            for (;;) {
                screen_text(scr);
                if (strstr(scr, line + 6)) break;
                if (n-- <= 0) { printf("TIMEOUT waiting for [%s]\n%s", line + 6, scr); return 2; }
                frames(10);
            }
        } else if (!strcmp(line, "clear")) {
            libatari800_clear_input_array(&in);
            in.keycode = AKEY_LESS | 0x40;
            frames(2);
            libatari800_clear_input_array(&in);
            frames(2);
        } else if (!strcmp(line, "reset")) {
            libatari800_clear_input_array(&in);
            in.special = 2;     /* AKEY_WARMSTART, EFTP_XL's */
            frames(2);
            libatari800_clear_input_array(&in);
            frames(2);
        } else if (!strncmp(line, "dump ", 5)) {
            FILE *o = fopen(line + 5, "wb");
            fwrite(libatari800_get_screen_ptr(), 1, 384 * 240, o);
            fclose(o);
        } else if (!strcmp(line, "screen")) {
            screen_text(scr);
            printf("----\n%s", scr);
            fflush(stdout);
        }
    }
    libatari800_exit();
    return 0;
}
