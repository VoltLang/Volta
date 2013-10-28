# Makefile for windows.
# Intended for Digital Mars Make and GNU Make.
# If using the latter, make sure to specify -fMakefile.

RDMD=rdmd
DMD=dmd
EXE=volt.exe
DFLAGS=--build-only --compiler=$(DMD) -of$(EXE) -gc -wi -debug LLVM.lib $(FLAGS)

# rules
all:
	$(RDMD) $(DFLAGS) src\main.d
	./volt --no-stdlib --emit-bitcode -I rt/src -o rt/rt.bc rt/src/object.volt rt/src/vrt/vmain.volt rt/src/vrt/gc.volt rt/src/vrt/clazz.volt rt/src/vrt/eh.volt rt/src/vrt/hash.volt rt/src/vrt/aa.volt

.PHONY: all
