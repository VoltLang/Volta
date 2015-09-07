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

viv:
	$(VOLT) --internal-d -o viv.exe $(VIV_SRC) $(VFLAGS)
	viv src/*.d src/lib/llvm/*.d src/lib/llvm/c/*.d src/volt/*.d src/volt/ir/*.d src/volt/llvm/*.d src/volt/parser/*.d src/volt/semantic/*.d src/volt/token/*.d src/volt/util/*.d src/volt/visitor/*.d

.PHONY: all viv

