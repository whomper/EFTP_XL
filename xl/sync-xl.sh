#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 AERA | Erez Yaary
# Bring xl/ up to date with the AERA 8-bit shared code and tools
# (github.com/whomper/AERA-Atari, folder xl/), and the release and
# withdraw workflows with it. Change shared code there, never here: a
# change made only in this copy drifts again. Copy this file to the
# program's tools/sync-xl.sh; the first time, instead:
#   git subtree add --prefix=xl https://github.com/whomper/AERA-Atari xl --squash
set -e
cd "$(dirname "$0")/.."
git subtree pull --prefix=xl https://github.com/whomper/AERA-Atari xl --squash \
    -m "Update xl/ from AERA-Atari"
mkdir -p .github/workflows
cp xl/workflows/release.yml xl/workflows/withdraw.yml .github/workflows/
git add .github/workflows/release.yml .github/workflows/withdraw.yml
git diff --cached --quiet || git commit -q -m "Release and withdraw workflows from xl/"
