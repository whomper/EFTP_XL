# EFTP_XL build: the Mac/65 sources in ASM/, assembled with ATasm
# (https://github.com/CycoPH/atasm, Mac/65 compatible) on the PATH.
#
#   make            bin/EFTPXL.PRG
#   make dist       a release's files in dist/
#   make atr        bin/EFTPXL.ATR: the sources as Mac/65 takes them
#   make test       tools/test_sim.py (pip install py65 pyftpdlib)
#
# bin/ and dist/ are what make builds, never committed: releases carry
# the program (.github/workflows/release.yml). VERSION in ASM/EFTPXL.ASM
# holds the last release, which every build shows.

ATASM      ?= atasm
PYTHON     ?= python3
PROGRAM    := bin/EFTPXL.PRG
SRCS       := $(wildcard ASM/*.ASM)

.PHONY: all dist atr test clean

all: $(PROGRAM)

# The main file names its parts as Mac/65 on the Atari does,
# ".INCLUDE #D:SCREEN.M65"; ATasm gets them as ASM/SCREEN.ASM.
$(PROGRAM): Makefile $(SRCS)
	mkdir -p bin
	sed -e 's/#D:\([A-Z0-9]*\)\.M65/\1.ASM/' \
	    ASM/EFTPXL.ASM > bin/EFTPXL.ASM
	$(ATASM) -s -mac65 -IASM -o$@ bin/EFTPXL.ASM > bin/EFTPXL.LST

ASM/FONT.ASM: fonts/EFTPXL.FNT tools/font2asm.py
	$(PYTHON) tools/font2asm.py

# the sources (and the program) on an Atari disk, SpartaDOS double
# density; ATasm must build the same program from what is on it
SRCATR     := bin/EFTPXL.ATR

atr: $(SRCATR)

$(SRCATR): $(PROGRAM) tools/atari_src.py tools/sparta.py tools/mac65tok.py tools/disk/*
	rm -rf bin/atr
	mkdir -p bin/atr
	$(PYTHON) tools/atari_src.py $@ $(SRCS) $(PROGRAM)
	$(PYTHON) tools/atari_src.py --check --to bin/atr $@ > /dev/null
	sed -e 's/#D:\([A-Z0-9]*\)\.M65/\1.ASM/' \
	    bin/atr/EFTPXL.ASM > bin/atr/MAIN.ASM
	cd bin/atr && $(ATASM) -s -mac65 -oCHECK.PRG MAIN.ASM > /dev/null
	cmp bin/atr/CHECK.PRG $(PROGRAM)
	rm -rf bin/atr

test: all
	$(PYTHON) tools/test_sim.py

dist: all atr
	rm -rf dist
	mkdir -p dist
	cp $(PROGRAM) $(SRCATR) dist/

clean:
	rm -rf bin dist
