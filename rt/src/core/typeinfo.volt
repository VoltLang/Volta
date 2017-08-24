// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.typeinfo;


/*!
 * The types of Volt, the `type` field of `TypeInfo`.
 */
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

/*!
 * Information for a type that can be retrieved at runtime.
 *
 * This is the object that the `typeid` expression returns.
 */
class TypeInfo
{
	size: size_t;  //!< The size of the type, in bytes.
	type: int;  //!< The specific type. A member of the `Type` enum.
	mangledName: char[];  //!< The Volt mangled name (if any)
	mutableIndirection: bool;  //!< Can this type mutate memory?
	classInit: void*;  //!< The class init struct, if this points at a class.
	classSize: size_t;  //!< The size of the class, if this points at a class.
	base: TypeInfo;  //!< The base type for arrays (dynamic and static), and pointers.
	staticArrayLength: size_t; //!< If this points at a static array, how long is it?
	key, value: TypeInfo;  //!< The key and value types for AAs.
	ret: TypeInfo;  //!< For functions and delegates, what's the return type?
	args: TypeInfo[];  //!< For functions and delegates, what are the parameter types?
}

/*!
 * A TypeInfo used by classes.
 */
class ClassInfo : TypeInfo
{
	interfaces: InterfaceInfo[];  //!< The interfaces the class this refers to implements.
}

/*!
 * Type information for interfaces.
 */
class InterfaceInfo
{
	info: TypeInfo;  //!< The tinfo for the pointed at interface.
	offset: size_t;  //!< How many bytes after the vtable does the information for this interface lie?
}
