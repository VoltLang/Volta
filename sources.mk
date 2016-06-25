
RT_SRC = \
	rt/src/core/rt/gc.volt \
	rt/src/vrt/vacuum/clazz.volt \
	rt/src/vrt/vacuum/vmain.volt \
	rt/src/vrt/vacuum/hash.volt \
	rt/src/vrt/vacuum/utf.volt \
	rt/src/vrt/vacuum/aa.volt \
	rt/src/vrt/ext/unwind.volt \
	rt/src/vrt/ext/dwarf.volt \
	rt/src/vrt/ext/stdc.volt \
	rt/src/vrt/os/panic.volt \
	rt/src/vrt/os/vmain.volt \
	rt/src/vrt/os/gtors.volt \
	rt/src/vrt/os/gc.volt \
	rt/src/vrt/os/gc_stub.volt \
	rt/src/vrt/os/eh.volt \
	rt/src/vrt/os/eh_stub.volt \
	rt/src/defaultsymbols.volt \
	rt/src/object.volt


VIV_SRC= \
	src/volt/*.d \
	src/lib/llvm/*.d \
	src/lib/llvm/c/*.d \
	src/volt/ir/*.d \
	src/volt/util/*.d \
	src/volt/llvm/*.d \
	src/volt/token/*.d \
	src/volt/parser/*.d \
	src/volt/visitor/*.d \
	src/volt/lowerer/*.d \
	src/volt/semantic/*.d \
	src/volt/postparse/*.d \
	src/main.d
