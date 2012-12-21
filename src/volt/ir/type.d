// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.type;

import volt.ir.base;
import volt.ir.declaration;


/**
 * @defgroup irType IR Type Nodes
 *
 * Used to express the types of the Volt Language.
 *
 * A Type, in broad terms, defines how an instance
 * of that type manifests in memory. Various passes
 * work with Types to assign and ensure the semantic 
 * meaning of the program. 
 *
 * Volt is a statically typed language. As a result,
 * all expressions have a Type. The ExpTyper pass assigns
 * types to expressions.
 *
 * All Types have to be able to be instantiated, and thus
 * well defined -- the TypeVerifier ensures all user defined
 * types (structs, classes, function's underlying function types)
 * are well defined. Where well defined means 'able to be composed
 * of other well defined types'. This is not circular, as there
 * are primitive types that the language knows about with no user
 * interaction.
 *
 * There are also passes that deal with Types in small ways --
 * the UserResolver associates a user defined type with a Type
 * object. The MangleWriter mangles type strings. The Context
 * pass creates scopes on Types that have them.
 *
 * This module does not contain all the Types that Volt has --
 * things like structs and classes are in toplevel, as they
 * contain top level declarations, but they are also Types,
 * and are children of Type.
 *
 * @ingroup irNode
 */

/**
 * Base class for all types.
 *
 * @ingroup irNode irType
 */
abstract class Type : Node
{
public:
	string mangledName;  ///< Filled in with a pass.

protected:
	this(NodeType nt) { super(nt); }
}

/**
 * PrimitiveTypes are types that are entirely
 * well known to the compiler ahead of time. Consisting
 * mostly of integral types, the only abstract one is
 * Void, which indicates no type or (in the case of 
 * arrays and pointers) any type.
 *
 * PrimitiveTypes are mangled as follows:
 * @li @p Void is mangled as 'v'.
 * @li @p Bool is mangled as 'b'.
 * @li @p Char is mangled as 'a'.
 * @li @p Byte is mangled as 'g'.
 * @li @p Ubyte is mangled as 'h'.
 * @li @p Short is mangled as 's'.
 * @li @p Ushort is mangled as 't'.
 * @li @p Int is mangled as 'i'.
 * @li @p Uint is mangled as 'k'.
 * @li @p Long is mangled as 'l'.
 * @li @p Ulong is mangled as 'm'.
 * @li @p Float is mangled as 'f'.
 * @li @p Double is mangled as 'd'.
 * @li @p Real is mangled as 'e'.
 * PrimitiveTypes aren't mangled on their own, usually forming
 * a part of a larger composite type (e.g. a function).
 *
 * @ingroup irNode irType
 */
class PrimitiveType : Type
{
public:
	enum Kind {
		Void = TokenType.Void,
		Bool = TokenType.Bool,

		Char = TokenType.Char,
		Byte = TokenType.Byte,
		Ubyte = TokenType.Ubyte,
		Short = TokenType.Short,
		Ushort = TokenType.Ushort,
		Int = TokenType.Int,
		Uint = TokenType.Uint,
		Long = TokenType.Long,
		Ulong = TokenType.Ulong,

		Float = TokenType.Float,
		Double = TokenType.Double,
		Real = TokenType.Real,
	}


public:
	Kind type;


public:
	this() { super(NodeType.PrimitiveType); }
	this(Kind kind) { super(NodeType.PrimitiveType); type = kind; }
}

/**
 * A TypeReference is generated for user defined types, and a pass fills
 * in the information so it can act as a cache, and not require multiple
 * lookups.
 *
 * @p TypeReference is just a cache, and as such it is @p type that is mangled.
 *
 * @ingroup irNode irType
 */
class TypeReference : Type
{
public:
	string[] names;  /// The name of the Type. Filled in the initial parsing.
	Type type;  /// What Type this refers to. Filled in after parsing sometime.
	bool isInternal;  /// This TypeReference refers to a type in Module.internalScope.


public:
	this() { super(NodeType.TypeReference); }
}

/**
 * A pointer is an abstraction of an address. 
 * You can dereference a pointer (get the thing it's pointing to),
 * perform pointer arithmetic (move to the next possible address that
 * could contain the same type), or reseat a pointer (change what it
 * points to). You can also slice a pointer to get an array.
 *
 * Volt pointers are compatible with C pointers (and by association, D
 * pointers).
 *
 * @p PointerTypes are mangled as "P" + @p base.
 *
 * @ingroup irNode irType
 */
class PointerType : Type
{
public:
	Type base;
	/**
	 * If this is true, then this pointer represents a
	 * reference -- that is to say, it is presented to
	 * the user as the base type, but is handled as a
	 * pointer internally to the compiler.
	 */
	bool isReference;


public:
	this() { super(NodeType.PointerType); }
	this(Type base) { super(NodeType.PointerType); this.base = base; }
}

/**
 * An ArrayType represents a slice of memory. It contains a pointer,
 * that contains elements of the base type, and a length, which says
 * how many elements this slice shows. This is lowered into a struct
 * before the backend gets it.
 *
 * While arrays are often allocated by the GC, the memory can be from
 * anywhere.
 *
 * @p ArrayType is mangled as "A" + the mangle of @p base.
 *
 * @ingroup irNode irType
 */
class ArrayType : Type
{
public:
	Type base;


public:
	this() { super(NodeType.ArrayType); }
	this(Type base) { super(NodeType.ArrayType); this.base = base; }
}

/**
 * A StaticArray is a list of elements of type base with a
 * statically (known at compile time) number of elements.
 * Unlike C, these are passed by value to functions.
 *
 * @p StaticArrayTypes are mangled as "G" + @p length + @p base.
 *
 * @ingroup irNode irType
 */
class StaticArrayType : Type
{
public:
	Type base;
	size_t length;


public:
	this() { super(NodeType.StaticArrayType); }
}

/**
 * An AAType is an associative array -- it associates
 * keys with values.
 *
 * @p AAType is mangled as "H" + @p key + @p value.
 *
 * @ingroup irNode irType
 */
class AAType : Type
{
public:
	Type value;
	Type key;


public:
	this() { super(NodeType.AAType); }
}

/**
 * The common ancestor of DelegateTypes and FunctionTypes.
 */
class CallableType : Type
{
public:
	Linkage linkage;

	Type ret;
	Variable[] params;
	/// @todo Get rid of this once we've moved Function.Kind here.
	bool hiddenParameter;


public:
	this(NodeType nt) { super(nt); }
}

/**
 * A FunctionType represents the form of a function, and defines
 * how it is called. It has a return type and a number of parameters.
 *
 * The Linkages define how the function is mangled and called by the backend.
 *
 * FunctionTypes are mangled like so: Linkage Attributes Parameters "Z" Ret
 *
 * @ingroup irNode irType
 */
class FunctionType : CallableType
{
public:
	this() { super(NodeType.FunctionType); }
}

/**
 * A DelegateType is a function pointer with an additional context
 * pointer.
 *
 * @p DelegateTypes are mangled as 'D' then as a FunctionType.
 *
 * @ingroup irNode irType
 */
class DelegateType : CallableType
{
public:
	this() { super(NodeType.DelegateType); }
}

/**
 * A StorageType changes how a Type is stored and/or
 * operated on.
 *
 * @todo This needs serious pruning.
 *
 * @ingroup irNode irType
 */
class StorageType : Type
{
public:
	enum Kind {
		Abstract = TokenType.Abstract,
		Auto = TokenType.Auto,
		Const = TokenType.Const,
		Deprecated = TokenType.Deprecated,
		Enum = TokenType.Enum,
		Extern = TokenType.Extern,
		Final = TokenType.Final,
		Immutable = TokenType.Immutable,
		Inout = TokenType.Inout,
		Shared = TokenType.Shared,
		Nothrow = TokenType.Nothrow,
		Override = TokenType.Override,
		Pure = TokenType.Pure,
		Global = TokenType.Global,
		Local = TokenType.Local,
		Scope = TokenType.Scope,
		Static = TokenType.Static,
		Synchronized = TokenType.Synchronized,
	}


public:
	Kind type;
	Type base;  // Optional.


public:
	this() { super(NodeType.StorageType); }
}
