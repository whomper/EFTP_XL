# FTP_XL build. Needs a recent cc65 (built from git; the 2.19 release is too
# old for fujinet-lib) on the PATH.

CL65       ?= cl65
PROGRAM    := bin/FTPXL.XEX
SRCS       := src/main.c

# Load address. Above SpartaDOS 3.x / DOS 2.5 MEMLO with room to spare;
# lower it to gain RAM once MEMLO on your setup is known.
START_ADDR ?= 0x3000

FNLIB_DIR  := fujinet-lib
FNLIB      := $(FNLIB_DIR)/r2r/atari/fujinet.atari.lib

CFLAGS     := -t atari -O -W error -I $(FNLIB_DIR)/include
LDFLAGS    := --start-addr $(START_ADDR)

.PHONY: all clean distclean

all: $(PROGRAM)

$(PROGRAM): $(SRCS) $(FNLIB)
	mkdir -p bin
	$(CL65) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS) $(FNLIB)

$(FNLIB):
	$(MAKE) -C $(FNLIB_DIR) atari

clean:
	rm -f $(PROGRAM) src/*.o

distclean: clean
	$(MAKE) -C $(FNLIB_DIR) clean
