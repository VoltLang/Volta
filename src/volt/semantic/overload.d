// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.overload;

version (Volt) import core.object; // Needed, sort.

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
import volt.semantic.implicit;

import volt.util.sinks;


/*!
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

ir.Function selectFunction(ir.Function[] functions, ir.Exp[] arguments, ref in Location loc, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(arg);
	}
	return selectFunction(functions, types, arguments, loc, throwOnError);
}

ir.Function selectFunction(ir.FunctionSet fset, ir.Exp[] arguments, ref in Location loc, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(arg);
	}
	return selectFunction(fset, types, arguments, loc, throwOnError);
}

ir.Function selectFunction(ir.FunctionSet fset, ir.Variable[] arguments, ref in Location loc, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(fset, types, [], loc, throwOnError);
}

ir.Function selectFunction(ir.Function[] functions, ir.Variable[] arguments, ref in Location loc, bool throwOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(functions, types, [], loc, throwOnError);
}

int matchLevel(bool homogenous, ir.Type argument, ir.Type parameter, ir.Exp exp=null)
{
	if (typesEqual(argument, parameter)) {
		return 4;
	}
	if (typesEqual(argument, parameter, IgnoreStorage)) {
		return 3;
	}
	if (parameter.nodeType == ir.NodeType.PrimitiveType && exp !is null &&
	    fitsInPrimitive(parameter.toPrimitiveTypeFast(), exp)) {
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
}

bool specialisationComparison(Object ao, Object bo)
{
	auto a = cast(ir.Function) ao;
	auto b = cast(ir.Function) bo;
	assert(a !is null && b !is null);
	if (a.type.params.length != b.type.params.length) {
		return false;
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

ir.Function selectFunction(ir.FunctionSet fset, ir.Type[] arguments, ref in Location loc, bool throwOnError = ThrowOnError)
{
	return selectFunction(fset, arguments, [], loc, throwOnError);
}

ir.Function selectFunction(ir.FunctionSet fset, ir.Type[] arguments, ir.Exp[] exps, ref in Location loc, bool throwOnError = ThrowOnError)
{
	auto func = selectFunction(fset.functions, arguments, exps, loc, throwOnError);
	if (func is null) {
		return null;
	}
	return fset.resolved(func);
}

ir.Function selectFunction(ir.Function[] functions, ir.Type[] arguments, ref in Location loc, bool throwOnError = ThrowOnError)
{
	return selectFunction(functions, arguments, [], loc, throwOnError);
}

ir.Function selectFunction(ref FunctionSink functions, ir.Type[] arguments, ref in Location loc, bool throwOnError = ThrowOnError)
{
	return selectFunction(functions.borrowUnsafe(), arguments, [], loc, throwOnError);
}

ir.Function selectFunction(scope ir.Function[] functions, ir.Type[] arguments, ir.Exp[] exps, ref in Location loc, bool throwOnError = ThrowOnError)
{
	panicAssert(loc, functions.length > 0);

	ir.Access lastAccess = functions[0].access;
	for (size_t i = 1; i < functions.length; ++i) {
		auto outFunction = functions[i];
		if (outFunction.access != lastAccess &&
			outFunction.kind != ir.Function.Kind.Constructor) {
			throw makeOverloadedFunctionsAccessMismatch(outFunction, functions[0]);
		}
	}

	bool correctNumberOfArguments(ir.Function func, out int defaultArguments)
	{
		foreach (i, param; func.params) {
			if (param.assign !is null && i >= arguments.length) {
				defaultArguments++;
			}
		}
		return func.type.params.length == arguments.length;
	}

	// These are for the sinks in matchLevel.
	int _matchLevel = int.max;
	void matchSink(scope int[] levels)
	{
		foreach (l; levels) {
			if (l <= _matchLevel) {
				_matchLevel = l;
			}
		}
	}
	IntSink matchLevels;
	int delegate(ir.Function) matchDgt;
	void getFunctionMatchLevels(scope ir.Function[] functions)
	{
		foreach (func; functions) {
			matchLevels.sink(matchDgt(func));
		}
	}
	FunctionSink matchedFunctions;
	int highestMatchLevel = -1;
	void getMatchedFunctions(scope ir.Function[] functions)
	{
		foreach (func; functions) {
			if (matchDgt(func) >= highestMatchLevel) {
				matchedFunctions.sink(func);
			}
		}
	}
	version (Volt) { // Needed, sort.
		bool cmp(size_t ia, size_t ib)
		{
			return specialisationComparison(matchedFunctions.get(ia),
											matchedFunctions.get(ib));
		}
		void swap(size_t ia, size_t ib)
		{
			ir.Function tmp = matchedFunctions.get(ia);
			matchedFunctions.set(ia, matchedFunctions.get(ib));
			matchedFunctions.set(ib, tmp);
		}
	}
	void sortFunctions(scope ir.Function[] functions)
	{
		version (Volt) { // Needed, sort.
			runSort(functions.length, cmp, swap);
		} else {
			sort(cast(Object[])functions, &specialisationComparison);
		}
	}
	void throwError(scope ir.Function[] functions)
	{
		if (functions.length > 1 && highestMatchLevel > 1) {
			throw makeMultipleFunctionsMatch(loc, functions);
		} else {
			throw makeCannotDisambiguate(loc, functions, arguments);
		}
	}

	int matchLevel(ir.Function func)
	{
		auto variadic = func.type.homogenousVariadic || func.type.hasVarArgs;
		if (arguments.length > func.type.params.length) {
			assert(variadic);
		} else {
			assert(func.type.params.length >= arguments.length);
		}
		if (func.type.params.length == 0) {
			return 4;
		}
		IntSink matchLevels;
		foreach (i, param; func.type.params) {
			if (i >= arguments.length && !variadic) {
				assert(func.params[i].assign !is null);
				matchLevels.sink(4);
			} else {
				bool homogenous = variadic && i == func.type.params.length - 1;
				auto exp = i < exps.length ? exps[i] : null;
				if (homogenous && i >= arguments.length) {
					panicAssert(func, i == func.params.length - 1);
					matchLevels.sink(3);
					break;
				} else {
					matchLevels.sink(.matchLevel(homogenous, arguments[i], param, exp));
				}
			}
		}
		if (func.type.homogenousVariadic && arguments.length >= func.params.length) {
			matchLevels.popLast();
			auto toCheck = arguments[func.type.params.length - 1 .. $];
			auto rtype = realType(func.type.params[$-1]);
			assert(rtype.nodeType == ir.NodeType.ArrayType);
			auto arr = realType(func.type.params[$-1]).toArrayTypeFast();
			foreach (arg; toCheck) {
				if (arg.nodeType == ir.NodeType.ArrayType) {
					auto atype = arg.toArrayTypeFast();
					if (isVoid(atype.base)) {
						matchLevels.sink(2);
						continue;
					}
				}
				auto ml1 = .matchLevel(true, arg, arr.base);
				auto ml2 = .matchLevel(true, arg, arr);
				matchLevels.sink(ml1 > ml2 ? ml1 : ml2);
				// Given foo(T[]...) and foo(T) passing a T, the latter should be preferred.
				if (matchLevels.getLast() == 4) {
					matchLevels.setLast(3);
				}
			}
		}
		_matchLevel = int.max;
		version (D_Version2) matchLevels.toSink(&matchSink);
		else matchLevels.toSink(matchSink);
		panicAssert(func, _matchLevel < int.max);
		return _matchLevel;
	}

	FunctionSink outFunctions;
	foreach (func; functions) {
		auto variadic = func.type.homogenousVariadic || func.type.hasVarArgs;
		int defaultArguments;
		if (correctNumberOfArguments(func, defaultArguments)) {
			outFunctions.sink(func);
		} else if (func.params.length == arguments.length + cast(size_t)defaultArguments) {
			outFunctions.sink(func);
		} else if (variadic && arguments.length >= (func.params.length - 1)) {
			panicAssert(func, func.params.length > 0);
			outFunctions.sink(func);
		}
	}
	if (outFunctions.length == 0) {
		if (throwOnError) {
			throw makeNoValidFunction(loc, functions[0].name, arguments);
		} else {
			return null;
		}
	}

	matchLevels.reset();
	version (D_Version2) matchDgt = &matchLevel;
	else matchDgt = cast(int delegate(ir.Function))matchLevel;
	version (D_Version2) outFunctions.toSink(&getFunctionMatchLevels);
	else outFunctions.toSink(getFunctionMatchLevels);

	highestMatchLevel = -1;
	while (matchLevels.length > 0) {
		if (matchLevels.getLast() >= highestMatchLevel) {
			highestMatchLevel = matchLevels.getLast();
		}
		matchLevels.popLast();
	}
	assert(highestMatchLevel >= 0);

	matchedFunctions.reset();
	version (D_Version2) outFunctions.toSink(&getMatchedFunctions);
	else outFunctions.toSink(getMatchedFunctions);

	version (D_Version2) matchedFunctions.toSink(&sortFunctions);
	else matchedFunctions.toSink(sortFunctions);
	if (matchedFunctions.length == 1 || specialisationComparison(matchedFunctions.get(0), matchedFunctions.get(1)) > 0) {
		if (highestMatchLevel > 1) {
			return matchedFunctions.get(0);
		}
	}

	if (throwOnError) {
		version (D_Version2) matchedFunctions.toSink(&throwError);
		else matchedFunctions.toSink(throwError);
	} else {
		return null;
	}
	assert(false); // If
}
