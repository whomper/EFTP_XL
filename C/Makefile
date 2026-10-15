# EFTP_XL in C (cc65): the first version, kept for reference; the program
# is now in assembly (../ASM). Needs a recent cc65 (built from git; the
# 2.19 release is too old for fujinet-lib) on the PATH.
#
#   make            bin/EFTPXL.XEX
#   make dist       a release's files in dist/
#
# bin/ is what make builds, never committed. Releases are of the
# assembly version; this one is not built by CI.

CL65       ?= cl65
PROGRAM    := bin/EFTPXL.XEX
SRCS       := src/main.c src/screen.c src/pane.c src/local.c src/remote.c \
              src/sites.c src/xfer.c src/ftp.c src/cio.s src/font.s

# Load address, 1K-aligned (the font comes first): cc65's default. DOS
# 2.5's and SpartaDOS 3's MEMLO are below $1E00, where EDOS loads; if a
# DOS's is higher, cc65's loader check says so.
START_ADDR ?= 0x2000

FNLIB_DIR  := fujinet-lib
FNLIB      := $(FNLIB_DIR)/r2r/atari/fujinet.atari.lib

CFLAGS     := -t atari -O -W error -I $(FNLIB_DIR)/include --bin-include-dir ../fonts $(if $(RELEASE),-D RELEASE)
LDFLAGS    := --start-addr $(START_ADDR) -C src/eftpxl.cfg

# whether the last build was a release, so that changing RELEASE rebuilds
RELFLAG    := bin/release.flag

.PHONY: all dist clean distclean FORCE

all: $(PROGRAM)

$(PROGRAM): Makefile $(SRCS) src/*.h src/eftpxl.cfg ../fonts/EFTPXL.FNT $(FNLIB) $(RELFLAG)
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
