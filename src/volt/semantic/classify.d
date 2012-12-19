// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classify;

import std.conv : to;

import ir = volt.ir.ir;


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
	case Int: return 4;
	case Uint: return 4;
	case Long: return 8;
	case Ulong: return 8;
	case Float: return 4;
	case Double: return 8;
	case Real: return 8;
	}
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

bool isComparison(ir.BinOp.Type t)
{
	switch (t) with (ir.BinOp.Type) {
	case OrOr, AndAnd, Equal, NotEqual, Is, NotIs, Less, LessEqual, Greater, GreaterEqual:
		return true;
	default:
		return false;
	}
}

bool isValidPointerArithmeticOperation(ir.BinOp.Type t)
{
	switch (t) with (ir.BinOp.Type) {
	case Add, Sub:
		return true;
	default:
		return false;
	}
}

bool fitsInPrimitive(ir.PrimitiveType t, ir.Exp e)
{
	if (e.nodeType != ir.NodeType.Constant) {
		return false;
	}
	auto asConstant = cast(ir.Constant) e;
	assert(asConstant !is null);

	if (isIntegral(t.type)) {
		long l;
		try {
			l = to!long(asConstant.value);
		} catch (Throwable t) {
			return false;
		}
		switch (t.type) with (ir.PrimitiveType.Kind) {
		case Ubyte:
			return l >= ubyte.min && l <= ubyte.max;
		case Byte:
			return l >= byte.min && l <= byte.max;
		case Ushort:
			return l >= ushort.min && l <= ushort.max;
		case Short:
			return l >= short.min && l <= short.max;
		case Uint:
			return l >= uint.min && l <= uint.max;
		case Int:
			return l >= int.min && l <= int.max;
		case Long:
			return true;
		case Ulong:
			return false;
		case Float:
			return l >= float.min && l <= float.max;
		case Double:
			return l >= double.min && l <= double.max;
		default:
			return false;
		}
	} else {
		return false;
	}
}

/**
 * Determines whether the two given types are the same.
 *
 * Not similar. Not implicitly convertable. The _same_ type.
 * Returns: true if they're the same, false otherwise.
 */
bool typesEqual(ir.Type a, ir.Type b)
{
	if (a.nodeType == ir.NodeType.PrimitiveType &&
	    b.nodeType == ir.NodeType.PrimitiveType) {
		auto ap = cast(ir.PrimitiveType) a;
		auto bp = cast(ir.PrimitiveType) b;
		assert(ap !is null && bp !is null);
		return ap.type == bp.type;
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
		return typesEqual(ap.base, ap.base);
	} else if (a.nodeType == ir.NodeType.TypeReference &&
	           b.nodeType == ir.NodeType.TypeReference) {
		auto ap = cast(ir.TypeReference) a;
		auto bp = cast(ir.TypeReference) b;
		assert(ap !is null && bp !is null);
		return ap.names == bp.names;
	} else if ((a.nodeType == ir.NodeType.FunctionType &&
	            b.nodeType == ir.NodeType.FunctionType) ||
		   (a.nodeType == ir.NodeType.DelegateType &&
	            b.nodeType == ir.NodeType.DelegateType)) {
		auto ap = cast(ir.CallableType) a;
		auto bp = cast(ir.CallableType) b;
		assert(ap !is null && bp !is null);

		if (ap.params.length != bp.params.length)
			return false;
		auto ret = typesEqual(ap.ret, bp.ret);
		if (!ret)
			return false;
		for (int i; i < ap.params.length; i++)
			if (!typesEqual(ap.params[i].type, bp.params[i].type))
				return false;
		return true;
	} else {
		return a is b;
	}
}
