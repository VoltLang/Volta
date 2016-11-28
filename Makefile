# Makefile for windows.
# Intended for Digital Mars Make and GNU Make.
# If using the latter, make sure to specify -fMakefile.

include sources.mk

RDMD=rdmd
DMD=dmd
VOLT=volt.exe
VRT=rt/rt.bc
DFLAGS=--build-only --compiler=$(DMD) -of$(VOLT) -gc -wi -debug LLVM.lib $(FLAGS)
# rules
all:
	$(RDMD) $(DFLAGS) src\main.d
	$(VOLT) --no-stdlib --emit-bitcode -I rt/src -o rt/rt.bc $(RT_SRC) $(VFLAGS)
	$(VOLT) --no-stdlib -c -I rt/src -o rt/rt.o rt/rt.bc


.PHONY: all viv viviv

