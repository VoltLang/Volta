/*#D*/
// Copyright 2012-2016, Bernard Helyer.
// Copyright 2012-2016, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volt.semantic.implicit;

import volt.errors;

import ir = volta.ir;
import volta.util.util;

import volta.visitor.visitor;

import volt.semantic.context;
import volt.semantic.classify;
import volt.semantic.typer;
import volt.semantic.util;
import volt.semantic.lookup;


/*!
 * @defgroup semanticImplicit Implicit Type Conversion
 *
 * Contains functions that identify if a type or expression can be converted
 * implicitly to a given type, and functions that do the actual conversion.
 *
 * @ingroup semantic
 */

/*!
 * Call checkAndDoConvert, but convert string literals into pointers, if needed.
 */
void checkAndConvertStringLiterals(Context ctx, ir.Type type, ref ir.Exp exp)
{
	auto ptr = cast(ir.PointerType)realType(type);
	auto constant = cast(ir.Constant)exp;
	if (ptr !is null && constant !is null && constant._string.length != 0) {
		auto a = cast(ir.ArrayType)constant.type;
		exp = buildArrayPtr(/*#ref*/exp.loc, a.base, exp);
	}
	checkAndDoConvert(ctx, type, /*#ref*/exp);
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
	doConvert(ctx, type, /*#ref*/exp);
}

/*!
 * Returns true if the given expression's type converts into type.
 */
bool willConvert(Context ctx, ir.Type type, ir.Exp exp, bool ignoreConst = false)
{
	auto prim = cast(ir.PrimitiveType)realType(type);
	if (prim !is null && fitsInPrimitive(ctx.lp.target, prim, exp)) {
		return true;
	}
	auto rtype = getExpType(exp);
	assert(type !is null);
	assert(rtype !is null);
	return willConvert(type, rtype, ignoreConst);
}

enum IgnoreConst = true;

/*!
 * Returns true if arg converts into param.
 */
bool willConvert(ir.Type ltype, ir.Type rtype, bool ignoreConst = false)
{
	assert(rtype !is null);
	assert(ltype !is null);
	if (typesEqual(ltype, rtype)) {
		return true;
	}

	auto r = realType(rtype);
	auto l = realType(ltype);

	switch (r.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		return willConvertPrimitiveType(l, r, ignoreConst);
	case Enum:
	case TypeReference:
		assert(false);
	case Interface:
		auto iface = r.toInterfaceFast();
		return willConvertInterface(l, iface, ignoreConst);
	case Class:
		auto _class = r.toClassFast();
		return willConvertClass(l, _class, ignoreConst);
	case ArrayType:
	case StaticArrayType:
		return willConvertArray(l, r, ignoreConst);
	case PointerType:
		return willConvertPointer(l, r, ignoreConst);
	case NullType:
		auto nt = realType(l).nodeType;
		return nt == PointerType || nt == Class ||
		       nt == ArrayType || nt == AAType || nt == DelegateType;
	case FunctionSetType:
		return willConvertFunctionSetType(l, r, ignoreConst);
	case FunctionType:
	case DelegateType:
		return willConvertCallable(l, r, ignoreConst);
	case Struct:
		return typesEqual(l, r);
	default: return false;
	}
}

bool willConvertCallable(ir.Type l, ir.Type r, bool ignoreConst)
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
		/* We reverse the parameters because the right hand
		 * delegate will be called according to the signature
		 * of the left.  
		 * That is to say, if you pass a `dg(const(char)[])` to
		 * a function that takes a `dg(string)`, we're really going
		 * string -> const(char)[], not the otherway around.
		 */
		if (!willConvert(rct.params[i], lct.params[i], ignoreConst)) {
			return false;
		}
	}
	return true;
}

bool willConvertInterface(ir.Type l, ir._Interface rInterface, bool ignoreConst)
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
		throw panic(/*#ref*/rInterface.loc, "TODO: interface to different interface.");
	}
}

bool willConvertClassToInterface(ir._Interface lInterface, ir.Class rClass, bool ignoreConst)
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
	handleIfNull(ctx, type, /*#ref*/exp);
	auto rtype = getExpType(exp);
	switch (type.nodeType) {
	case ir.NodeType.AAType:
		bool _null = isNull(exp);
		auto mod = getModuleFromScope(/*#ref*/exp.loc, ctx.current);
		if (_null && !mod.magicFlagD) {
			throw makeBadImplicitCast(exp, rtype, type);
		}
		auto alit = cast(ir.AssocArray)exp;
		if ((_null && mod.magicFlagD) || (alit !is null && alit.pairs.length == 0)) {
			auto aa = new ir.AssocArray();
			aa.loc = exp.loc;
			aa.type = copyTypeSmart(/*#ref*/exp.loc, type);
			exp = aa;
			return;
		}
		break;
	case ir.NodeType.StaticArrayType:
		auto sarray = cast(ir.StaticArrayType)type;
		doConvertStaticArrayType(ctx, sarray, /*#ref*/exp);
		return;
	case ir.NodeType.ArrayType:
		auto atype = cast(ir.ArrayType)type;
		auto sarray = cast(ir.StaticArrayType)realType(getExpType(exp));
		if (sarray !is null && typesEqual(sarray.base, atype.base)) {
			exp = buildSlice(/*#ref*/exp.loc, exp);
			return;
		}
		goto default;
	default:
		if (rtype.nodeType == ir.NodeType.FunctionSetType) {
			throw makeUnexpected(/*#ref*/exp.loc, "overloaded function set");
		}
		if (!typesEqual(realType(type), realType(rtype), IgnoreStorage)) {
			exp = buildCastSmart(/*#ref*/exp.loc, type, exp);
		}
	}
}

private:

bool badConst(ir.Type l, ir.Type r, bool ignoreMutability = false)
{
	if (l is null || r is null || l.nodeType != r.nodeType ||
	    (!mutableIndirection(l) && !ignoreMutability)) {
		// It might be a type mismatch, but it's not a const error.
		return false;
	}
	bool badConst;
	if (l.isImmutable) {
		badConst = !r.isImmutable;
	}
	if (!l.isConst && !l.isImmutable) {
		badConst = r.isConst || r.isImmutable;
	}
	switch (l.nodeType) with (ir.NodeType) {
	case ArrayType:
		auto latype = cast(ir.ArrayType)l;
		auto ratype = cast(ir.ArrayType)r;
		return .badConst(latype.base, ratype.base, true) || badConst;
	case PointerType:
		auto lptr = cast(ir.PointerType)l;
		auto rptr = cast(ir.PointerType)r;
		return .badConst(lptr.base, rptr.base, true) || badConst;
	default:
		return badConst;
	}
}

bool willConvertPrimitiveType(ir.Type l, ir.Type r, bool ignoreConst)
{
	auto rprim = cast(ir.PrimitiveType)r;
	auto lprim = cast(ir.PrimitiveType)l;
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
	if (rprim.type == ir.PrimitiveType.Kind.Bool && isIntegral(lprim)) {
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

bool willConvertFunctionSetType(ir.Type l, ir.Type r, bool ignoreConst)
{
	auto fsettype = cast(ir.FunctionSetType)r;
	auto fnparam = cast(ir.FunctionType)l;
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

bool willConvertPointer(ir.Type l, ir.Type r, bool ignoreConst)
{
	if (!ignoreConst && effectivelyConst(r) && !effectivelyConst(l)) {
		return false;
	}
	auto rptr = cast(ir.PointerType)r;
	auto lptr = cast(ir.PointerType)l;
	if (lptr is null) {
		return false;
	}
	if (!ignoreConst && badConst(lptr, rptr)) {
		return false;
	}
	bool ignoreStorage = !(r.isScope && !l.isScope);
	return typesEqual(lptr, rptr, ignoreStorage);
}

bool willConvertClass(ir.Type l, ir.Class rclass, bool ignoreConst)
{
	switch (l.nodeType) with (ir.NodeType) {
	case Class:
		auto lclass = l.toClassFast();
		return isOrInheritsFrom(rclass, lclass);
	case Interface:
		auto liface = l.toInterfaceFast();
		return willConvertClassToInterface(liface, rclass, ignoreConst);
	case TypeReference:
		throw panic("TypeReference should not reach this point");
	default:
		return false;
	}
}

bool willConvertArray(ir.Type l, ir.Type r, bool ignoreConst)
{
	auto rarr = cast(ir.ArrayType)r;
	auto stype = cast(ir.StaticArrayType)realType(l);
	if (stype !is null && rarr !is null) {
		// The extyper will check the length.
		return willConvert(stype.base, rarr.base, ignoreConst);
	}
	stype = cast(ir.StaticArrayType)realType(r);
	auto larr = cast(ir.ArrayType)realType(l);
	if (stype !is null && larr !is null) {
		return willConvert(larr.base, stype.base, ignoreConst);
	}

	if (!ignoreConst && badConst(larr, rarr)) {
		return false;
	}

	auto atype = cast(ir.ArrayType)realType(l);
	if (atype is null) {
		return false;
	}
	auto astore = accumulateStorage(atype);
	ir.Type rstore;
	if (rarr !is null) {
		rstore = accumulateStorage(rarr);
	}
	bool badImmutable = astore.isImmutable && rstore !is null &&
						!rstore.isImmutable && !rstore.isConst && !ignoreConst;
	if (rarr !is null && typesEqual(deepStripStorage(atype), deepStripStorage(rarr), IgnoreStorage) &&
	    !badImmutable) {
		return true;
	}

	auto ctype = cast(ir.CallableType)atype;
	if (ctype !is null && ctype.homogenousVariadic && rarr is null) {
		return true;
	}

	auto aclass = cast(ir.Class)realType(atype.base);
	ir.Class rclass;
	if (rarr !is null) {
		rclass = cast(ir.Class)realType(rarr.base);
	}
	return false;
}

void doConvertStaticArrayType(Context ctx, ir.StaticArrayType atype, ref ir.Exp exp)
{
	ir.ArrayLiteral alit;
	void checkAlit()
	{
		if (alit is null) {
			throw makeExpected(/*#ref*/exp.loc, "array literal");
		}
		if (alit.exps.length != atype.length) {
			throw makeStaticArrayLengthMismatch(/*#ref*/exp.loc, atype.length,
			                                    alit.exps.length);
		}
		auto ltype = realType(atype.base);
		foreach (ref e; alit.exps) {
			checkAndDoConvert(ctx, ltype, /*#ref*/e);
		}
	}
	alit = cast(ir.ArrayLiteral)exp;
	if (alit is null) {
		auto t = realType(getExpType(exp));
		if (typesEqual(t, atype)) {
			return;
		}
	}
	if (isString(atype.base) && alit !is null) {
		/* HACK to make assigning arrays of strings to static immutable arrays
		 * not completely awful.
		 * See test `arrays.staticArrays.immutableStaticArrayOfStrings`.
		 */
	} else {
		checkAlit();
	}
	if (ctx.functionDepth > 0) {
		exp = buildInternalStaticArrayLiteralSmart(ctx.lp.errSink, /*#ref*/exp.loc, atype, alit.exps);
	}
}
