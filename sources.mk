
RT_SRC = \
	rt/src/object.volt \
	rt/src/vrt/vmain.volt \
	rt/src/vrt/gc.volt \
	rt/src/vrt/gc_stub.volt \
	rt/src/vrt/clazz.volt \
	rt/src/vrt/hash.volt \
	rt/src/vrt/aa.volt \
	rt/src/vrt/eh.volt \
	rt/src/vrt/eh_stub.volt \
	rt/src/vrt/unwind.volt \
	rt/src/vrt/dwarf.volt

VIV_SRC= \
	src/volt/errors.d \
	src/volt/exceptions.d \
	src/volt/interfaces.d \
	src/volt/ir/*.d \
	src/volt/util/string.d \
	src/volt/util/worktracker.d \
	src/volt/token/*.d \
	src/volt/parser/*.d \
	src/volt/visitor/*.d \
	src/volt/postparse/scopereplacer.d \
	src/volt/postparse/condremoval.d \
	src/volt/semantic/ctfe.d \
	src/volt/semantic/strace.d \
	src/volt/semantic/mangle.d \
	src/volt/semantic/lookup.d \
	src/volt/semantic/nested.d \
	src/volt/semantic/context.d \
	src/volt/semantic/classify.d \
	src/volt/semantic/overload.d \
	src/volt/semantic/util.d \
	src/volt/semantic/typer.d \
	src/volt/main.volt
