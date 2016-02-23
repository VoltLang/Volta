// Copyright © 2012-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.implicit;

import volt.errors;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.visitor.visitor;

import volt.semantic.context;
import volt.semantic.classify;
import volt.semantic.typer;
import volt.semantic.util;
import volt.semantic.storageremoval;

/**
 * @defgroup semanticImplicit Implicit Type Conversion
 *
 * Contains functions that identify if a type or expression can be converted
 * implicitly to a given type, and functions to do the actual conversion.
 */

/**
 * Call checkAndDoConvert, but convert string literals into pointers, if needed.
 */
void checkAndConvertStringLiterals(Context ctx, ir.Type type, ref ir.Exp exp)
{
	auto ptr = cast(ir.PointerType) realType(type, true, true);
	auto constant = cast(ir.Constant) exp;
	if (ptr !is null && constant !is null && constant._string.length != 0) {
		auto a = cast(ir.ArrayType) constant.type;
		exp = buildArrayPtr(exp.location, a.base, exp);
	}
	checkAndDoConvert(ctx, type, exp);
}

/**
 * If exp will convert into type, call doConvert to do it, otherwise
 * throw an error, with the location set to exp.location.
 */
void checkAndDoConvert(Context ctx, ir.Type type, ref ir.Exp exp)
{
	if (!willConvert(ctx, type, exp)) {
		auto rtype = getExpType(ctx.lp, exp, ctx.current);
		throw makeBadImplicitCast(exp, rtype, type);
	}
	doConvert(ctx, type, exp);
}

/**
 * Returns true if the given expression's type converts into type.
 */
bool willConvert(Context ctx, ir.Type type, ir.Exp exp)
{
	auto prim = cast(ir.PrimitiveType)realType(type, true, true);
	if (prim !is null && fitsInPrimitive(prim, exp)) {
		return true;
	}
	auto rtype = getExpType(ctx.lp, exp, ctx.current);
	assert(type !is null);
	assert(rtype !is null);
	return willConvert(rtype, type);
}

/**
 * Returns true if arg converts into param.
 */
bool willConvert(ir.Type arg, ir.Type param)
{
	assert(arg !is null);
	assert(param !is null);
	if (typesEqual(arg, param)) {
		return true;
	}

	auto argument = realType(arg);
	auto parameter = realType(param);

	switch (argument.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		return willConvertPrimitiveType(parameter, argument);
	case Enum:
	case TypeReference:
		assert(false);
	case Interface:
		return willConvertInterface(parameter, argument);
	case Class:
		return willConvertClass(parameter, argument);
	case ArrayType:
	case StaticArrayType:
		return willConvertArray(parameter, argument);
	case PointerType:
		return willConvertPointer(parameter, argument);
	case NullType:
		auto nt = realType(parameter).nodeType;
		return nt == PointerType || nt == Class ||
		       nt == ArrayType || nt == AAType || nt == DelegateType;
	case FunctionSetType:
		return willConvertFunctionSetType(parameter, argument);
	case FunctionType:
	case DelegateType:
		return typesEqual(argument, parameter, IgnoreStorage);
	case Struct:
		return typesEqual(argument, parameter);
	default: return false;
	}
}

bool willConvertInterface(ir.Type l, ir.Type r)
{
	auto lInterface = cast(ir._Interface)realType(l);
	if (lInterface is null) {
		return false;
	}

	auto rInterface = cast(ir._Interface)realType(r);
	if (rInterface !is null) {
		if (typesEqual(lInterface, rInterface)) {
			return true;
		} else {
			throw panic(r.location, "TODO: interface to different interface.");
		}

	}

	auto rClass = cast(ir.Class)realType(r);
	if (rClass is null) {
		return false;
	}

	bool checkInterface(ir._Interface i)
	{
		if (i is lInterface) {
			return true;
		}
		foreach (piface; i.parentInterfaces) {
			if (checkInterface(piface)) {
				return true;
			}
		}
		return false;
	}

	bool checkClass(ir.Class _class)
	{
		if (_class is null) {
			return false;
		}
		foreach (i, classIface; _class.parentInterfaces) {
			if (checkInterface(classIface)) {
				return true;
			}
		}
		if (checkClass(_class.parentClass)) {
			return true;
		}
		return false;
	}
	return checkClass(rClass);
}

/**
 * Change exp so its type is type. This function assumes that
 * willConvert returns true on the given expression.
 */
void doConvert(Context ctx, ir.Type type, ref ir.Exp exp)
{
	handleIfNull(ctx, type, exp);
	auto rtype = getExpType(ctx.lp, exp, ctx.current);
	switch (type.nodeType) {
	case ir.NodeType.AAType:
		auto alit = cast(ir.ArrayLiteral)exp;
		if (alit !is null && alit.exps.length == 0) {
			auto aa = new ir.AssocArray();
			aa.location = exp.location;
			aa.type = copyTypeSmart(exp.location, type);
			exp = aa;
			return;
		}
		break;
	case ir.NodeType.StaticArrayType:
		auto sarray = cast(ir.StaticArrayType)type;
		doConvertStaticArrayType(ctx, sarray, exp);
		return;
	default:
		if (rtype.nodeType == ir.NodeType.FunctionSetType) {
			throw makeUnexpected(exp.location, "overloaded function set");
		}
		if (!typesEqual(realType(type), realType(rtype), IgnoreStorage)) {
			exp = buildCastSmart(exp.location, type, exp);
		}
	}
}

private:

bool badConst(ir.Type a, ir.Type b)
{
	if (a is null || b is null || a.nodeType != b.nodeType ||
	    !mutableIndirection(a)) {
		// It might be a type mismatch, but it's not a const error.
		return false;
	}
	bool badConst = (a.isImmutable || a.isConst) &&
	                !(b.isImmutable || b.isConst);
	switch (a.nodeType) with (ir.NodeType) {
	case ArrayType:
		auto aatype = cast(ir.ArrayType)a;
		auto batype = cast(ir.ArrayType)b;
		return .badConst(aatype.base, batype.base) ||
		       (a.isConst && !effectivelyConst(b) &&
			   !effectivelyConst(batype.base));
	case PointerType:
		auto aptr = cast(ir.PointerType)a;
		auto bptr = cast(ir.PointerType)b;
		return .badConst(aptr.base, bptr.base) || badConst;
	default:
		return badConst;
	}
	assert(false);
}

bool willConvertPrimitiveType(ir.Type parameter, ir.Type argument)
{
	auto rprim = cast(ir.PrimitiveType) argument;
	auto lprim = cast(ir.PrimitiveType) parameter;
	if (rprim is null || lprim is null) {
		return false;
	}

	bool rightFloating = isFloatingPoint(rprim.type);
	bool leftFloating = isFloatingPoint(lprim.type);
	if (leftFloating != rightFloating) {
		return false;
	}
	if (leftFloating && rightFloating) {
		return size(rprim.type) <= size(lprim.type);
	}

	// We are now dealing with integers only.

	// Bool an always be casted to any other integer type.
	if (rprim.type == ir.PrimitiveType.Kind.Bool) {
		return true;
	}

	bool rightUnsigned = isUnsigned(rprim.type);
	bool leftUnsigned = isUnsigned(lprim.type);
	// If they match, we can extend the bits.
	if (rightUnsigned == leftUnsigned) {
		return size(rprim.type) <= size(lprim.type);
	}

	// They are different, is it left that is unsigned.
	// Always false since signed can never convert to unsigned.
	if (leftUnsigned) {
		return false;
	}

	// Smaller unsigned can fit into signed.
	return size(rprim.type) < size(lprim.type);
}

bool willConvertFunctionSetType(ir.Type parameter, ir.Type argument)
{
	auto fsettype = cast(ir.FunctionSetType)argument;
	auto fnparam = cast(ir.FunctionType)parameter;
	if (fnparam is null) {
		return false;
	}
	foreach (fn; fsettype.set.functions) {
		if (typesEqual(fn.type, fnparam)) {
			return true;
		}
	}
	return false;
}

bool willConvertPointer(ir.Type parameter, ir.Type argument)
{
	if (effectivelyConst(argument) && !effectivelyConst(parameter)) {
		return false;
	}
	auto aptr = cast(ir.PointerType) argument;
	auto astr = cast(ir.Struct) aptr.base;
	if (astr !is null) {
		/* @TODO Remove
		 * Hack for Tesla's overloading/024.
		 * The proper fix is to make the Postfix.Call code
		 * run on constructor call.
		 */
		auto loweredType = cast(ir.Type)astr.loweredNode;
		if (loweredType !is null && typesEqual(parameter, loweredType)) {
			return true;
		}
	}
	auto ptr = cast(ir.PointerType) parameter;
	if (ptr is null) {
		return false;
	}
	if (badConst(aptr, ptr)) {
		return false;
	}
	bool ignoreStorage = !(argument.isScope && !parameter.isScope);
	return typesEqual(ptr, aptr, ignoreStorage);
}

bool willConvertClass(ir.Type parameter, ir.Type argument)
{
	if (willConvertInterface(parameter, argument)) {
		return true;
	}
	bool implements(ir._Interface _iface, ir.Class _class)
	{
		foreach (i; _class.parentInterfaces) {
			if (i is _iface) {
				return true;
			}
		}
		return false;
	}
	auto lclass = cast(ir.Class) ifTypeRefDeRef(parameter);
	auto liface = cast(ir._Interface) ifTypeRefDeRef(parameter);
	auto rclass = cast(ir.Class) ifTypeRefDeRef(argument);
	auto riface = cast(ir._Interface) ifTypeRefDeRef(argument);
	if ((liface !is null && rclass !is null) ||
	    (lclass !is null && riface !is null)) {
		return implements(liface is null ? riface : liface,
		                  lclass is null ? rclass : lclass);
	}
	if (lclass is null || rclass is null) {
		return false;
	}
	return isOrInheritsFrom(rclass, lclass);
}

bool willConvertArray(ir.Type l, ir.Type r)
{
	auto rarr = cast(ir.ArrayType) removeRefAndOut(r);
	auto stype = cast(ir.StaticArrayType) realType(removeRefAndOut(l));
	if (stype !is null && rarr !is null) {
		// The extyper will check the length.
		return willConvert(stype.base, rarr.base);
	}
	stype = cast(ir.StaticArrayType)realType(removeRefAndOut(r));
	auto larr = cast(ir.ArrayType)realType(removeRefAndOut(l));
	if (stype !is null && larr !is null) {
		return willConvert(larr.base, stype.base);
	}

	if (badConst(rarr, larr)) {
		return false;
	}

	auto atype = cast(ir.ArrayType) realType(removeRefAndOut(l));
	if (atype is null) {
		return false;
	}
	auto astore = accumulateStorage(atype);
	ir.Type rstore;
	if (rarr !is null) {
		rstore = accumulateStorage(rarr);
	}
	bool badImmutable = atype.isImmutable && rstore !is null &&
	                    !rstore.isImmutable && !rstore.isConst;
	if (rarr !is null && typesEqual(atype, rarr, IgnoreStorage) &&
	    !badImmutable) {
		return true;
	}

	auto ctype = cast(ir.CallableType) atype;
	if (ctype !is null && ctype.homogenousVariadic && rarr is null) {
		return true;
	}

	auto aclass = cast(ir.Class) realType(atype.base);
	ir.Class rclass;
	if (rarr !is null) {
		rclass = cast(ir.Class) realType(rarr.base);
	}
	return false;
}

void doConvertStaticArrayType(Context ctx, ir.StaticArrayType atype, ref ir.Exp exp)
{
	ir.ArrayLiteral alit;
	void checkAlit()
	{
		if (alit is null) {
			throw makeExpected(exp.location, "array literal");
		}
		if (alit.exps.length != atype.length) {
			throw makeStaticArrayLengthMismatch(exp.location, atype.length,
			                                    alit.exps.length);
		}
		auto ltype = realType(atype.base);
		foreach (ref e; alit.exps) {
			acceptExp(e, ctx.extyper);
			checkAndDoConvert(ctx, ltype, e);
		}
	}
	alit = cast(ir.ArrayLiteral) exp;
	if (alit is null) {
		auto t = realType(getExpType(ctx.lp, exp, ctx.current));
		if (typesEqual(t, atype)) {
			return;
		}
	}
	checkAlit();
	if (ctx.functionDepth > 0) {
		exp = buildInternalStaticArrayLiteralSmart(exp.location, atype, alit.exps);
	}
}
