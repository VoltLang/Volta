// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module object;

/**
 * This is all up in the air. But here is how its intended to work.
 *
 * @param typeinfo The type to which we should allocate storage for.
 * @param count the number of elements in a array, zero if just the type.
 *
 * The count logic is a bit odd. If count is zero we are allocating the
 * storage for just the type alone, if count is greater then one we are
 * allocating the storage an array of that type. Here how it is done,
 * Thow following shows what happends for some cases.
 *
 * For primitive types:
 * int* ptr = new int;
 * int* ptr = allocDg(typeid(int), 0);
 * // Alloc size == int.sizeof == 4
 *
 * While for arrays:
 * int[] arr; arr.length = 5;
 * int[] arr; { arr.ptr = allocDg(typeid(int), 5); arr.length = 5 }
 * // Alloc size == int.sizeof * 5 == 20
 *
 * Classes are weird, tho in the normal case not so much but notice the -1.
 * Clazz foo = new Clazz();
 * Clazz foo = allocDg(typeid(Clazz), cast(size_t)-1);
 * // Alloc size == Clazz.storage.sizeof
 *
 * Here its where it gets weird: this is because classes are references.
 * Clazz foo = new Clazz;
 * Clazz foo = allocDg(typeid(Clazz), 0);
 * // Alloc size == (void*).sizeof
 *
 * And going from that this makes sense.
 * Clazz[] arr; arr.length = 3;
 * Clazz[] arr; { arr.ptr = allocDg(typeid(Clazz), 3); arr.length = 3 }
 * // Alloc size == (void*).sizeof * 3
 */
alias AllocDg = void* delegate(TypeInfo typeinfo, size_t count);
local AllocDg allocDg;


struct ArrayStruct
{
	void* ptr;
	size_t length;
}

enum
{
	TYPE_STRUCT = 1,
	TYPE_CLASS = 2,
	TYPE_INTERFACE = 3,
	TYPE_UNION = 4,
	TYPE_ENUM = 5,
	TYPE_ATTRIBUTE = 6,
	TYPE_USER_ATTRIBUTE = 7,

	TYPE_VOID = 8,
	TYPE_UBYTE = 9,
	TYPE_BYTE = 10,
	TYPE_CHAR = 12,
	TYPE_BOOL = 13,
	TYPE_USHORT = 14,
	TYPE_SHORT = 15,
	TYPE_WCHAR = 16,
	TYPE_UINT = 17,
	TYPE_INT = 18,
	TYPE_DCHAR = 19,
	TYPE_FLOAT = 20,
	TYPE_ULONG = 21,
	TYPE_LONG = 22,
	TYPE_DOUBLE = 23,
	TYPE_REAL = 24,

	TYPE_POINTER = 25,
	TYPE_ARRAY = 26,
	TYPE_STATIC_ARRAY = 27,
	TYPE_AA = 28,
	TYPE_FUNCTION = 29,
	TYPE_DELEGATE = 30,
}

class TypeInfo
{
	this()
	{
		return;
	}

	size_t size;
	int type;
	char[] mangledName;
	bool mutableIndirection;
	void* classVtable;
	size_t classSize;
	TypeInfo base;  // For arrays (dynamic and static), and pointers.
	size_t staticArrayLength;
	TypeInfo key, value;  // For AAs.
	TypeInfo ret;  // For functions and delegates.
	TypeInfo[] args;  // For functions and delegates.
}

class Object
{
	this()
	{
		return;
	}

	~this()
	{
		return;
	}

	string toString()
	{
		return "object.Object";
	}
}

class Attribute
{
	this()
	{
		return;
	}
}


/*
 *
 * Exceptions
 *
 */


class Throwable
{
	string message;

	this(string message)
	{
		this.message = message;
		return;
	}
}

class Exception : Throwable
{
	this(string message)
	{
		super(message);
		return;
	}
}

class Error : Throwable
{
	this(string message)
	{
		super(message);
		return;
	}
}

class AssertError : Error
{
	this(string message)
	{
		super(message);
		return;
	}
}

// Thrown if Key does not exist in AA
// TODO: move to core.exception (llvmlowerer!)
class KeyNotFoundException : Exception
{
	this(string message)
	{
		super(message);
		return;
	}
}


/*
 *
 * Runtime and internal helpers.
 *
 */

extern(C) void vrt_gc_init();
extern(C) AllocDg vrt_gc_get_alloc_dg();
extern(C) void vrt_gc_shutdown();
extern(C) void* vrt_handle_cast(void* obj, TypeInfo tinfo);
extern(C) void vrt_eh_throw(Throwable);
extern(C) uint vrt_hash(void*, size_t);
extern(C) void vrt_throw_slice_error(size_t length, size_t targetSize, string file, size_t line)
{
	if ((length % targetSize) != 0) {
		throw new Error("invalid array cast");
	}
	return;
}

extern(C) void* vrt_aa_new(TypeInfo value);
extern(C) bool vrt_aa_in_primitive(void* rbtv, ulong key, void* ret);
extern(C) bool vrt_aa_in_array(void* rbtv, void[] key, void* ret);
extern(C) void vrt_aa_insert_primitive(void* rbtv, ulong key, void* value);
extern(C) void vrt_aa_insert_array(void* rbtv, void[] key, void* value);
extern(C) bool vrt_aa_delete_primitive(void* rbtv, ulong key);
extern(C) bool vrt_aa_delete_array(void* rbtv, void[] key);
extern(C) void* vrt_aa_get_keys(void* rbtv);
extern(C) void* vrt_aa_get_values(void* rbtv);
extern(C) size_t vrt_aa_get_length(void* rbtv);
extern(C) void* vrt_aa_in_binop_array(void* rbtv, void[] key);
extern(C) void* vrt_aa_in_binop_primitive(void* rbtv, ulong key);
extern(C) void vrt_aa_rehash(void* rbtv);
extern(C) ulong vrt_aa_get_pp(void* rbtv, ulong key, ulong _default);
extern(C) void[] vrt_aa_get_aa(void* rbtv, void[] key, void[] _default);
extern(C) ulong vrt_aa_get_ap(void* rbtv, void[] key, ulong _default);
extern(C) void[] vrt_aa_get_pa(void* rbtv, ulong key, void[] _default);

// Calls to these are replaced by the compiler.
extern(C) void __volt_va_start(void** vl, void* _args);
extern(C) void __volt_va_end(void** vl);

extern(C) {
	@mangledName("memcmp") int __llvm_memcmp(void*, void*, size_t);
	@mangledName("llvm.trap") void __llvm_trap();
	@mangledName("llvm.memcpy.p0i8.p0i8.i32") void __llvm_memcpy_p0i8_p0i8_i32(void*, void*, uint, int, bool);
	@mangledName("llvm.memcpy.p0i8.p0i8.i64") void __llvm_memcpy_p0i8_p0i8_i64(void*, void*, ulong, int, bool);
	@mangledName("llvm.memmove.p0i8.p0i8.i32") void __llvm_memmove_p0i8_p0i8_i32(void*, void*, uint, int, bool);
	@mangledName("llvm.memmove.p0i8.p0i8.i64") void __llvm_memmove_p0i8_p0i8_i64(void*, void*, ulong, int, bool);
	@mangledName("llvm.va_start") void __llvm_volt_va_start(void*);
	@mangledName("llvm.va_end") void __llvm_volt_va_end(void*);
}

