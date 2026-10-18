#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 AERA | Erez Yaary
# xl/ end to end in atari800: HELLO.M65, built by xl/tools/mac65.py and
# put on a SpartaDOS 3.2 disk by atari_src.py, boots and runs; built to
# load below MEMLO, its AXLOAD check refuses and SpartaDOS carries on;
# after RESET, AXRESET brings it back (DOS's init first); HELP and
# BREAK reach it.
#   xl/tests/test_atari800.sh DIR    (DIR: scratch, where a8run is built)
set -e
XL=$(cd "$(dirname "$0")/.." && pwd)
DIR=${1:?a scratch folder}
A8=$("$XL/tools/atari800/build.sh" "$DIR" | tail -1)
W="$DIR/hello"
rm -rf "$W"
mkdir -p "$W"
cp "$XL"/src/*.M65 "$XL/tests/HELLO.M65" "$W/"
sed -e 's/^AXLOW    =   \$3000/AXLOW    =   $0800/' -e 's/HELLO.M65 - /LOW.M65 - /' \
    "$XL/tests/HELLO.M65" > "$W/LOW.M65"
python3 "$XL/tools/mac65.py" "$W/HELLO.M65" -o "$W/HELLO.COM"
python3 "$XL/tools/mac65.py" "$W/LOW.M65" -o "$W/LOW.COM"
python3 "$XL/tools/atari_src.py" disk "$W/T.ATR" --program HELLO --version 1.0 \
    "$XL/tests/HELLO.M65" "$XL/src/AXEQU.M65" "$XL/src/AXLOAD.M65" "$XL/src/AXRESET.M65" \
    "$W/HELLO.COM" "$W/LOW.COM"
python3 "$XL/tools/atari800/a8check.py" start "$A8" "$W/T.ATR" HELLO.COM "AERA XL OK"
python3 "$XL/tools/atari800/a8check.py" start "$A8" "$W/T.ATR" LOW.COM "HELLO: DOS too big"
printf 'until D1: 400\nwait 60\ntype HELLO.COM\\n\nuntil AERA XL OK 300\nreset\nuntil AERA XL RESET 300\nscreen\n' > "$W/reset.txt"
# a8run's script: PASS when every until is met (a TIMEOUT line names the
# text it waited for, so grep for that, not for the text)
run() {
    out=$("$A8" "$2" -- -xl -nobasic "$3") || true
    if echo "$out" | grep -q TIMEOUT; then echo "$out"; echo "$1: FAIL"; exit 1; fi
    echo "$1: PASS"
}
run RESET "$W/reset.txt" "$W/T.ATR"
# a8run's help and break: the OS sets HELPFG and BRKKEY, HELLO says so
printf 'until D1: 400\nwait 60\ntype HELLO.COM\\n\nuntil AERA XL OK 300\nhelp\nuntil AERA XL HELP 100\nbreak\nuntil AERA XL BREAK 100\nscreen\n' > "$W/keys.txt"
run KEYS "$W/keys.txt" "$W/T.ATR"
# --tree: a folder made by sparta.py, as SpartaDOS 3.2 reads it
mkdir -p "$W/tree/SUB"
printf 'IN SUB\233' > "$W/tree/SUB/C.TXT"
python3 "$XL/tools/atari_src.py" disk "$W/F.ATR" --program HELLO --version 1.0 \
    --tree "$W/tree" "$XL/tests/HELLO.M65"
printf 'until D1: 400\nwait 60\ntype TYPE >SUB>C.TXT\\n\nuntil IN SUB 300\nscreen\n' > "$W/tree.txt"
run FOLDERS "$W/tree.txt" "$W/F.ATR"
