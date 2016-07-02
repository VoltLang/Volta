// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.object;

static import object;

import core.typeinfo;


/+
alias string = immutable(char)[];
alias wstring = immutable(wchar)[];
alias dstring = immutable(dchar)[];

version (V_P64) {
	alias size_t = ulong;
	alias ptrdiff_t = long;
} else {
	alias size_t = uint;
	alias ptrdiff_t = int;
}
+/

alias ModuleInfo = object.ModuleInfo;
alias moduleInfoRoot = object.moduleInfoRoot;
alias Object = object.Object;
alias Attribute = object.Attribute;

extern(C):

void vrt_panic(scope const(char)[][] msg, scope const(char)[] file = __FILE__, const size_t line = __LINE__);
int vrt_run_global_ctors();
int vrt_run_main(int argc, char** argv, int function(string[]) args);
int vrt_run_global_dtors();
void* vrt_handle_cast(void* obj, TypeInfo tinfo);
uint vrt_hash(void*, size_t);
@mangledName("memcmp") int vrt_memcmp(void*, void*, size_t);
