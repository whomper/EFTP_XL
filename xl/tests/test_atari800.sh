#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 AERA | Erez Yaary
# xl/ end to end in atari800: HELLO.M65, built by xl/tools/mac65.py and
# put on a SpartaDOS 3.2 disk by atari_src.py, boots and runs; built to
# load below MEMLO, its AXLOAD check refuses and SpartaDOS carries on;
# after RESET, AXRESET brings it back (DOS's init first).
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
python3 "$XL/tools/mac65.py" "$W/HELLO.M65" -o "$W/HELLO.PRG"
python3 "$XL/tools/mac65.py" "$W/LOW.M65" -o "$W/LOW.PRG"
python3 "$XL/tools/atari_src.py" disk "$W/T.ATR" --program HELLO --version 1.0 \
    "$XL/tests/HELLO.M65" "$XL/src/AXEQU.M65" "$XL/src/AXLOAD.M65" "$XL/src/AXRESET.M65" \
    "$W/HELLO.PRG" "$W/LOW.PRG"
python3 "$XL/tools/atari800/a8check.py" start "$A8" "$W/T.ATR" HELLO.PRG "AERA XL OK"
python3 "$XL/tools/atari800/a8check.py" start "$A8" "$W/T.ATR" LOW.PRG "HELLO: DOS too big"
printf 'until D1: 400\nwait 60\ntype HELLO.PRG\\n\nuntil AERA XL OK 300\nreset\nuntil AERA XL RESET 300\nscreen\n' > "$W/reset.txt"
"$A8" "$W/reset.txt" -- -xl -nobasic "$W/T.ATR" | grep -q 'AERA XL RESET' && echo "RESET: PASS" || { echo "RESET: FAIL"; exit 1; }
