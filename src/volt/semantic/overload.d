// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.overload;

import watt.algorithm;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.token.location;

import volt.semantic.util;
import volt.semantic.typer;
import volt.semantic.context;
import volt.semantic.classify;


/**
 * Returns true if argument converts into parameter.
 */
bool willConvert(Context ctx, ir.Type type, ir.Exp exp)
{
	auto rtype = getExpType(ctx.lp, exp, ctx.current);
	return willConvert(type, rtype);
}

/**
 * Returns true if argument converts into parameter.
 */
bool willConvert(ir.Type argument, ir.Type parameter)
{
	bool oldArgConst = argument.isConst;
	bool oldArgImmutable = argument.isImmutable;
	bool oldParamConst = parameter.isConst;
	bool oldParamImmutable = parameter.isImmutable;
	if (!mutableIndirection(argument)) {
		argument.isConst = false;
		argument.isImmutable = false;
	}
	if (!mutableIndirection(parameter)) {
		parameter.isConst = false;
		parameter.isImmutable = false;
	}
	scope (exit) {
		argument.isConst = oldArgConst;
		argument.isImmutable = oldArgImmutable;
		parameter.isConst = oldParamConst;
		parameter.isImmutable = oldParamImmutable;
	}
	if (typesEqual(argument, parameter)) {
		return true;
	}

	argument = realType(argument);
	parameter = realType(parameter);

	switch (argument.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto rprim = cast(ir.PrimitiveType) argument;
		auto lprim = cast(ir.PrimitiveType) parameter;
		if (rprim is null || lprim is null) {
			return false;
		}
		if (isUnsigned(rprim.type) != isUnsigned(lprim.type)) {
			return false;
		}
		return size(rprim.type) <= size(lprim.type);
	case Enum:
	case TypeReference:
		assert(false);
	case Class:
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
		if ((liface !is null && rclass !is null) || (lclass !is null && riface !is null)) {
			return implements(liface is null ? riface : liface, lclass is null ? rclass : lclass);
		}
		if (lclass is null || rclass is null) {
			return false;
		}
		return isOrInheritsFrom(rclass, lclass);
	case StaticArrayType:
		uint dummyInt;
		ir.Exp dummyExp;
		return willConvertStaticArray(parameter, argument, dummyInt, dummyExp);
	case ArrayType:
		uint dummyInt;
		ir.Exp dummyExp;
		return willConvertArray(parameter, argument, dummyInt, dummyExp);
	case PointerType:
		auto ptr = cast(ir.PointerType) parameter;
		if (ptr is null || !isVoid(ptr.base)) {
			return false;
		} else {
			return true;
		}
	case NullType:
		auto nt = realType(parameter).nodeType;
		return nt == PointerType || nt == Class || nt == ArrayType || nt == AAType || nt == DelegateType;
	default: return false;
	}
	version (Volt) assert(false);
}

bool willConvertStaticArray(ir.Type l, ir.Type r, ref uint flag, ref ir.Exp exp)
{
	auto sa = cast(ir.StaticArrayType) r;
	if (sa is null) {
		return false;
	}
	auto at = buildArrayTypeSmart(sa.location, sa.base);
	return willConvertArray(l, at, flag, exp);
}

bool willConvertArray(ir.Type l, ir.Type r, ref uint flag, ref ir.Exp exp)
{
	auto atype = cast(ir.ArrayType) realType(removeRefAndOut(l));
	if (atype is null) {
		return false;
	}

	auto astore = accumulateStorage(atype);
	auto rarr = cast(ir.ArrayType) removeRefAndOut(r);
	ir.Type rstore;
	if (rarr !is null) {
		rstore = accumulateStorage(rarr);
	}
	bool badImmutable = atype.isImmutable && rstore !is null && !rstore.isImmutable && !rstore.isConst;
	if (rarr !is null && typesEqual(atype, rarr, IgnoreStorage) && !badImmutable && !astore.isScope) {
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
	if (rclass !is null) {
		if (inheritsFrom(rclass, aclass)) {
			if (exp !is null) {
				exp = buildCastSmart(exp.location, buildArrayType(exp.location, aclass), exp);
			}
			return true;
		}
	}

	return false;
}

/**
 * Okay, so here's a rough description of how function overload resolution
 * is supposed to work. No doubt there will be discrepancies between this
 * description and the implementation proper. We in the business call those
 * 'bugs'. 
 *
 * For all functions of a given name, first those without the correct number
 * of parameters are culled.
 *
 * Then of that list, a match level is generated for each function, the match
 * level is the lowest of
 *
 * 4 - Exact match
 * 3 - Exact match with conversion to const
 * 2 - Match with implicit conversion
 * 1 - No match
 *
 * Then the list is culled down to only functions of the highest match level.
 * If the list has only one element, it is chosen, otherwise the functions
 * are sorted by their specialisation: a function is more specialised than
 * another function if its parameters can be given to the other but the other's
 * cannot be given to it. 
 *
 * For example, foo(ChildClass) is more specialised than foo(Object), as ChildClass
 * can be passed as an Object, but not the other way around.
 *
 * If after this, there is a function that is more specialised than the next in the
 * list, it is chosen, otherwise an error is generated.
 */

enum ThrowOnError = true;
enum DoNotThrow = false;

ir.Function selectFunction(LanguagePass lp, ir.Scope current, ir.Function[] functions, ir.Exp[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(lp, arg, current);
	}
	return selectFunction(lp, functions, types, arguments, location, throwOnError);
}

ir.Function selectFunction(LanguagePass lp, ir.Scope current, ir.FunctionSet fset, ir.Exp[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(lp, arg, current);
	}
	return selectFunction(lp, fset, types, arguments, location, throwOnError);
}

ir.Function selectFunction(LanguagePass lp, ir.FunctionSet fset, ir.Variable[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(lp, fset, types, [], location, throwOnError);
}

ir.Function selectFunction(LanguagePass lp, ir.Function[] functions, ir.Variable[] arguments, Location location, bool throwOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(lp, functions, types, [], location, throwOnError);
}

ir.Type ifTypeRefDeRef(ir.Type t)
{
	auto tref = cast(ir.TypeReference) t;
	if (tref is null) {
		return t;
	} else {
		return tref.type;
	}
}

int matchLevel(bool homogenous, ir.Type argument, ir.Type parameter, ir.Exp exp=null)
{
	if (typesEqual(argument, parameter)) {
		return 4;
	}
	if (typesEqual(argument, parameter, IgnoreStorage)) {
		return 3;
	}
	auto prim = cast(ir.PrimitiveType) parameter;
	if (prim !is null && exp !is null && fitsInPrimitive(prim, exp)) {
		return 3;
	}

	auto oldConst = argument.isConst;
	argument.isConst = true;
	auto equalAsConst = typesEqual(argument, parameter);
	argument.isConst = oldConst;
	if (equalAsConst) {
		return 3;
	}

	if (willConvert(argument, parameter)) {
		return 2;
	} else {
		auto pArray = cast(ir.ArrayType) realType(parameter);
		auto aArray = cast(ir.ArrayType) realType(argument);
		if (pArray !is null && aArray !is null && isVoid(aArray.base)) {
			return 2;
		}
		if (homogenous) {
			if (pArray !is null && willConvert(argument, pArray.base)) {
				return matchLevel(homogenous, argument, pArray.base);
			}
		}
		return 1;
	}
	version (Volt) assert(false);
}

bool specialisationComparison(object.Object ao, object.Object bo)
{
	auto a = cast(ir.Function) ao;
	auto b = cast(ir.Function) bo;
	assert(a !is null && b !is null);
	if (a.type.params.length != b.type.params.length) {
		auto longer = a.params.length > b.params.length ? a : b;
		assert(longer.params[$-1].assign !is null);
		return a.params.length < b.params.length;
	}
	bool atob = true, btoa = true;
	for (size_t i = 0; i < a.type.params.length; ++i) {
		auto at = a.params[i].type;
		auto bt = b.params[i].type;
		if (!willConvert(at, bt)) {
			atob = false;
		}
		if (!willConvert(bt, at)) {
			btoa = false;
		}
	}

	return atob && !btoa;
}

ir.Function selectFunction(LanguagePass lp, ir.FunctionSet fset, ir.Type[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	return selectFunction(lp, fset, arguments, [], location, throwOnError);
}

ir.Function selectFunction(LanguagePass lp, ir.FunctionSet fset, ir.Type[] arguments, ir.Exp[] exps, Location location, bool throwOnError = ThrowOnError)
{
	auto fn = selectFunction(lp, fset.functions, arguments, exps, location, throwOnError);
	if (fn is null) {
		return null;
	}
	return fset.resolved(fn);
}

ir.Function selectFunction(LanguagePass lp, ir.Function[] functions, ir.Type[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	return selectFunction(lp, functions, arguments, [], location, throwOnError);
}

ir.Function selectFunction(LanguagePass lp, ir.Function[] functions, ir.Type[] arguments, ir.Exp[] exps, Location location, bool throwOnError = ThrowOnError)
{
	assert(functions.length > 0);

	bool correctNumberOfArguments(ir.Function fn, out int defaultArguments)
	{
		foreach (i, param; fn.params) {
			if (param.assign !is null && i >= arguments.length) {
				defaultArguments++;
			}
		}
		return fn.type.params.length == arguments.length;
	}

	int matchLevel(ir.Function fn)
	{
		if (arguments.length > fn.type.params.length) {
			assert(fn.type.homogenousVariadic);
		} else {
			assert(fn.type.params.length >= arguments.length);
		}
		if (fn.type.params.length == 0) {
			return 4;
		}
		int[] matchLevels;
		foreach (i, param; fn.type.params) {
			if (i >= arguments.length) {
				assert(fn.params[i].assign !is null);
				matchLevels ~= 4;
			} else {
				bool homogenous = fn.type.homogenousVariadic && i == fn.type.params.length - 1;
				auto exp = i < exps.length ? exps[i] : null;
				matchLevels ~= .matchLevel(homogenous, arguments[i], param, exp);
			}
		}
		if (fn.type.homogenousVariadic) {
			matchLevels = matchLevels[0 .. $ - 1];
			auto toCheck = arguments[fn.type.params.length - 1 .. $];
			auto arr = cast(ir.ArrayType) realType(fn.type.params[$-1]);
			assert(arr !is null);
			foreach (arg; toCheck) {
				auto atype = cast(ir.ArrayType) arg;
				if (atype !is null && isVoid(atype.base)) {
					matchLevels ~= 2;
				} else {
					auto ml1 = .matchLevel(true, arg, arr.base);
					auto ml2 = .matchLevel(true, arg, arr);
					matchLevels ~= ml1 > ml2 ? ml1 : ml2;
					// Given foo(T[]...) and foo(T) passing a T, the latter should be preferred.
					if (matchLevels[$-1] == 4) {
						matchLevels[$-1] = 3;
					}
				}
			}
		}
		int _matchLevel = int.max;
		foreach (l; matchLevels) {
			if (l <= _matchLevel) {
				_matchLevel = l;
			}
		}
		assert(_matchLevel < int.max);
		return _matchLevel;
	}

	ir.Function[] outFunctions;
	foreach (fn; functions) {
		int defaultArguments;
		if (correctNumberOfArguments(fn, defaultArguments)) {
			outFunctions ~= fn;
		} else if (fn.params.length == arguments.length + cast(size_t)defaultArguments) {
			outFunctions ~= fn;
		} else if (fn.type.homogenousVariadic && arguments.length >= fn.params.length) {
			outFunctions ~= fn;
		}
	}
	if (outFunctions.length == 0) {
		if (throwOnError) {
			throw makeNoValidFunction(location, functions[0].name, arguments);
		} else {
			return null;
		}
	}

	int[] matchLevels;
	foreach (fn; outFunctions) {
		matchLevels ~= matchLevel(fn);
	}
	int highestMatchLevel = -1;
	while (matchLevels.length > 0) {
		if (matchLevels[0] >= highestMatchLevel) {
			highestMatchLevel = matchLevels[0];
		}
		matchLevels = matchLevels[1 .. $];
	}
	assert(highestMatchLevel >= 0);

	ir.Function[] matchedFunctions;
	foreach (fn; outFunctions) {
		if (matchLevel(fn) >= highestMatchLevel) {
			matchedFunctions ~= fn;
		}
	}

	version (Volt) {
		bool cmp(object.Object a, object.Object b) { return specialisationComparison(a, b); }
		sort(cast(object.Object[])matchedFunctions, cmp);
	} else {
		sort(cast(object.Object[])matchedFunctions, &specialisationComparison);
	}
	if (matchedFunctions.length == 1 || specialisationComparison(matchedFunctions[0], matchedFunctions[1]) > 0) {
		if (highestMatchLevel > 1) {
			return matchedFunctions[0];
		}
	}

	if (throwOnError) {
		if (matchedFunctions.length > 1 && highestMatchLevel > 1) {
			throw makeMultipleFunctionsMatch(location, matchedFunctions);
		} else {
			throw makeCannotDisambiguate(location, matchedFunctions);
		}
	} else {
		return null;
	}
	version (Volt) assert(false);
}
