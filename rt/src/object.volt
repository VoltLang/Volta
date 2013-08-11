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


@interface MangledName
{
	string name;
}

extern(C) void vrt_gc_init();
extern(C) AllocDg vrt_gc_get_alloc_dg();
extern(C) void vrt_gc_shutdown();
extern(C) void* vrt_handle_cast(void* obj, TypeInfo tinfo);
extern(C) void vrt_eh_throw(Throwable);
extern(C) uint vrt_hash(string);

extern(C) void* vrt_aa_new(TypeInfo value);
extern(C) bool vrt_aa_in_primitive(void* rbtv, ulong key, void* ret);
extern(C) bool vrt_aa_in_array(void* rbtv, void[] key, void* ret);
extern(C) void vrt_aa_insert_primitive(void* rbtv, ulong key, void* value);
extern(C) void vrt_aa_insert_array(void* rbtv, void[] key, void* value);
extern(C) bool vrt_aa_delete_primitive(void* rbtv, ulong key);
extern(C) bool vrt_aa_delete_array(void* rbtv, void[] key);

extern(C) {
	@MangledName("memcmp") int __llvm_memcmp(void*, void*, size_t);
	@MangledName("llvm.trap") void __llvm_trap();
	@MangledName("llvm.memcpy.p0i8.p0i8.i32") void __llvm_memcpy_p0i8_p0i8_i32(void*, void*, uint, int, bool);
	@MangledName("llvm.memcpy.p0i8.p0i8.i64") void __llvm_memcpy_p0i8_p0i8_i64(void*, void*, ulong, int, bool);
	@MangledName("llvm.memmove.p0i8.p0i8.i32") void __llvm_memmove_p0i8_p0i8_i32(void*, void*, uint, int, bool);
	@MangledName("llvm.memmove.p0i8.p0i8.i64") void __llvm_memmove_p0i8_p0i8_i64(void*, void*, ulong, int, bool);
}
