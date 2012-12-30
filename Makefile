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
	./volt -c -o rt/rt.o rt/src/object.d rt/src/vrt/vmain.d rt/src/vrt/gc.d

.PHONY: all
