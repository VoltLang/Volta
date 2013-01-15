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
	./volt --emit-bitcode -o rt/rt.bc rt/src/object.d rt/src/vrt/vmain.d rt/src/vrt/gc.d

# Only works with Digital Mar's make. Make it into
# one line for GNU (join commands with &&).
test:
	cd test
	$(DMD) runner
	runner

.PHONY: all test
