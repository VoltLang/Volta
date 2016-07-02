// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.object;

static import __volta;

import core.typeinfo;


alias ModuleInfo = __volta.ModuleInfo;
alias moduleInfoRoot = __volta.moduleInfoRoot;
alias Object = __volta.Object;
alias Attribute = __volta.Attribute;

extern(C):

void vrt_panic(scope const(char)[][] msg, scope const(char)[] file = __FILE__, const size_t line = __LINE__);
int vrt_run_global_ctors();
int vrt_run_main(int argc, char** argv, int function(string[]) args);
int vrt_run_global_dtors();
void* vrt_handle_cast(void* obj, TypeInfo tinfo);
uint vrt_hash(void*, size_t);
@mangledName("memcmp") int vrt_memcmp(void*, void*, size_t);
