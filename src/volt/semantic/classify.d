// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classify;

import std.range : array, retro;
import std.conv : to;
import std.stdio : format;
import std.math : isNaN;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.semantic.lookup;

/**
 * If the given scope is in a function, return it. Otherwise, return null.
 */
ir.Function getParentFunction(ir.Scope current)
{
	auto fn = cast(ir.Function) current.node;
	if (fn !is null) {
		return fn;
	}

	auto bs = cast(ir.BlockStatement) current.node;
	if (bs !is null) {
		return getParentFunction(current.parent);
	}

	return null;
}

int size(ir.PrimitiveType.Kind kind)
{
	final switch (kind) with (ir.PrimitiveType.Kind) {
	case Void: return 1;
	case Bool: return 1;
	case Char: return 1;
	case Byte: return 1;
	case Ubyte: return 1;
	case Short: return 2;
	case Ushort: return 2;
	case Wchar: return 2;
	case Int: return 4;
	case Uint: return 4;
	case Dchar: return 4;
	case Long: return 8;
	case Ulong: return 8;
	case Float: return 4;
	case Double: return 8;
	case Real: return 8;
	}
}

int size(Location location, LanguagePass lp, ir.Node node)
{
	switch (node.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto asPrim = cast(ir.PrimitiveType) node;
		assert(asPrim !is null);
		return size(asPrim.type);
	case Struct:
		auto asStruct = cast(ir.Struct) node;
		assert(asStruct !is null);
		return structSize(location, lp, asStruct);
	case Union:
		auto asUnion = cast(ir.Union) node;
		assert(asUnion !is null);
		return unionSize(location, lp, asUnion);
	case Class:
		return lp.settings.isVersionSet("V_P64") ? 8 : 4;
	case Enum:
		auto asEnum = cast(ir.Enum) node;
		assert(asEnum !is null);
		return size(location, lp, asEnum.base);

	case Variable:
		auto asVariable = cast(ir.Variable) node;
		assert(asVariable !is null);
		return size(location, lp, asVariable.type);
	case PointerType, FunctionType, DelegateType:
		return lp.settings.isVersionSet("V_P64") ? 8 : 4;
	case ArrayType:
		return lp.settings.isVersionSet("V_P64") ? 16 : 8;
	case TypeReference:
		auto asTR = cast(ir.TypeReference) node;
		assert(asTR !is null);
		return size(location, lp, asTR.type);
	case StorageType:
		auto asST = cast(ir.StorageType) node;
		assert(asST !is null);
		return size(location, lp, asST.base);
	case StaticArrayType:
		auto _static = cast(ir.StaticArrayType) node;
		assert(_static !is null);
		return size(location, lp, _static.base) * cast(int)_static.length;
	default:
		throw panicUnhandled(node, to!string(node.nodeType));
	}
}

/**
 * A type without mutable indirection is a pure value type --
 * it cannot mutate any other memory than its own, or is composed
 * of the above. This is useful for making const and friends more
 * user friendly.
 *
 * Given a Variable with a const type that does not have mutableIndirection
 * it is safe to copy that value and pass it to a non-const function, like so:
 *
 * void bar(int f);
 * void foo(const(int) i) { bar(i); }
 */
bool mutableIndirection(ir.Type t)
{
	switch (t.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		return false;
	case TypeReference:
		auto asTR = cast(ir.TypeReference) t;
		assert(asTR !is null);
		return mutableIndirection(asTR.type);
	case Struct:
		auto asStruct = cast(ir.Struct) t;
		assert(asStruct !is null);
		foreach (node; asStruct.members.nodes) {
			auto asVar = cast(ir.Variable) node;
			if (asVar is null) {
				continue;
			}
			if (mutableIndirection(asVar.type)) {
				return true;
			}
		}
		return false;
	case Union:
		auto asUnion = cast(ir.Union) t;
		assert(asUnion !is null);
		foreach (node; asUnion.members.nodes) {
			auto asVar = cast(ir.Variable) node;
			if (asVar is null) {
				continue;
			}
			if (mutableIndirection(asVar.type)) {
				return true;
			}
		}
		return false;
	case StorageType:
		auto asStorageType = cast(ir.StorageType) t;
		assert(asStorageType !is null);
		return mutableIndirection(asStorageType.base);
	default:
		return true;
	}
}

bool canTransparentlyReferToBase(ir.StorageType storage)
{
	return storage.type == ir.StorageType.Kind.Auto || storage.type == ir.StorageType.Kind.Ref;
}

bool isAuto(ir.Type t)
{
	auto s = cast(ir.StorageType) t;
	if (s is null) {
		return false;
	}
	return s.type == ir.StorageType.Kind.Auto;
}

bool isBool(ir.Type t)
{
	auto p = cast(ir.PrimitiveType) t;
	if (p is null) {
		return false;
	}
	return p.type == ir.PrimitiveType.Kind.Bool;
}

bool isLValue(ir.Exp exp)
{
	switch (exp.nodeType) {
	case ir.NodeType.IdentifierExp:
	case ir.NodeType.ExpReference: return true;
	case ir.NodeType.Postfix:
		auto asPostfix = cast(ir.Postfix) exp;
		assert(asPostfix !is null);
		if (asPostfix.op == ir.Postfix.Op.Index) {
			return isLValue(asPostfix.child);
		}
		return asPostfix.op == ir.Postfix.Op.Identifier;
	default:
		return false;
	}
}

bool isImmutable(ir.Type type)
{
	if (type is null) {
		return false;
	}
	auto storage = cast(ir.StorageType) type;
	if (storage is null) {
		return false;
	}
	while (storage !is null) {
		if (storage.type == ir.StorageType.Kind.Immutable) {
			return true;
		}
		storage = cast(ir.StorageType) storage.base;
	}
	return false;
}

bool isRef(ir.Type type)
{
	if (type is null) {
		return false;
	}
	auto storage = cast(ir.StorageType) type;
	if (storage is null) {
		return false;
	}
	while (storage !is null) {
		if (storage.type == ir.StorageType.Kind.Ref) {
			return true;
		}
		storage = cast(ir.StorageType) storage.base;
	}
	return false;
}

bool isConst(ir.Type type)
{
	if (type is null) {
		return false;
	}
	auto storage = cast(ir.StorageType) type;
	if (storage is null) {
		return false;
	}
	while (storage !is null) {
		if (storage.type == ir.StorageType.Kind.Const) {
			return true;
		}
		storage = cast(ir.StorageType) storage.base;
	}
	return false;
}

bool isRefVar(ir.Exp exp)
{
	auto asExpRef = cast(ir.ExpReference) exp;
	if (asExpRef is null) {
		return false;
	}
	auto asVar = cast(ir.FunctionParam) asExpRef.decl;
	if (asVar is null) {
		return false;
	}
	return isRef(asVar.type);
}

bool isFunctionMemberOrConstructor(ir.Function fn)
{
	final switch (fn.kind) with (ir.Function.Kind) {
	case Invalid:
		assert(false);
	case Member:
	case Constructor:
	case Destructor:
	case LocalConstructor:
	case LocalDestructor:
	case GlobalConstructor:
	case GlobalDestructor:
		return true;
	case Function:
	case LocalMember:
	case GlobalMember:
		return false;
	}
}

bool isFunctionStatic(ir.Function fn)
{
	final switch (fn.kind) with (ir.Function.Kind) {
	case Invalid:
	case Constructor:
	case Destructor:
	case LocalConstructor:
	case LocalDestructor:
	case GlobalConstructor:
	case GlobalDestructor:
		assert(false);
	case Member:
		return false;
	case Function:
	case LocalMember:
	case GlobalMember:
		return true;
	}
}

bool isVariableStatic(ir.Variable var)
{
	final switch (var.storage) with (ir.Variable.Storage) {
	case Invalid:
		assert(false);
	case Field:
		return false;
	case Function:
	case Nested:
	case Local:
	case Global:
		return true;
	}
}

bool acceptableForUserAttribute(LanguagePass lp, ir.Scope current, ir.Type type)
{
	ensureResolved(lp, current, type);
	auto asPrim = cast(ir.PrimitiveType) type;
	if (asPrim !is null) {
		return true;
	}

	auto asStorage = cast(ir.StorageType) type;
	if (asStorage !is null) {
		return acceptableForUserAttribute(lp, current, asStorage.base);
	}

	auto asArray = cast(ir.ArrayType) type;
	if (asArray !is null) {
		return acceptableForUserAttribute(lp, current, asArray.base);
	}

	auto asTR = cast(ir.TypeReference) type;
	if (asTR !is null) {
		assert(asTR.type !is null);
		return acceptableForUserAttribute(lp, current, asTR.type);
	}

	return false;
}

/// Returns the size of a given Struct, in bytes.
int structSize(Location location, LanguagePass lp, ir.Struct s)
{
	int sizeAccumulator;
	foreach (node; s.members.nodes) {
		// If it's not a Variable, it shouldn't take up space.
		if (node.nodeType != ir.NodeType.Variable) {
			continue;
		}

		sizeAccumulator += size(location, lp, node);
	}
	return sizeAccumulator;
}

/// Returns the size of a given Union, in bytes.
int unionSize(Location location, LanguagePass lp, ir.Union u)
{
	int sizeAccumulator;
	foreach (node; u.members.nodes) {
		// If it's not a Variable, it shouldn't take up space.
		if (node.nodeType != ir.NodeType.Variable) {
			continue;
		}

		auto s = size(location, lp, node);
		if (s > sizeAccumulator)
			sizeAccumulator = s;
	}
	return sizeAccumulator;
}

/// Returns the size of a given Class (not the reference), in bytes.
int classSize(Location location, LanguagePass lp, ir.Class c)
{
	int sizeAccumulator;
	while (c !is null) {
		foreach (node; c.members.nodes) {
			// If it's not a Variable, it shouldn't take up space.
			if (node.nodeType != ir.NodeType.Variable) {
				continue;
			}

			sizeAccumulator += size(location, lp, node);
		}
		c = c.parentClass;
	}

	auto wordSize = size(lp.settings.getSizeT(location).type);
	return sizeAccumulator + wordSize;
}

bool effectivelyConst(ir.Type type)
{
	auto asStorageType = cast(ir.StorageType) type;
	if (asStorageType is null) {
		return false;
	}

	auto t = asStorageType.type;
	with (ir.StorageType.Kind) return t == Const || t == Immutable;
}

bool isIntegral(ir.Type t)
{
	auto prim = cast(ir.PrimitiveType)t;
	if (prim is null) {
		return false;
	}
	return isIntegral(prim.type);
}

bool isIntegral(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
		case Byte:
		case Ubyte:
		case Short:
		case Ushort:
		case Int:
		case Uint:
		case Long:
		case Ulong:
		case Char:
		case Wchar:
		case Dchar:
			return true;
		default:
			return false;
	}
}

bool isFloatingPoint(ir.Type t)
{
	auto prim = cast(ir.PrimitiveType)t;
	if (prim is null) {
		return false;
	}
	return isFloatingPoint(prim.type);
}

bool isFloatingPoint(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
		case Float:
		case Double:
		case Real:
			return true;
		default:
			return false;
	}
}

bool isUnsigned(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Void:
	case Byte:
	case Short:
	case Int:
	case Long:
	case Float:
	case Double:
	case Real:
		return false;
	default:
		return true;
	}
}

bool isOkayForPointerArithmetic(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Byte:
	case Ubyte:
	case Short:
	case Ushort:
	case Int:
	case Uint:
	case Long:
	case Ulong:
		return true;
	default:
		return false;
	}
}

bool isVoid(ir.Type type)
{
	if (type is null) {
		return false;
	}
	auto primitive = cast(ir.PrimitiveType) type;
	if (primitive is null) {
		return false;
	}
	return primitive.type == ir.PrimitiveType.Kind.Void;
}

bool isComparison(ir.BinOp.Op t)
{
	switch (t) with (ir.BinOp.Op) {
	case OrOr, AndAnd, Equal, NotEqual, Is, NotIs, Less, LessEqual, Greater, GreaterEqual:
		return true;
	default:
		return false;
	}
}

bool isValidPointerArithmeticOperation(ir.BinOp.Op t)
{
	switch (t) with (ir.BinOp.Op) {
	case Add, Sub:
		return true;
	default:
		return false;
	}
}

bool isImplicitlyConvertable(ir.Type from, ir.Type to)
{
	auto fprim = cast(ir.PrimitiveType)from;
	auto tprim = cast(ir.PrimitiveType)to;

	auto tstorage = cast(ir.StorageType) to;
	if (tstorage !is null) {
		return typesEqual(from, tstorage.base) || isImplicitlyConvertable(from, tstorage.base);
	}

	auto fstorage = cast(ir.StorageType) from;
	if (fstorage !is null) {
		return typesEqual(to, fstorage.base) || isImplicitlyConvertable(fstorage.base, to);
	}

	if (fprim is null || tprim is null)
		return false;

	auto fromsz = size(fprim.type);
	auto tosz = size(tprim.type);
	
	if (isIntegral(from) && isIntegral(to)) {
		if (isUnsigned(fprim.type) != isUnsigned(tprim.type))
			return false;

		return fromsz <= tosz; // int is implicitly convertable to int
	}
	
	if (isFloatingPoint(from) && isFloatingPoint(to))
		return fromsz <= tosz;

	if (isFloatingPoint(from) && isIntegral(to))
		return false;

	if (isIntegral(from) && isFloatingPoint(to))
		return true;

	// also arrays go here
	return false;
}

bool fitsInPrimitive(ir.PrimitiveType t, ir.Exp e)
{
	auto constant = cast(ir.Constant) e;
	if (constant is null) {
		return false;
	}

	auto primitive = cast(ir.PrimitiveType) constant.type;
	if (primitive is null) {
		return false;
	}

	with (ir.PrimitiveType.Kind) {
		bool inUnsignedRange(ulong max)
		{
			if (primitive.type == Int) {
				return constant._int >= 0 && cast(ulong) constant._int <= max;
			} else if (primitive.type == Uint) {
				return constant._uint <= max;
			} else if (primitive.type == Long) {
				return constant._long >= 0 && cast(ulong) constant._long <= max;
			} else if (primitive.type == Ulong) {
				return constant._ulong <= max;
			} else if (primitive.type == Float || primitive.type == Double) {
				return false;
			} else {
				assert(false);
			}
		}

		bool inSignedRange(long min, long max)
		{
			if (primitive.type == Int) {
				return constant._int >= min && constant._int <= max;
			} else if (primitive.type == Uint) {
				return constant._uint <= cast(uint) max;
			} else if (primitive.type == Long) {
				return constant._long >= min && constant._long <= max;
			} else if (primitive.type == Ulong) {
				return constant._ulong <= cast(ulong) max;
			} else if (primitive.type == Float || primitive.type == Double) {
				return false;
			} else {
				assert(false);
			}
		}

		bool inFPRange(T)()
		{
			if (primitive.type == Int) {
				return constant._int >= T.min_normal && constant._int <= T.max;
			} else if (primitive.type == Uint) {
				return constant._uint >= T.min_normal && constant._uint <= T.max;
			} else if (primitive.type == Long) {
				return constant._long >= T.min_normal && constant._long <= T.max;
			} else if (primitive.type == Ulong) {
				return constant._ulong >= T.min_normal && constant._ulong <= T.max;
			} else if (primitive.type == Float) {
				return constant._float >= T.min_normal && constant._float <= T.max;
			} else if (primitive.type == Double) {
				return constant._double >= T.min_normal && constant._double <= T.max;
			} else {
				assert(false);
			}
		}

		alias inFPRange!float inFloatRange;
		alias inFPRange!double inDoubleRange;

		switch (t.type) {
		case Ubyte, Char: return inUnsignedRange(ubyte.max);
		case Byte: return inSignedRange(byte.min, byte.max);
		case Ushort, Wchar: return inUnsignedRange(ushort.max);
		case Short: return inSignedRange(ushort.min, ushort.max);
		case Uint, Dchar: return inUnsignedRange(uint.max);
		case Int: return inSignedRange(int.min, int.max);
		case Ulong: return inUnsignedRange(ulong.max);
		case Long: return inSignedRange(ulong.min, ulong.max);
		case Float: return inFloatRange();
		case Double: return inDoubleRange();
		case Void: return false;
		default:
			return false;
		}
	}

	assert(false);
}

/**
 * Determines whether the two given types are the same.
 *
 * Not similar. Not implicitly convertable. The _same_ type.
 * Returns: true if they're the same, false otherwise.
 */
bool typesEqual(ir.Type a, ir.Type b)
{
	if (a is b) {
		return true;
	}
	
	if (a.nodeType == ir.NodeType.PrimitiveType &&
	    b.nodeType == ir.NodeType.PrimitiveType) {
		auto ap = cast(ir.PrimitiveType) a;
		auto bp = cast(ir.PrimitiveType) b;
		assert(ap !is null && bp !is null);
		return ap.type == bp.type;
	} else if (a.nodeType == ir.NodeType.StaticArrayType &&
			   b.nodeType == ir.NodeType.StaticArrayType) {
		auto ap = cast(ir.StaticArrayType) a;
		auto bp = cast(ir.StaticArrayType) b;
		assert(ap !is null && bp !is null);
		return ap.length && bp.length && typesEqual(ap.base, bp.base);
	} else if (a.nodeType == ir.NodeType.PointerType &&
	           b.nodeType == ir.NodeType.PointerType) {
		auto ap = cast(ir.PointerType) a;
		auto bp = cast(ir.PointerType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.base, bp.base);
	} else if (a.nodeType == ir.NodeType.ArrayType &&
	           b.nodeType == ir.NodeType.ArrayType) {
		auto ap = cast(ir.ArrayType) a;
		auto bp = cast(ir.ArrayType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.base, bp.base);
	} else if (a.nodeType == ir.NodeType.TypeReference &&
	           b.nodeType == ir.NodeType.TypeReference) {
		auto ap = cast(ir.TypeReference) a;
		auto bp = cast(ir.TypeReference) b;
		assert(ap !is null && bp !is null);
		assert(ap.type !is null && bp.type !is null);
		return typesEqual(ap.type, bp.type);
	} else if (a.nodeType == ir.NodeType.TypeReference) {
		// Need to discard any TypeReference on either side.
		auto ap = cast(ir.TypeReference) a;
		assert(ap !is null);
		assert(ap.type !is null);
		return typesEqual(ap.type, b);
	} else if (b.nodeType == ir.NodeType.TypeReference) {
		// Need to discard any TypeReference on either side.
		auto bp = cast(ir.TypeReference) b;
		assert(bp !is null);
		assert(bp.type !is null);
		return typesEqual(a, bp.type);
	} else if ((a.nodeType == ir.NodeType.FunctionType &&
	            b.nodeType == ir.NodeType.FunctionType) ||
		   (a.nodeType == ir.NodeType.DelegateType &&
	            b.nodeType == ir.NodeType.DelegateType)) {
		auto ap = cast(ir.CallableType) a;
		auto bp = cast(ir.CallableType) b;
		assert(ap !is null && bp !is null);

		size_t apLength = ap.params.length, bpLength = bp.params.length;
		if (apLength != bpLength)
			return false;
		if (ap.hiddenParameter != bp.hiddenParameter)
			return false;
		auto ret = typesEqual(ap.ret, bp.ret);
		if (!ret)
			return false;
		for (int i; i < apLength; i++)
			if (!typesEqual(ap.params[i], bp.params[i]))
				return false;
		return true;
	} else if (a.nodeType == ir.NodeType.StorageType &&
			   b.nodeType == ir.NodeType.StorageType) {
		auto ap = cast(ir.StorageType) a;
		auto bp = cast(ir.StorageType) b;
		return ap.type == bp.type && typesEqual(ap.base, bp.base);
	}

	return false;
}

/// Retrieves the types of Variables in _struct, in the order they appear.
ir.Type[] getStructFieldTypes(ir.Struct _struct)
{
	ir.Type[] types;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asVar = cast(ir.Variable) node;
		if (asVar is null) {
			continue;
		}
		types ~= asVar.type;
		assert(types[$-1] !is null);
	}

	return types;
}

ir.Function[] getStructFunctions(ir.Struct _struct)
{
	ir.Function[] functions;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asFunction = cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}
		functions ~= asFunction;
	}

	return functions;
}

ir.Function[] getClassFunctions(ir.Class _class)
{
	ir.Function[] functions;

	if (_class.members !is null) foreach (node; _class.members.nodes) {
		auto asFunction = cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}
		functions ~= asFunction;
	}

	return functions;
}

/// Returns: true if child is a child of parent.
bool inheritsFrom(ir.Class child, ir.Class parent)
{
	if (child is parent)
		return false;

	auto currentClass = child;
	while (currentClass !is null) {
		if (currentClass is parent) {
			return true;
		}
		currentClass = currentClass.parentClass;
	}
	return false;
}

bool isOrInheritsFrom(ir.Class a, ir.Class b)
{
	if (a is b) {
		return true;
	} else {
		return inheritsFrom(a, b);
	}
}
