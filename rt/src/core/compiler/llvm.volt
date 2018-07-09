// Copyright 2012-2016, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
//! LLVM intrinsic function definitions.
module core.compiler.llvm;


extern (C):

//! <http://llvm.org/docs/LangRef.html#llvm-trap-intrinsic>
@mangledName("llvm.trap") fn __llvm_trap();
version (LlvmIntrinsics1) {
	// LLVM 6 and earlier.
	//! <http://releases.llvm.org/6.0.0/docs/LangRef.html#llvm-memset-element-unordered-atomic-intrinsic>
	@mangledName("llvm.memset.p0i8.i32") fn __llvm_memset_p0i8_i32(dest: void*, val: u8, len: u32, _align: i32, _volatile: bool);
	//! <http://releases.llvm.org/6.0.0/docs/LangRef.html#llvm-memset-element-unordered-atomic-intrinsic>
	@mangledName("llvm.memset.p0i8.i64") fn __llvm_memset_p0i8_i64(dest: void*, val: u8, len: u64, _align: i32, _volatile: bool);
	//! <http://releases.llvm.org/6.0.0/docs/LangRef.html#llvm-memcpy-intrinsic>
	@mangledName("llvm.memcpy.p0i8.p0i8.i32") fn __llvm_memcpy_p0i8_p0i8_i32(dest: void*, src: void*, len: u32, _align: i32, _volatile: bool);
	//! <http://releases.llvm.org/6.0.0/docs/LangRef.html#llvm-memcpy-intrinsic>
	@mangledName("llvm.memcpy.p0i8.p0i8.i64") fn __llvm_memcpy_p0i8_p0i8_i64(dest: void*, src: void*, len: u64, _align: i32, _volatile: bool);
	//! <http://releases.llvm.org/6.0.0/docs/LangRef.html#llvm-memmove-intrinsic>
	@mangledName("llvm.memmove.p0i8.p0i8.i32") fn __llvm_memmove_p0i8_p0i8_i32(dest: void*, src: void*, len: u32, _align: i32, _volatile: bool);
	//! <http://releases.llvm.org/6.0.0/docs/LangRef.html#llvm-memmove-intrinsic>
	@mangledName("llvm.memmove.p0i8.p0i8.i64") fn __llvm_memmove_p0i8_p0i8_i64(dest: void*, src: void*, len: u64, _align: i32, _volatile: bool);
} else version (LlvmIntrinsics2) {
	// LLVM 7 and later removed the align parameter.
	//! <http://llvm.org/docs/LangRef.html#llvm-memset-element-unordered-atomic-intrinsic>
	@mangledName("llvm.memset.p0i8.i32") fn __llvm_memset_p0i8_i32(dest: void*, val: u8, len: u32, _volatile: bool);
	//! <http://llvm.org/docs/LangRef.html#llvm-memset-element-unordered-atomic-intrinsic>
	@mangledName("llvm.memset.p0i8.i64") fn __llvm_memset_p0i8_i64(dest: void*, val: u8, len: u64, _volatile: bool);
	//! <http://llvm.org/docs/LangRef.html#llvm-memcpy-intrinsic>
	@mangledName("llvm.memcpy.p0i8.p0i8.i32") fn __llvm_memcpy_p0i8_p0i8_i32(dest: void*, src: void*, len: u32, _volatile: bool);
	//! <http://llvm.org/docs/LangRef.html#llvm-memcpy-intrinsic>
	@mangledName("llvm.memcpy.p0i8.p0i8.i64") fn __llvm_memcpy_p0i8_p0i8_i64(dest: void*, src: void*, len: u64, _volatile: bool);
	//! <http://llvm.org/docs/LangRef.html#llvm-memmove-intrinsic>
	@mangledName("llvm.memmove.p0i8.p0i8.i32") fn __llvm_memmove_p0i8_p0i8_i32(dest: void*, src: void*, len: u32, _volatile: bool);
	//! <http://llvm.org/docs/LangRef.html#llvm-memmove-intrinsic>
	@mangledName("llvm.memmove.p0i8.p0i8.i64") fn __llvm_memmove_p0i8_p0i8_i64(dest: void*, src: void*, len: u64, _volatile: bool);
}
//! <http://llvm.org/docs/ExceptionHandling.html#llvm-eh-typeid-for>
@mangledName("llvm.eh.typeid.for") fn __llvm_typeid_for(void*) i32;

version (V_P32) {
	version (LlvmIntrinsics1) {
		alias __llvm_memset = __llvm_memset_p0i8_i32;
		alias __llvm_memcpy = __llvm_memcpy_p0i8_p0i8_i32;
		alias __llvm_memmove = __llvm_memmove_p0i8_p0i8_i32;
	} else version (LlvmIntrinsics2) {
		fn __llvm_memset(dest: void*, val: u8, len: u32, _align: i32, _volatile: bool)
		{
			__llvm_memset_p0i8_i32(dest, val, len, true);
		}

		fn __llvm_memcpy(dest: void*, src: void*, len: u32, _align: i32 , _volatile: bool)
		{
			__llvm_memcpy_p0i8_p0i8_i32(dest, src, len, true);
		}

		fn __llvm_memmove(dest: void*, src: void*, len: u32, _align: i32 , _volatile: bool)
		{
			__llvm_memmove_p0i8_p0i8_i32(dest, src, len, true);
		}
	}
} else version (V_P64) {
	version (LlvmIntrinsics1) {
		alias __llvm_memset = __llvm_memset_p0i8_i64;
		alias __llvm_memcpy = __llvm_memcpy_p0i8_p0i8_i64;
		alias __llvm_memmove = __llvm_memmove_p0i8_p0i8_i64;
	} else version (LlvmIntrinsics2) {
		fn __llvm_memset(dest: void*, val: u8, len: u64, _align: i32, _volatile: bool)
		{
			__llvm_memset_p0i8_i64(dest, val, len, true);
		}

		fn __llvm_memcpy(dest: void*, src: void*, len: u64, _align: i32 , _volatile: bool)
		{
			__llvm_memcpy_p0i8_p0i8_i64(dest, src, len, true);
		}

		fn __llvm_memmove(dest: void*, src: void*, len: u64, _align: i32 , _volatile: bool)
		{
			__llvm_memmove_p0i8_p0i8_i64(dest, src, len, true);
		}
	}
} else {
	static assert(false);
}
