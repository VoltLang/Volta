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
	UserAttribute = 7,

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
	size_t size;
	int type;
	char[] mangledName;
	bool mutableIndirection;
	void* classInit;
	size_t classSize;
	TypeInfo base;  // For arrays (dynamic and static), and pointers.
	size_t staticArrayLength;
	TypeInfo key, value;  // For AAs.
	TypeInfo ret;  // For functions and delegates.
	TypeInfo[] args;  // For functions and delegates.
}

class ClassInfo : TypeInfo
{
	InterfaceInfo[] interfaces;
}

class InterfaceInfo
{
	TypeInfo info;
	size_t offset;
}
