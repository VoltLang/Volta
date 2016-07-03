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
 * For those very bad times.
 */
extern(C) {
	void vrt_panic(scope const(char)[][] msg, scope const(char)[] file = __FILE__, const size_t line = __LINE__);
}

/*
 * Language util functions
 */
extern(C) {
	void* vrt_handle_cast(void* obj, TypeInfo tinfo);
	uint vrt_hash(void*, size_t);
	@mangledName("memcmp") int vrt_memcmp(void*, void*, size_t);
}

/*
 * Starting up.
 */
extern(C) {
	int vrt_run_global_ctors();
	int vrt_run_main(int argc, char** argv, int function(string[]) args);
	int vrt_run_global_dtors();
}

/*
 * Exception handling functions
 */
extern(C) {
	void vrt_eh_throw(Throwable, string filename, size_t line);
	void vrt_eh_throw_slice_error(string filename, size_t line);
	void vrt_eh_personality_v0();
}

/*
 * AA functions
 */
extern(C) {
	void* vrt_aa_new(TypeInfo value, TypeInfo key);
	void* vrt_aa_dup(void* rbtv);
	bool vrt_aa_in_primitive(void* rbtv, ulong key, void* ret);
	bool vrt_aa_in_array(void* rbtv, void[] key, void* ret);
	void vrt_aa_insert_primitive(void* rbtv, ulong key, void* value);
	void vrt_aa_insert_array(void* rbtv, void[] key, void* value);
	bool vrt_aa_delete_primitive(void* rbtv, ulong key);
	bool vrt_aa_delete_array(void* rbtv, void[] key);
	void[] vrt_aa_get_keys(void* rbtv);
	void[] vrt_aa_get_values(void* rbtv);
	size_t vrt_aa_get_length(void* rbtv);
	void* vrt_aa_in_binop_array(void* rbtv, void[] key);
	void* vrt_aa_in_binop_primitive(void* rbtv, ulong key);
	void vrt_aa_rehash(void* rbtv);
	ulong vrt_aa_get_pp(void* rbtv, ulong key, ulong _default);
	void[] vrt_aa_get_aa(void* rbtv, void[] key, void[] _default);
	ulong vrt_aa_get_ap(void* rbtv, void[] key, ulong _default);
	void[] vrt_aa_get_pa(void* rbtv, ulong key, void[] _default);
}

/*
 * Unicode functions.
 */
extern (C) {
	dchar vrt_decode_u8_d(string str, ref size_t index);
	dchar vrt_reverse_decode_u8_d(string str, ref size_t index);
}

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
