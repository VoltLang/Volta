# Makefile for windows.
# Intended for Digital Mars Make and GNU Make.
# If using the latter, make sure to specify -fMakefile.

RDMD=rdmd
DMD=dmd
VOLT=volt.exe
VRT=rt/rt.bc
DFLAGS=--build-only --compiler=$(DMD) -of$(EXE) -gc -wi -debug LLVM.lib $(FLAGS)
RT_SRC = \
	rt/src/object.volt \
	rt/src/vrt/vmain.volt \
	rt/src/vrt/gc.volt \
	rt/src/vrt/clazz.volt \
	rt/src/vrt/hash.volt \
	rt/src/vrt/aa.volt \
	rt/src/vrt/eh.volt \
	rt/src/vrt/eh_stub.volt \
	rt/src/vrt/unwind.volt \
	rt/src/vrt/dwarf.volt
VIV_SRC= \
	src/volt/main.volt \
	src/volt/errors.d \
	src/volt/exceptions.d \
	src/volt/interfaces.d \
	src/volt/ir/*.d \
	src/volt/util/string.d \
	src/volt/token/*.d \
	src/volt/parser/*.d \
	src/volt/visitor/manip.d \
	src/volt/visitor/visitor.d \
	src/volt/semantic/condremoval.d

# rules
all:
	$(RDMD) $(DFLAGS) src\main.d
	$(VOLT) --no-stdlib --emit-bitcode -I rt/src -o rt/rt.bc $(RT_SRC) $(VFLAGS)

viv:
	$(VOLT) --dep-argtags -o viv $(VIV_SRC)

.PHONY: all viv

