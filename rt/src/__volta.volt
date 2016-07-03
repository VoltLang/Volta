// Copyright © 2012-2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module __volta;

import core.exception;
import core.typeinfo;


/*
 *
 * Misc
 *
 */

struct ArrayStruct
{
	size_t length;
	void* ptr;
}


/*
 *
 * Runtime and internal helpers.
 *
 */

/*
 * Variadic arguments functions.
 * Calls to these are replaced by the compiler.
 */
extern(C) {
	void __volt_va_start(void** vl, void* _args);
	void __volt_va_end(void** vl);
}

/*
 * LLVM backend functions.
 */
extern(C) {
	@mangledName("llvm.trap") void __llvm_trap();
	@mangledName("llvm.memset.p0i8.i32") void __llvm_memset_p0i8_i32(void* dest, ubyte val, uint len, int _align, bool _volatile);
	@mangledName("llvm.memset.p0i8.i64") void __llvm_memset_p0i8_i64(void* dest, ubyte val, ulong len, int _align, bool _volatile);
	@mangledName("llvm.memcpy.p0i8.p0i8.i32") void __llvm_memcpy_p0i8_p0i8_i32(void* dest, void* src, uint len, int _align, bool _volatile);
	@mangledName("llvm.memcpy.p0i8.p0i8.i64") void __llvm_memcpy_p0i8_p0i8_i64(void* dest, void* src, ulong len, int _align, bool _volatile);
	@mangledName("llvm.memmove.p0i8.p0i8.i32") void __llvm_memmove_p0i8_p0i8_i32(void* dest, void* src, uint len, int _align, bool _volatile);
	@mangledName("llvm.memmove.p0i8.p0i8.i64") void __llvm_memmove_p0i8_p0i8_i64(void* dest, void* src, ulong len, int _align, bool _volatile);
	@mangledName("llvm.va_start") void __llvm_volt_va_start(void*);
	@mangledName("llvm.va_end") void __llvm_volt_va_end(void*);
	@mangledName("llvm.eh.typeid.for") int __llvm_typeid_for(void*);
	version (V_P32) {
		alias __llvm_memset = __llvm_memset_p0i8_i32;
		alias __llvm_memcpy = __llvm_memcpy_p0i8_p0i8_i32;
		alias __llvm_memmove = __llvm_memmove_p0i8_p0i8_i32;
	} else version (V_P64) {
		alias __llvm_memset = __llvm_memset_p0i8_i64;
		alias __llvm_memcpy = __llvm_memcpy_p0i8_p0i8_i64;
		alias __llvm_memmove = __llvm_memmove_p0i8_p0i8_i64;
	} else {
		static assert(false);
	}
}
