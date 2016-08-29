// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.typeinfo;


enum Type
{
	Struct = 1,
	Class = 2,
	Interface = 3,
	Union = 4,
	Enum = 5,
	Attribute = 6,

	Void = 8,
	U8 = 9,
	I8 = 10,
	Char = 12,
	Bool = 13,
	U16 = 14,
	I16 = 15,
	Wchar = 16,
	U32 = 17,
	I32 = 18,
	Dchar = 19,
	F32 = 20,
	U64 = 21,
	I64 = 22,
	F64 = 23,
	Real = 24,

	Pointer = 25,
	Array = 26,
	StaticArray = 27,
	AA = 28,
	Function = 29,
	Delegate = 30,
}

class TypeInfo
{
	size: size_t;
	type: int;
	mangledName: char[];
	mutableIndirection: bool;
	classInit: void*;
	classSize: size_t;
	base: TypeInfo;  // For arrays (dynamic and static), and pointers.
	staticArrayLength: size_t;
	key, value: TypeInfo;  // For AAs.
	ret: TypeInfo;  // For functions and delegates.
	args: TypeInfo[];  // For functions and delegates.
}

class ClassInfo : TypeInfo
{
	interfaces: InterfaceInfo[];
}

class InterfaceInfo
{
	info: TypeInfo;
	offset: size_t;
}
