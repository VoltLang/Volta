// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.compiler.llvm;


extern (C):

@mangledName("llvm.trap") fn __llvm_trap();
@mangledName("llvm.memset.p0i8.i32") fn __llvm_memset_p0i8_i32(dest: void*, val: u8, len: u32, _align: i32, _volatile: bool);
@mangledName("llvm.memset.p0i8.i64") fn __llvm_memset_p0i8_i64(dest: void*, val: u8, len: u64, _align: i32, _volatile: bool);
@mangledName("llvm.memcpy.p0i8.p0i8.i32") fn __llvm_memcpy_p0i8_p0i8_i32(dest: void*, src: void*, len: u32, _align: i32 , _volatile: bool);
@mangledName("llvm.memcpy.p0i8.p0i8.i64") fn __llvm_memcpy_p0i8_p0i8_i64(dest: void*, src: void*, len: u64, _align: i32 , _volatile: bool);
@mangledName("llvm.memmove.p0i8.p0i8.i32") fn __llvm_memmove_p0i8_p0i8_i32(dest: void*, src: void*, len: u32, _align: i32 , _volatile: bool);
@mangledName("llvm.memmove.p0i8.p0i8.i64") fn __llvm_memmove_p0i8_p0i8_i64(dest: void*, src: void*, len: u64, _align: i32 , _volatile: bool);
@mangledName("llvm.eh.typeid.for") fn __llvm_typeid_for(void*) i32;

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
