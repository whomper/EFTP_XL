# EFTP_XL build. Needs a recent cc65 (built from git; the 2.19 release is too
# old for fujinet-lib) on the PATH.
#
#   make            bin/EFTPXL.XEX
#   make dist       a release's files in dist/
#
# bin/ is what make builds, never committed: releases carry the program
# (.github/workflows/release.yml). VERSION in src/main.c holds the last
# release, which a release build (RELEASE=1) shows; others show "x.y-dev".

CL65       ?= cl65
PROGRAM    := bin/EFTPXL.XEX
SRCS       := src/main.c src/screen.c src/pane.c src/local.c src/remote.c \
              src/sites.c src/ftp.c src/cio.s src/font.s

# Load address. Above SpartaDOS 3.x / DOS 2.5 MEMLO with room to spare;
# lower it to gain RAM once MEMLO on your setup is known.
START_ADDR ?= 0x3000

FNLIB_DIR  := fujinet-lib
FNLIB      := $(FNLIB_DIR)/r2r/atari/fujinet.atari.lib

CFLAGS     := -t atari -O -W error -I $(FNLIB_DIR)/include --bin-include-dir fonts $(if $(RELEASE),-D RELEASE)
LDFLAGS    := --start-addr $(START_ADDR) -C src/eftpxl.cfg

# whether the last build was a release, so that changing RELEASE rebuilds
RELFLAG    := bin/release.flag

.PHONY: all dist clean distclean FORCE

all: $(PROGRAM)

$(PROGRAM): $(SRCS) src/*.h src/eftpxl.cfg fonts/EFTPXL.FNT $(FNLIB) $(RELFLAG)
	mkdir -p bin
	$(CL65) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS) $(FNLIB)

$(RELFLAG): FORCE
	@mkdir -p bin
	@echo "$(RELEASE)" > $@.new
	@if cmp -s $@.new $@; then rm $@.new; else mv $@.new $@; fi
FORCE:

dist: all
	rm -rf dist
	mkdir -p dist
	cp $(PROGRAM) dist/

$(FNLIB):
	$(MAKE) -C $(FNLIB_DIR) atari

clean:
	rm -rf bin dist src/*.o

distclean: clean
	$(MAKE) -C $(FNLIB_DIR) clean
