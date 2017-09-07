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


/*!
 * @defgroup semanticImplicit Implicit Type Conversion
 *
 * Contains functions that identify if a type or expression can be converted
 * implicitly to a given type, and functions that do the actual conversion.
 */

/*!
 * Call checkAndDoConvert, but convert string literals into pointers, if needed.
 */
void checkAndConvertStringLiterals(Context ctx, ir.Type type, ref ir.Exp exp)
{
	auto ptr = cast(ir.PointerType) realType(type);
	auto constant = cast(ir.Constant) exp;
	if (ptr !is null && constant !is null && constant._string.length != 0) {
		auto a = cast(ir.ArrayType) constant.type;
		exp = buildArrayPtr(exp.loc, a.base, exp);
	}
	checkAndDoConvert(ctx, type, exp);
}

/*!
 * If exp will convert into type, call doConvert to do it, otherwise
 * throw an error, with the loc set to exp.loc.
 */
void checkAndDoConvert(Context ctx, ir.Type type, ref ir.Exp exp)
{
	if (!willConvert(ctx, type, exp)) {
		auto rtype = getExpType(exp);
		throw makeBadImplicitCast(exp, rtype, type);
	}
	doConvert(ctx, type, exp);
}

/*!
 * Returns true if the given expression's type converts into type.
 */
bool willConvert(Context ctx, ir.Type type, ir.Exp exp)
{
	auto prim = cast(ir.PrimitiveType) realType(type);
	if (prim !is null && fitsInPrimitive(ctx.lp.target, prim, exp)) {
		return true;
	}
	auto rtype = getExpType(exp);
	assert(type !is null);
	assert(rtype !is null);
	return willConvert(rtype, type);
}

/*!
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
		auto iface = argument.toInterfaceFast();
		return willConvertInterface(parameter, iface);
	case Class:
		auto _class = argument.toClassFast();
		return willConvertClass(parameter, _class);
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
		return willConvertCallable(parameter, argument);
	case Struct:
		return typesEqual(argument, parameter);
	default: return false;
	}
}

bool willConvertCallable(ir.Type l, ir.Type r)
{
	auto lct = cast(ir.CallableType)l;
	auto rct = cast(ir.CallableType)r;
	if (lct is null || rct is null) {
		return false;
	}
	if (lct.params.length != rct.params.length) {
		return false;
	}
	if (!typesEqual(lct.ret, rct.ret, IgnoreStorage)) {
		return false;
	}
	foreach (i, param; lct.params) {
		if (!typesEqual(lct.params[i], rct.params[i], IgnoreStorage)) {
			return false;
		}
		if (!mutableIndirection(lct.params[i])) {
			continue;
		}
		if (!rct.params[i].isScope && lct.params[i].isScope) {
			return false;
		}
		if (!willConvert(rct.params[i], lct.params[i])) {
			return false;
		}
	}
	return true;
}

bool willConvertInterface(ir.Type l, ir._Interface rInterface)
{
	ir._Interface lInterface;

	switch (l.nodeType) with (ir.NodeType) {
	case Interface:
		lInterface = l.toInterfaceFast();
		break;
	case TypeReference:
		throw panic("TypeReference should not reach this point");
	default:
		return false;
	}

	if (typesEqual(lInterface, rInterface)) {
		return true;
	} else {
		throw panic(rInterface.loc, "TODO: interface to different interface.");
	}
}

bool willConvertClassToInterface(ir._Interface lInterface, ir.Class rClass)
{
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

/*!
 * Change exp so its type is type. This function assumes that
 * willConvert returns true on the given expression.
 */
void doConvert(Context ctx, ir.Type type, ref ir.Exp exp)
{
	handleIfNull(ctx, type, exp);
	auto rtype = getExpType(exp);
	switch (type.nodeType) {
	case ir.NodeType.AAType:
		bool _null = isNull(exp);
		auto alit = cast(ir.ArrayLiteral)exp;
		if ((_null && ctx.lp.beMoreLikeD) || (alit !is null && alit.exps.length == 0)) {
			auto aa = new ir.AssocArray();
			aa.loc = exp.loc;
			aa.type = copyTypeSmart(exp.loc, type);
			exp = aa;
			return;
		}
		break;
	case ir.NodeType.StaticArrayType:
		auto sarray = cast(ir.StaticArrayType)type;
		doConvertStaticArrayType(ctx, sarray, exp);
		return;
	case ir.NodeType.ArrayType:
		auto atype = cast(ir.ArrayType)type;
		auto sarray = cast(ir.StaticArrayType)realType(getExpType(exp));
		if (sarray !is null && typesEqual(sarray.base, atype.base)) {
			exp = buildSlice(exp.loc, exp);
			return;
		}
		goto default;
	default:
		if (rtype.nodeType == ir.NodeType.FunctionSetType) {
			throw makeUnexpected(exp.loc, "overloaded function set");
		}
		if (!typesEqual(realType(type), realType(rtype), IgnoreStorage)) {
			exp = buildCastSmart(exp.loc, type, exp);
		}
	}
}

private:

bool badConst(ir.Type a, ir.Type b, bool ignoreMutability = false)
{
	if (a is null || b is null || a.nodeType != b.nodeType ||
	    (!mutableIndirection(a) && !ignoreMutability)) {
		// It might be a type mismatch, but it's not a const error.
		return false;
	}
	bool badConst = (a.isImmutable || a.isConst) &&
	                !(b.isImmutable || b.isConst);
	switch (a.nodeType) with (ir.NodeType) {
	case ArrayType:
		auto aatype = cast(ir.ArrayType)a;
		auto batype = cast(ir.ArrayType)b;
		return .badConst(aatype.base, batype.base, true) ||
		       (a.isConst && !effectivelyConst(b) &&
			   !effectivelyConst(batype.base));
	case PointerType:
		auto aptr = cast(ir.PointerType)a;
		auto bptr = cast(ir.PointerType)b;
		return .badConst(aptr.base, bptr.base, true) || badConst;
	default:
		return badConst;
	}
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
	foreach (func; fsettype.set.functions) {
		if (typesEqual(func.type, fnparam)) {
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

bool willConvertClass(ir.Type parameter, ir.Class rclass)
{
	switch (parameter.nodeType) with (ir.NodeType) {
	case Class:
		auto lclass = parameter.toClassFast();
		return isOrInheritsFrom(rclass, lclass);
	case Interface:
		auto liface = parameter.toInterfaceFast();
		return willConvertClassToInterface(liface, rclass);
	case TypeReference:
		throw panic("TypeReference should not reach this point");
	default:
		return false;
	}
}

bool willConvertArray(ir.Type l, ir.Type r)
{
	auto rarr = cast(ir.ArrayType) r;
	auto stype = cast(ir.StaticArrayType) realType(l);
	if (stype !is null && rarr !is null) {
		// The extyper will check the length.
		return willConvert(stype.base, rarr.base);
	}
	stype = cast(ir.StaticArrayType)realType(r);
	auto larr = cast(ir.ArrayType)realType(l);
	if (stype !is null && larr !is null) {
		return willConvert(larr.base, stype.base);
	}

	if (badConst(rarr, larr)) {
		return false;
	}

	auto atype = cast(ir.ArrayType) realType(l);
	if (atype is null) {
		return false;
	}
	auto astore = accumulateStorage(atype);
	ir.Type rstore;
	if (rarr !is null) {
		rstore = accumulateStorage(rarr);
	}
	bool badImmutable = astore.isImmutable && rstore !is null &&
	                    !rstore.isImmutable && !rstore.isConst;
	if (rarr !is null && typesEqual(deepStripStorage(atype), deepStripStorage(rarr), IgnoreStorage) &&
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
			throw makeExpected(exp.loc, "array literal");
		}
		if (alit.exps.length != atype.length) {
			throw makeStaticArrayLengthMismatch(exp.loc, atype.length,
			                                    alit.exps.length);
		}
		auto ltype = realType(atype.base);
		foreach (ref e; alit.exps) {
			checkAndDoConvert(ctx, ltype, e);
		}
	}
	alit = cast(ir.ArrayLiteral) exp;
	if (alit is null) {
		auto t = realType(getExpType(exp));
		if (typesEqual(t, atype)) {
			return;
		}
	}
	checkAlit();
	if (ctx.functionDepth > 0) {
		exp = buildInternalStaticArrayLiteralSmart(exp.loc, atype, alit.exps);
	}
}
