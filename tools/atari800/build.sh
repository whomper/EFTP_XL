#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 AERA | Erez Yaary
# Build a8run: libatari800 at a fixed commit, driven by a script.
#   xl/tools/atari800/build.sh DIR     makes DIR/a8run (DIR: a scratch folder)
# The OS is atari800's own replacement ROM, so no Atari ROMs are needed.
# Newer compilers warn where this commit doesn't expect it, so the build
# leaves out atari800's -Werror.
set -e
REV=b49865e63f5675c798d0122a5ff65c89b2f2748b
HERE=$(cd "$(dirname "$0")" && pwd)
DIR=${1:?a folder to build in}
mkdir -p "$DIR"
cd "$DIR"
if [ ! -f atari800/src/libatari800.a ]; then
    rm -rf atari800
    git init -q atari800
    git -C atari800 fetch -q --depth 1 https://github.com/atari800/atari800 "$REV"
    git -C atari800 checkout -q FETCH_HEAD
    (cd atari800 && ./autogen.sh >/dev/null && ./configure -q --target=libatari800 >/dev/null &&
     make -s -j"$(nproc)" CFLAGS="-g -O2 -DNETSIO" CFLAGS_NOANSI="-g -O2 -DNETSIO" >/dev/null)
fi
gcc -O2 -o a8run "$HERE/a8run.c" -I atari800/src/libatari800 -I atari800/src \
    atari800/src/libatari800.a -lm -lz
echo "$DIR/a8run"
