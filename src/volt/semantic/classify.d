// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classify;

import std.range : array, retro;
import std.conv : to;
import std.string : format;
import std.math : isNaN;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.semantic.context;
import volt.semantic.lookup;
import volt.semantic.ctfe;
import volt.semantic.typer;

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
		lp.actualize(asStruct);
		return structSize(location, lp, asStruct);
	case Union:
		auto asUnion = cast(ir.Union) node;
		assert(asUnion !is null);
		lp.actualize(asUnion);
		return unionSize(location, lp, asUnion);
	case Class:
		return lp.settings.isVersionSet("V_P64") ? 8 : 4;
	case Enum:
		auto asEnum = cast(ir.Enum) node;
		assert(asEnum !is null);
		lp.resolve(asEnum);
		return size(location, lp, asEnum.base);

	case Variable:
		auto asVariable = cast(ir.Variable) node;
		assert(asVariable !is null);
		return size(location, lp, asVariable.type);
	case PointerType, FunctionType, DelegateType:
		return lp.settings.isVersionSet("V_P64") ? 8 : 4;
	case ArrayType:
		return lp.settings.isVersionSet("V_P64") ? 16 : 8;
	case AAType:
		return lp.settings.isVersionSet("V_P64") ? 8 : 4;
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

size_t alignment(LanguagePass lp, ir.PrimitiveType.Kind kind)
{
	final switch (kind) with (ir.PrimitiveType.Kind) {
	case Void: return lp.settings.alignment.int8;
	case Bool: return lp.settings.alignment.int1;
	case Char: return lp.settings.alignment.int8;
	case Byte: return lp.settings.alignment.int8;
	case Ubyte: return lp.settings.alignment.int8;
	case Short: return lp.settings.alignment.int16;
	case Ushort: return lp.settings.alignment.int16;
	case Wchar: return lp.settings.alignment.int16;
	case Int: return lp.settings.alignment.int32;
	case Uint: return lp.settings.alignment.int32;
	case Dchar: return lp.settings.alignment.int32;
	case Long: return lp.settings.alignment.int64;
	case Ulong: return lp.settings.alignment.int64;
	case Float: return lp.settings.alignment.float32;
	case Double: return lp.settings.alignment.float64;
	case Real: return lp.settings.alignment.float64;
	}
}

size_t alignment(Location location, LanguagePass lp, ir.Type node)
{
	switch (node.nodeType) with (ir.NodeType) {
	case ArrayType:
	case DelegateType:
	case Struct:
		return lp.settings.alignment.aggregate;
	case AAType:
	case PointerType:
	case FunctionType:
	case Class:
		return lp.settings.alignment.ptr;
	case Union:
		return lp.settings.alignment.int8; // Matches implementation
	case PrimitiveType:
		auto asPrim = cast(ir.PrimitiveType) node;
		assert(asPrim !is null);
		return alignment(lp, asPrim.type);
	case Enum:
		auto asEnum = cast(ir.Enum) node;
		assert(asEnum !is null);
		lp.resolve(asEnum);
		return alignment(location, lp, asEnum.base);
	case Variable:
		auto asVariable = cast(ir.Variable) node;
		assert(asVariable !is null);
		return alignment(location, lp, asVariable.type);
	case TypeReference:
		auto asTR = cast(ir.TypeReference) node;
		assert(asTR !is null);
		return alignment(location, lp, asTR.type);
	case StorageType:
		auto asST = cast(ir.StorageType) node;
		assert(asST !is null);
		return alignment(location, lp, asST.base);
	case StaticArrayType:
		auto _static = cast(ir.StaticArrayType) node;
		assert(_static !is null);
		return alignment(location, lp, _static.base) * cast(int)_static.length;
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
			if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
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
			if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
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
		if (asStorageType.type == ir.StorageType.Kind.Immutable || asStorageType.type == ir.StorageType.Kind.Const) {
			return false;
		}
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

/// TODO: non char strings, non immutable strings.
bool isString(ir.Type t)
{
	auto stor = cast(ir.StorageType) t;
	if (stor !is null) {
		return isString(stor.base);
	}
	auto arr = cast(ir.ArrayType) t;
	if (arr is null) {
		return false;
	}
	auto old = arr.base;
	do {
		stor = cast(ir.StorageType) old;
		if (stor !is null) {
			old = stor.base;
		}
	} while (stor !is null);
	auto prim = cast(ir.PrimitiveType) old;
	if (prim is null) {
		return false;
	}
	if (prim.type == ir.PrimitiveType.Kind.Char) {
		return true;
	}
	return false;
}

bool isArray(ir.Type t)
{
	return (cast(ir.ArrayType) t) !is null;
}

bool isAssign(ir.Exp exp)
{
	auto bop = cast(ir.BinOp) exp;
	if (bop is null) {
		return false;
	}
	switch (bop.op) with (ir.BinOp.Op) {
	case Assign, AddAssign, SubAssign, MulAssign, DivAssign, ModAssign,
		AndAssign, OrAssign, XorAssign, CatAssign, LSAssign, SRSAssign,
		RSAssign, PowAssign:
		return true;
	default:
		return false;
	}
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

bool isRef(ir.Type type, out ir.StorageType.Kind kind)
{
	if (type is null) {
		return false;
	}
	auto storage = cast(ir.StorageType) type;
	if (storage is null) {
		return false;
	}
	while (storage !is null) {
		if (storage.type == ir.StorageType.Kind.Ref || storage.type == ir.StorageType.Kind.Out) {
			kind = storage.type;
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
	ir.StorageType.Kind dummy;
	return isRef(asVar.type, dummy);
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
		// If it's not a Variable, or not a field, it shouldn't take up space.
		auto asVar = cast(ir.Variable)node;
		if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}

		int a = cast(int)alignment(location, lp, asVar.type);
		int size = .size(location, lp, asVar.type);
		if (sizeAccumulator % a) {
			sizeAccumulator += (a - (sizeAccumulator % a)) + size;
		} else {
			sizeAccumulator += size;
		}
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

bool effectivelyConst(ir.Type type)
{
	auto asStorageType = cast(ir.StorageType) type;
	if (asStorageType is null) {
		return false;
	}

	auto t = asStorageType.type;
	with (ir.StorageType.Kind) return t == Const || t == Immutable;
}

bool isPointer(ir.Type t)
{
	auto ptr = cast(ir.PointerType) t;
	return ptr !is null;
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

bool isInt(ir.Type type)
{
	auto primitive = cast(ir.PrimitiveType) type;
	if (primitive is null) {
		return false;
	}
	return primitive.type == ir.PrimitiveType.Kind.Int;
}

bool isVoid(ir.Type type)
{
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

bool isConstant(ir.Exp e)
{
	auto eref = cast(ir.ExpReference) e;
	if (eref !is null) {
		auto var = cast(ir.Variable) eref.decl;
		if (var !is null && var.assign !is null) {
			return isConstant(var.assign);
		}
	}
	return e.nodeType == ir.NodeType.Constant || e.nodeType == ir.NodeType.Typeid || e.nodeType == ir.NodeType.ClassLiteral;
}

bool isInFunction(Context ctx)
{
	return ctx.current.node.nodeType == ir.NodeType.Function || ctx.current.node.nodeType == ir.NodeType.BlockStatement;
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
	ir.Constant removeCast(ir.Exp exp)
	{
		auto constant = cast(ir.Constant) exp;
		if (constant !is null) {
			return constant;
		}
		auto unary = cast(ir.Unary) exp;
		while (unary !is null && unary.op == ir.Unary.Op.Cast) {
			return removeCast(unary.value);
		}
		return null;
	}

	auto constant = removeCast(e);
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
				return constant.u._int >= 0 && cast(ulong) constant.u._int <= max;
			} else if (primitive.type == Uint) {
				return constant.u._uint <= max;
			} else if (primitive.type == Long) {
				return constant.u._long >= 0 && cast(ulong) constant.u._long <= max;
			} else if (primitive.type == Ulong) {
				return constant.u._ulong <= max;
			} else if (primitive.type == Float || primitive.type == Double) {
				return false;
			} else if (primitive.type == Bool) {
				return true;
			} else {
				assert(false);
			}
		}

		bool inSignedRange(long min, long max)
		{
			if (primitive.type == Int) {
				return constant.u._int >= min && constant.u._int <= max;
			} else if (primitive.type == Uint) {
				return constant.u._uint <= cast(uint) max;
			} else if (primitive.type == Long) {
				return constant.u._long >= min && constant.u._long <= max;
			} else if (primitive.type == Ulong) {
				return constant.u._ulong <= cast(ulong) max;
			} else if (primitive.type == Float || primitive.type == Double) {
				return false;
			} else if (primitive.type == Char) {
				return true;
			} else if (primitive.type == Dchar) {
				return constant.u._uint < cast(uint) max;
			} else if (primitive.type == Bool) {
				return true;
			} else {
				assert(false);
			}
		}

		bool inFPRange(T)()
		{
			if (primitive.type == Int) {
				return constant.u._int >= T.min_normal && constant.u._int <= T.max;
			} else if (primitive.type == Uint) {
				return constant.u._uint >= T.min_normal && constant.u._uint <= T.max;
			} else if (primitive.type == Long) {
				return constant.u._long >= T.min_normal && constant.u._long <= T.max;
			} else if (primitive.type == Ulong) {
				return constant.u._ulong >= T.min_normal && constant.u._ulong <= T.max;
			} else if (primitive.type == Float) {
				return constant.u._float >= T.min_normal && constant.u._float <= T.max;
			} else if (primitive.type == Double) {
				return constant.u._double >= T.min_normal && constant.u._double <= T.max;
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
	} else if (a.nodeType == ir.NodeType.AAType &&
	           b.nodeType == ir.NodeType.AAType) {
		auto ap = cast(ir.AAType) a;
		auto bp = cast(ir.AAType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.key, bp.key) && typesEqual(ap.value, bp.value);
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

int typeToRuntimeConstant(LanguagePass lp, ir.Scope current, ir.Type type)
{
	int evaluate(ir.EnumDeclaration ed)
	{
		assert(ed.assign !is null);
		auto constant = .evaluate(lp, current, ed.assign);
		return constant.u._int;
	}

	type = realType(type);
	switch (type.nodeType) with (ir.NodeType) {
	case Struct: return evaluate(lp.TYPE_STRUCT);
	case Class: return evaluate(lp.TYPE_CLASS);
	case Interface: return evaluate(lp.TYPE_INTERFACE);
	case Union: return evaluate(lp.TYPE_UNION);
	case Enum: return evaluate(lp.TYPE_ENUM);
	case Attribute: return evaluate(lp.TYPE_ATTRIBUTE);
	case UserAttribute: return evaluate(lp.TYPE_USER_ATTRIBUTE);
	case PrimitiveType:
		auto prim = cast(ir.PrimitiveType) type;
		final switch (prim.type) with (ir.PrimitiveType.Kind) {
		case Void: return evaluate(lp.TYPE_VOID);
		case Ubyte: return evaluate(lp.TYPE_UBYTE);
		case Byte: return evaluate(lp.TYPE_BYTE);
		case Char: return evaluate(lp.TYPE_CHAR);
		case Bool: return evaluate(lp.TYPE_BOOL);
		case Ushort: return evaluate(lp.TYPE_USHORT);
		case Short: return evaluate(lp.TYPE_SHORT);
		case Wchar: return evaluate(lp.TYPE_WCHAR);
		case Uint: return evaluate(lp.TYPE_UINT);
		case Int: return evaluate(lp.TYPE_INT);
		case Dchar: return evaluate(lp.TYPE_DCHAR);
		case Float: return evaluate(lp.TYPE_FLOAT);
		case Ulong: return evaluate(lp.TYPE_ULONG);
		case Long: return evaluate(lp.TYPE_LONG);
		case Double: return evaluate(lp.TYPE_DOUBLE);
		case Real: return evaluate(lp.TYPE_REAL);
		}
	case PointerType: return evaluate(lp.TYPE_POINTER);
	case ArrayType: return evaluate(lp.TYPE_ARRAY);
	case StaticArrayType: return evaluate(lp.TYPE_STATIC_ARRAY);
	case AAType: return evaluate(lp.TYPE_AA);
	case FunctionType: return evaluate(lp.TYPE_FUNCTION);
	case DelegateType: return evaluate(lp.TYPE_DELEGATE);
	case StorageType:
		auto storage = cast(ir.StorageType) type;
		return typeToRuntimeConstant(lp, current, storage.base);
	default:
		throw panicUnhandled(type, "typeToRuntimeConstant");
	}
}

bool isPointerToClass(ir.Type t)
{
	auto ptr = cast(ir.PointerType) realType(t);
	if (ptr is null) {
		return false;
	}
	auto _class = cast(ir.Class) realType(ptr.base);
	return _class !is null;
}

ir.Aggregate opOverloadableOrNull(ir.Type t)
{
	auto _agg = cast(ir.Aggregate) realType(t);
	if (_agg is null || _agg.nodeType == ir.NodeType.UserAttribute) {
		return null;
	}
	return _agg;
}

string overloadName(ir.BinOp.Op op)
{
	switch (op) with (ir.BinOp.Op) {
	case NotEqual: return "opNotEqual";
	case Equal:    return "opEqual";
	case Sub:      return "opSub";
	case Add:      return "opAdd";
	case Mul:      return "opMul";
	case Div:      return "opDiv";
	default:       return "";
	}
}

string overloadIndexName()
{
	return "opIndex";
}

bool isNested(ir.Variable.Storage s)
{
	with (ir.Variable.Storage) {
		return s == Nested;
	}
}

