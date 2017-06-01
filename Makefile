# Makefile for windows.
# Intended for Digital Mars Make and GNU Make.
# If using the latter, make sure to specify -fMakefile.

include sources.mk

RDMD=rdmd
DMD=dmd
NASM=nasm
VOLT=volt.exe
VRT=rt/rt.bc
DFLAGS=--build-only --compiler=$(DMD) -of$(VOLT) -gc -wi -debug LLVM.lib $(FLAGS)
# rules
all:
	$(RDMD) $(DFLAGS) src\main.d
	$(VOLT) --no-stdlib --emit-bitcode -I rt/src -o rt/rt.bc $(RT_SRC) $(VFLAGS)
	$(VOLT) --no-stdlib -c -I rt/src -o rt/rt.o rt/rt.bc
	$(NASM) -f win64 -o rt/save-regs-host.o rt/src/vrt/gc/save_regs.asm
	$(NASM) -f win64 -o rt/eh.o rt/src/vrt/os/eh.asm


.PHONY: all viv viviv

