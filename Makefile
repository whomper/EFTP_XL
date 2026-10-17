# EFTP_XL build: the Mac/65 sources in ASM/, assembled with xl/'s
# mac65.py, which makes the same program as MAC/65 1.01 on the Atari.
#
#   make            bin/EFTPXL.PRG
#   make atr        bin/EFTPXL.ATR: the bootable disk, the sources as
#                   Mac/65 takes them; they must give the same program
#   make test       xl/'s tests and tools/test_sim.py
#   make dist       a release's files in dist/ (the program, its
#                   disk, AERA.FNT and EFTPTEST.ATR, the test disk)
#   make version    the version every build shows (x.y)
#
# pip install -r xl/requirements.txt -r requirements.txt
#
# bin/ and dist/ are what make builds, never committed: releases carry
# the program (.github/workflows/release.yml). VERSION in ASM/EFTPXL.M65
# holds the last release.

PYTHON     ?= python3
MAC65      := $(PYTHON) xl/tools/mac65.py
SRC        := $(PYTHON) xl/tools/atari_src.py
PROGRAM    := bin/EFTPXL.PRG
FONTFILE   := xl/font/AERA.FNT
DISK       := bin/EFTPXL.ATR
TESTDISK   := bin/EFTPTEST.ATR
SRCS       := $(wildcard ASM/*.M65)
VERSION    := $(shell sed -n 's/^VERSION *\.BYTE "EFTP_XL \([^"]*\)".*/\1/p' ASM/EFTPXL.M65)
# the shared includes the program uses, as its main file names them
AXSRCS     := $(patsubst %,xl/src/%.M65,$(shell sed -n \
                's/^ *\.INCLUDE #D:\(AX[A-Z0-9]*\)\.M65.*/\1/p' ASM/EFTPXL.M65))

.PHONY: all atr test dist version clean

all: $(PROGRAM)

# mac65.py finds each .INCLUDE #D:NAME.M65 next to the main file, so
# the program's files and xl/'s go together in bin/src
$(PROGRAM): Makefile $(SRCS) $(AXSRCS) xl/tools/mac65.py
	rm -rf bin/src
	mkdir -p bin/src
	cp $(SRCS) $(AXSRCS) bin/src/
	$(MAC65) bin/src/EFTPXL.M65 -o $@ -l bin/EFTPXL.LST > /dev/null

# the disk: SpartaDOS 3.2, the sources numbered and tokenized, the
# program and the font; what is on it must build the same program
atr: $(DISK)

$(DISK): $(PROGRAM) $(FONTFILE) $(SRCS) $(AXSRCS) xl/tools/*.py
	$(SRC) disk $@ --program EFTP_XL --version $(VERSION) \
	    $(SRCS) $(AXSRCS) $(PROGRAM) $(FONTFILE) > /dev/null
	rm -rf bin/atr
	mkdir -p bin/atr
	$(SRC) check --to bin/atr $@ > /dev/null
	$(MAC65) bin/atr/EFTPXL.M65 -o bin/atr/CHECK.PRG > /dev/null
	cmp bin/atr/CHECK.PRG $(PROGRAM)
	rm -rf bin/atr

# the test disk for real hardware: the program, the font, the test
# plan (docs/TESTPLAN.TXT), a site and the files the plan sends
$(TESTDISK): $(PROGRAM) $(FONTFILE) docs/TESTPLAN.TXT tools/testdisk.py xl/tools/*.py
	$(PYTHON) tools/testdisk.py bin/testdisk $(VERSION) > /dev/null
	$(SRC) disk $@ --program EFTP_XL --version $(VERSION) --volume EFTPTEST \
	    --tree bin/testdisk $(PROGRAM) $(FONTFILE) > /dev/null
	rm -rf bin/testdisk

test: $(PROGRAM) $(DISK) $(TESTDISK)
	$(PYTHON) xl/tests/test_tools.py
	$(PYTHON) xl/tests/test_ax.py
	$(PYTHON) xl/tests/test_sim.py
	$(PYTHON) tools/test_sim.py

dist: $(PROGRAM) $(DISK) $(FONTFILE) $(TESTDISK)
	rm -rf dist
	mkdir -p dist
	cp $(PROGRAM) $(DISK) $(FONTFILE) $(TESTDISK) dist/

version:
	@echo $(VERSION)

clean:
	rm -rf bin dist
