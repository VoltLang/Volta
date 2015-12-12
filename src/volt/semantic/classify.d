// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classify;

import watt.text.format : format;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;

import volt.semantic.context;


/*
 *
 * Size and alignment functions.
 *
 */

/**
 * Returns the size of a given ir.PrimitiveType in bytes.
 */
size_t size(ir.PrimitiveType.Kind kind)
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
	case Invalid: throw panic(Location.init, "invalid primitive kind");
	}
}

/**
 * Returns the size of a given ir.Type in bytes.
 */
size_t size(LanguagePass lp, ir.Node node)
{
	switch (node.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto asPrim = cast(ir.PrimitiveType) node;
		assert(asPrim !is null);
		return size(asPrim.type);
	case Struct:
		auto asStruct = cast(ir.Struct) node;
		assert(asStruct !is null);
		return structSize(lp, asStruct);
	case Union:
		auto asUnion = cast(ir.Union) node;
		assert(asUnion !is null);
		return unionSize(lp, asUnion);
	case Enum:
		auto asEnum = cast(ir.Enum) node;
		assert(asEnum !is null);
		lp.resolveNamed(asEnum);
		return size(lp, asEnum.base);
	case Variable:
		auto asVariable = cast(ir.Variable) node;
		assert(asVariable !is null);
		return size(lp, asVariable.type);
	case Class:
	case AAType:
	case Interface:
	case PointerType:
	case FunctionType:
		return lp.ver.isP64 ? 8U : 4U;
	case ArrayType:
	case DelegateType:
		return lp.ver.isP64 ? 16U : 8U;
	case TypeReference:
		auto asTR = cast(ir.TypeReference) node;
		assert(asTR !is null);
		assert(asTR.type !is null);
		return size(lp, asTR.type);
	case StorageType:
		auto asST = cast(ir.StorageType) node;
		assert(asST !is null);
		return size(lp, asST.base);
	case StaticArrayType:
		auto _static = cast(ir.StaticArrayType) node;
		assert(_static !is null);
		return size(lp, _static.base) * _static.length;
	default:
		throw panicUnhandled(node, ir.nodeToString(node));
	}
}

/**
 * Returns the size of a given ir.Struct in bytes.
 */
size_t structSize(LanguagePass lp, ir.Struct s)
{
	lp.actualize(s);

	size_t sizeAccumulator;
	foreach (node; s.members.nodes) {
		// If it's not a Variable, or not a field, it shouldn't take up space.
		auto asVar = cast(ir.Variable)node;
		if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}

		auto a = alignment(lp, asVar.type);
		auto size = .size(lp, asVar.type);
		sizeAccumulator = calcAlignment(a, sizeAccumulator) + size;
	}
	return sizeAccumulator;
}

/**
 * Returns the size of a given ir.Union in bytes.
 */
size_t unionSize(LanguagePass lp, ir.Union u)
{
	lp.actualize(u);

	size_t sizeAccumulator;
	foreach (node; u.members.nodes) {
		// If it's not a Variable, it shouldn't take up space.
		if (node.nodeType != ir.NodeType.Variable) {
			continue;
		}

		auto s = size(lp, node);
		if (s > sizeAccumulator) {
			sizeAccumulator = s;
		}
	}
	return sizeAccumulator;
}

/**
 * Returns the offset adjusted to alignment.
 */
size_t calcAlignment(size_t a, size_t offset)
{
	if (offset % a) {
		return offset + (a - (offset % a));
	} else {
		return offset;
	}
}

/**
 * Returns the offset adjusted to alignment of type.
 */
size_t calcAlignment(LanguagePass lp, ir.Type t, size_t offset)
{
	auto a = alignment(lp, t);
	return calcAlignment(a, offset);
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
	case Invalid: throw panic(Location.init, "invalid primitive kind");
	}
}

size_t alignment(LanguagePass lp, ir.Type node)
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
	case Interface:
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
		lp.resolveNamed(asEnum);
		return alignment(lp, asEnum.base);
	case Variable:
		auto asVariable = cast(ir.Variable) node;
		assert(asVariable !is null);
		return alignment(lp, asVariable.type);
	case TypeReference:
		auto asTR = cast(ir.TypeReference) node;
		assert(asTR !is null);
		return alignment(lp, asTR.type);
	case StorageType:
		auto asST = cast(ir.StorageType) node;
		assert(asST !is null);
		return alignment(lp, asST.base);
	case StaticArrayType:
		auto _static = cast(ir.StaticArrayType) node;
		assert(_static !is null);
		return alignment(lp, _static.base) * _static.length;
	default:
		throw panicUnhandled(node, ir.nodeToString(node));
	}
}


/*
 *
 * Type classifier functions.
 *
 */

/**
 * Remove types masking a type (e.g. enum).
 */
ir.Type realType(ir.Type t, bool stripEnum = true, bool stripStorage = false)
{
	auto tr = cast(ir.TypeReference) t;
	if (tr !is null) {
		return realType(tr.type, stripEnum, stripStorage);
	}
	if (stripEnum) {
		auto e = cast(ir.Enum) t;
		if (e !is null) {
			return realType(e.base, stripEnum, stripStorage);
		}
	}
	if (stripStorage) {
		auto st = cast(ir.StorageType) t;
		if (st !is null) {
			return realType(st.base, stripEnum, stripStorage);
		}
	}
	return t;
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
	assert(t !is null);
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
	case AutoType:
		auto asAutoType = cast(ir.AutoType) t;
		assert(asAutoType !is null);
		assert(asAutoType.explicitType !is null);
		if (asAutoType.isConst || asAutoType.isImmutable) {
			return false;
		}
		if (asAutoType.explicitType is null) {
			return false;
		}
		return mutableIndirection(asAutoType.explicitType);
	default:
		return true;
	}
}

bool isAuto(ir.Type t)
{
	auto a = cast(ir.AutoType) t;
	return a !is null && a.explicitType is null;
}

bool isBool(ir.Type t)
{
	auto p = cast(ir.PrimitiveType) t;
	if (p is null) {
		return false;
	}
	return p.type == ir.PrimitiveType.Kind.Bool;
}

/// Is this an array of characters?
bool isString(ir.Type t)
{
	auto arr = cast(ir.ArrayType) realType(t);
	if (arr is null) {
		return false;
	}
	return isChar(arr.base);
}

/// Is this type a character type?
bool isChar(ir.Type t)
{
	auto prim = cast(ir.PrimitiveType) realType(t);
	if (prim is null) {
		return false;
	}
	return prim.type == ir.PrimitiveType.Kind.Char ||
	       prim.type == ir.PrimitiveType.Kind.Wchar ||
	       prim.type == ir.PrimitiveType.Kind.Dchar;
}

bool isArray(ir.Type t)
{
	return (cast(ir.ArrayType) t) !is null;
}

bool canTransparentlyReferToBase(ir.StorageType storage)
{
	return storage.type == ir.StorageType.Kind.Auto || storage.type == ir.StorageType.Kind.Ref;
}

bool acceptableForUserAttribute(LanguagePass lp, ir.Scope current, ir.Type type)
{
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

bool effectivelyConst(ir.Type type)
{
	return type.isConst || type.isImmutable;
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

bool isIntegralOrBool(ir.Type t)
{
	auto prim = cast(ir.PrimitiveType)t;
	if (prim is null) {
		return false;
	}
	return isIntegralOrBool(prim.type);
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

bool isIntegralOrBool(ir.PrimitiveType.Kind kind)
{
	if (kind == ir.PrimitiveType.Kind.Bool) {
		return true;
	} else {
		return isIntegral(kind);
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

/**
 * Return a view of the given type without ref or out.
 * Doesn't copy internally, so don't place the result into the IR.
 */
ir.Type removeRefAndOut(ir.Type type)
{
	assert(type !is null);
	auto stype = cast(ir.StorageType)type;
	if (stype is null) {
		return type;
	}
	if (stype.type == ir.StorageType.Kind.Ref || stype.type == ir.StorageType.Kind.Out) {
		return removeRefAndOut(stype.base);
	}
	auto outType = new ir.StorageType();
	outType.type = stype.type;
	outType.location = type.location;
	outType.base = removeRefAndOut(stype.base);
	return outType;
}

/**
 * Return a view of the given type without const or immutable.
 * Doesn't copy internally, so don't place the result into the IR.
 */
ir.Type removeConstAndImmutable(ir.Type type)
{
	auto stype = cast(ir.StorageType)type;
	if (stype is null) {
		return type;
	}
	if (stype.type == ir.StorageType.Kind.Const || stype.type == ir.StorageType.Kind.Immutable) {
		return removeConstAndImmutable(stype.base);
	}
	auto outType = new ir.StorageType();
	outType.type = stype.type;
	outType.location = type.location;
	outType.base = removeConstAndImmutable(outType.base);
	return outType;
}

/**
 * Making the code more readable.
 */
enum IgnoreStorage = true;

/**
 * Determines whether the two given types are the same.
 *
 * Not similar. Not implicitly convertable. The _same_ type.
 * Returns: true if they're the same, false otherwise.
 */
bool typesEqual(ir.Type a, ir.Type b, bool ignoreStorage = false)
{
	if (!ignoreStorage) {
		if (a.isConst != b.isConst ||
		    a.isImmutable != b.isImmutable ||
		    a.isScope != b.isScope) {
			return false;
		}
	}
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
		return ap.length && bp.length && typesEqual(ap.base, bp.base, ignoreStorage);
	} else if (a.nodeType == ir.NodeType.PointerType &&
	           b.nodeType == ir.NodeType.PointerType) {
		auto ap = cast(ir.PointerType) a;
		auto bp = cast(ir.PointerType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.base, bp.base, ignoreStorage);
	} else if (a.nodeType == ir.NodeType.ArrayType &&
	           b.nodeType == ir.NodeType.ArrayType) {
		auto ap = cast(ir.ArrayType) a;
		auto bp = cast(ir.ArrayType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.base, bp.base, ignoreStorage);
	} else if (a.nodeType == ir.NodeType.AAType &&
	           b.nodeType == ir.NodeType.AAType) {
		auto ap = cast(ir.AAType) a;
		auto bp = cast(ir.AAType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.key, bp.key, ignoreStorage) && typesEqual(ap.value, bp.value, ignoreStorage);
	} else if (a.nodeType == ir.NodeType.TypeReference &&
	           b.nodeType == ir.NodeType.TypeReference) {
		auto ap = cast(ir.TypeReference) a;
		auto bp = cast(ir.TypeReference) b;
		assert(ap !is null && bp !is null);
		assert(ap.type !is null && bp.type !is null);
		return typesEqual(ap.type, bp.type, ignoreStorage);
	} else if (a.nodeType == ir.NodeType.TypeReference) {
		// Need to discard any TypeReference on either side.
		auto ap = cast(ir.TypeReference) a;
		assert(ap !is null);
		assert(ap.type !is null);
		return typesEqual(ap.type, b, ignoreStorage);
	} else if (b.nodeType == ir.NodeType.TypeReference) {
		// Need to discard any TypeReference on either side.
		auto bp = cast(ir.TypeReference) b;
		assert(bp !is null);
		assert(bp.type !is null);
		return typesEqual(a, bp.type, ignoreStorage);
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
		auto ret = typesEqual(ap.ret, bp.ret, ignoreStorage);
		if (!ret)
			return false;
		for (size_t i; i < apLength; i++)
			if (!typesEqual(ap.params[i], bp.params[i], ignoreStorage))
				return false;
		return true;
	} else if (a.nodeType == ir.NodeType.StorageType ||
			   b.nodeType == ir.NodeType.StorageType) {
		auto sta = cast(ir.StorageType)a;
		auto stb = cast(ir.StorageType)b;
		if ((sta !is null && sta.base is null) || (stb !is null && stb.base is null)) {
			return false;
		}
		throw panic(a.location, "tested storage type for equality");
	}

	return false;
}

int typeToRuntimeConstant(LanguagePass lp, ir.Scope current, ir.Type type)
{
	type = realType(type);
	switch (type.nodeType) with (ir.NodeType) {
	case Struct: return lp.TYPE_STRUCT;
	case Class: return lp.TYPE_CLASS;
	case Interface: return lp.TYPE_INTERFACE;
	case Union: return lp.TYPE_UNION;
	case Enum: return lp.TYPE_ENUM;
	case Attribute: return lp.TYPE_ATTRIBUTE;
	case UserAttribute: return lp.TYPE_USER_ATTRIBUTE;
	case PrimitiveType:
		auto prim = cast(ir.PrimitiveType) type;
		final switch (prim.type) with (ir.PrimitiveType.Kind) {
		case Void: return lp.TYPE_VOID;
		case Ubyte: return lp.TYPE_UBYTE;
		case Byte: return lp.TYPE_BYTE;
		case Char: return lp.TYPE_CHAR;
		case Bool: return lp.TYPE_BOOL;
		case Ushort: return lp.TYPE_USHORT;
		case Short: return lp.TYPE_SHORT;
		case Wchar: return lp.TYPE_WCHAR;
		case Uint: return lp.TYPE_UINT;
		case Int: return lp.TYPE_INT;
		case Dchar: return lp.TYPE_DCHAR;
		case Float: return lp.TYPE_FLOAT;
		case Ulong: return lp.TYPE_ULONG;
		case Long: return lp.TYPE_LONG;
		case Double: return lp.TYPE_DOUBLE;
		case Real: return lp.TYPE_REAL;
		case ir.PrimitiveType.Kind.Invalid:
			throw panic(prim, "invalid primitive kind");
		}
	case PointerType: return lp.TYPE_POINTER;
	case ArrayType: return lp.TYPE_ARRAY;
	case StaticArrayType: return lp.TYPE_STATIC_ARRAY;
	case AAType: return lp.TYPE_AA;
	case FunctionType: return lp.TYPE_FUNCTION;
	case DelegateType: return lp.TYPE_DELEGATE;
	case StorageType:
		auto storage = cast(ir.StorageType) type;
		return typeToRuntimeConstant(lp, current, storage.base);
	default:
		throw panicUnhandled(type, "typeToRuntimeConstant");
	}
}


/*
 *
 * Expression functions.
 *
 */

/**
 * Is the given exp a backend constant, this is the minimum that
 * a backend needs to implement in order to fully support Volt.
 *
 * Backends may support more.
 */
bool isBackendConstant(ir.Exp exp)
{
	if (exp.nodeType == ir.NodeType.Constant) {
		return true;
	}

	auto eref = cast(ir.ExpReference) exp;
	if (eref is null || eref.decl is null) {
		return false;
	}

	if (eref.decl.nodeType != ir.NodeType.Function) {
		return false;
	}

	// This is a ExpReference pointing to a function.
	return true;
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

bool isAssignable(ir.Exp exp)
{
	return isLValueOrAssignable(exp, true);
}

bool isLValue(ir.Exp exp)
{
	return isLValueOrAssignable(exp, false);
}

bool isLValueOrAssignable(ir.Exp exp, bool assign)
{
	switch (exp.nodeType) {
	case ir.NodeType.IdentifierExp:
		throw panic(exp, "IdentifierExp left in ir (run ExTyper)");
	case ir.NodeType.ExpReference: return true;
	case ir.NodeType.Postfix:
		auto asPostfix = cast(ir.Postfix) exp;
		assert(asPostfix !is null);
		return asPostfix.op == ir.Postfix.Op.Identifier ||
		       asPostfix.op == ir.Postfix.Op.Index ||
		       (asPostfix.op == ir.Postfix.Op.Slice && assign);
	case ir.NodeType.Unary:
		auto asUnary = cast(ir.Unary) exp;
		assert(asUnary !is null);
		return isLValueOrAssignable(asUnary.value, assign);
	case ir.NodeType.StatementExp:
		auto sexp = cast(ir.StatementExp) exp;
		assert(sexp !is null);
		return isLValueOrAssignable(sexp.exp, assign);
	default:
		return false;
	}
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
	return asVar.fn.type.isArgRef[asVar.index] || asVar.fn.type.isArgOut[asVar.index];
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

	if (fprim is null || tprim is null) {
		return false;
	}

	auto fromsz = size(fprim.type);
	auto tosz = size(tprim.type);
	
	if (isIntegralOrBool(from) && isIntegral(to)) {
		// to is unsigned.
		if (isUnsigned(tprim.type)) {
			if (isUnsigned(fprim.type)) {
				// uint is implicitly convertable to uint
				return fromsz <= tosz;
			} else {
				// can not implicitly cast signed to unsigned.
				return false;
			}
		}

		// to is signed.
		if (isUnsigned(fprim.type)) {
			// ushort is implicitly convertable to uint
			return fromsz < tosz;
		} else {
			// int is implicitly convertable to int
			return fromsz <= tosz;
		}
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
		auto eref = cast(ir.ExpReference) exp;
		if (eref !is null && eref.decl.nodeType == ir.NodeType.EnumDeclaration) {
			auto edecl = cast(ir.EnumDeclaration) eref.decl;
			return removeCast(edecl.assign);
		}
		auto unary = cast(ir.Unary) exp;
		while (unary !is null && unary.op == ir.Unary.Op.Cast) {
			return removeCast(unary.value);
		}
		return null;
	}

	auto ternary = cast(ir.Ternary) e;
	if (ternary !is null) {
		return fitsInPrimitive(t, ternary.ifTrue) && fitsInPrimitive(t, ternary.ifFalse);
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
			} else if (primitive.type == Uint || primitive.type == Dchar) {
				return constant.u._uint <= max;
			} else if (primitive.type == Long) {
				return constant.u._long >= 0 && cast(ulong) constant.u._long <= max;
			} else if (primitive.type == Ulong) {
				return constant.u._ulong <= max;
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

		bool inFloatRange()
		{
			switch(primitive.type) {
			case Int:
				return constant.u._int >= float.min_normal && constant.u._int <= float.max;
			case Uint:
				return constant.u._uint >= float.min_normal && constant.u._uint <= float.max;
			case Long:
				return constant.u._long >= float.min_normal && constant.u._long <= float.max;
			case Ulong:
				return constant.u._ulong >= float.min_normal && constant.u._ulong <= float.max;
			case Float:
				return constant.u._float >= float.min_normal && constant.u._float <= float.max;
			case Double:
				return constant.u._double >= float.min_normal && constant.u._double <= float.max;
			default:
				assert(false);
			}
		}

		bool inDoubleRange()
		{
			switch(primitive.type) {
			case Int:
				return constant.u._int >= double.min_normal && constant.u._int <= double.max;
			case Uint:
				return constant.u._uint >= double.min_normal && constant.u._uint <= double.max;
			case Long:
				return constant.u._long >= double.min_normal && constant.u._long <= double.max;
			case Ulong:
				return constant.u._ulong >= double.min_normal && constant.u._ulong <= double.max;
			case Float:
				return constant.u._double >= double.min_normal && constant.u._double <= double.max;
			case Double:
				return constant.u._double >= double.min_normal && constant.u._double <= double.max;
			default:
				assert(false);
			}
		}

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


/*
 *
 * Function and variable functions.
 *
 */

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

bool isInFunction(Context ctx)
{
	return ctx.current.node.nodeType == ir.NodeType.Function || ctx.current.node.nodeType == ir.NodeType.BlockStatement;
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
	case Nested:
	case GlobalNested:
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
	case GlobalNested:
	case Nested:
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


bool isNested(ir.Variable.Storage s)
{
	return s == ir.Variable.Storage.Nested;
}

/// Returns true if one of fns's types match fnToMatch. False otherwise.
/// (If fns is empty, this function returns false).
bool containsMatchingFunction(ir.Function[] fns, ir.Function fnToMatch)
{
	foreach (fn; fns) {
		if (typesEqual(fn.type, fnToMatch.type)) {
			return true;
		}
	}
	return false;
}

bool isNested(ir.Function fn)
{
	return fn.kind == ir.Function.Kind.Nested ||
	       fn.kind == ir.Function.Kind.GlobalNested;
}


/*
 *
 * Store functions.
 *
 */

/**
 * Used to determin wether a store is local to a function and therefore
 * can not be shadowed by a with statement.
 */
bool isStoreLocal(LanguagePass lp, ir.Scope current, ir.Store store)
{
	if (store.kind != ir.Store.Kind.Value) {
		return false;
	}

	auto var = cast(ir.Variable) store.node;
	assert(var !is null);

	if (var.storage != ir.Variable.Storage.Function &&
	    var.storage != ir.Variable.Storage.Nested) {
		return false;
	}

	// Yes this is a variable.
	return true;
}


/*
 *
 * Aggregate functions.
 *
 */

/// Retrieves the types of Variables in _struct, in the order they appear.
ir.Type[] getStructFieldTypes(ir.Struct _struct)
{
	ir.Type[] types;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asVar = cast(ir.Variable) node;
		if (asVar is null ||
		    asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}
		types ~= asVar.type;
		assert(types[$-1] !is null);
	}

	return types;
}

/// Retrieves the Variables in _struct, in the order they appear.
ir.Variable[] getStructFieldVars(ir.Struct _struct)
{
	ir.Variable[] vars;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asVar = cast(ir.Variable) node;
		if (asVar is null) {
			continue;
		}
		vars ~= asVar;
	}

	return vars;
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

bool isPointerToClass(ir.Type t)
{
	auto ptr = cast(ir.PointerType) realType(t);
	if (ptr is null) {
		return false;
	}
	auto _class = cast(ir.Class) realType(ptr.base);
	return _class !is null;
}

/**
 * How far removed from Object is this class?
 */
size_t distanceFromObject(ir.Class _class)
{
	size_t distance;
	while (_class.parent !is null) {
		distance++;
		_class = _class.parentClass;
	}
	return distance;
}

/**
 * Given two classes, return their closest relative.
 */
ir.Class commonParent(ir.Class a, ir.Class b)
{
	while (!typesEqual(a, b)) {
		if (distanceFromObject(a) > distanceFromObject(b)) {
			a = a.parentClass;
		} else {
			b = b.parentClass;
		}
	}
	return a;
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
	case Equal:    return "opEquals";
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
