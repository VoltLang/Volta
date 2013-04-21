# Makefile for windows.
# Intended for Digital Mars Make and GNU Make.
# If using the latter, make sure to specify -fMakefile.

RDMD=rdmd
DMD=dmd
EXE=volt.exe
DFLAGS=--build-only --compiler=$(DMD) -of$(EXE) -gc -w -debug LLVM.lib $(FLAGS)

# rules
all:
	$(RDMD) $(DFLAGS) src\main.d
	./volt --no-stdlib --emit-bitcode -I rt/src -o rt/rt.bc rt/src/object.v rt/src/vrt/vmain.v rt/src/vrt/gc.v rt/src/vrt/clazz.v rt/src/vrt/eh.v

.PHONY: all
