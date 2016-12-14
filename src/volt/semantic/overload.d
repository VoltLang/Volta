// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.overload;

version (Volt) import core.object;

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

ir.Function selectFunction(ir.Function[] functions, ir.Exp[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(arg);
	}
	return selectFunction(functions, types, arguments, location, throwOnError);
}

ir.Function selectFunction(ir.FunctionSet fset, ir.Exp[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(arg);
	}
	return selectFunction(fset, types, arguments, location, throwOnError);
}

ir.Function selectFunction(ir.FunctionSet fset, ir.Variable[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(fset, types, [], location, throwOnError);
}

ir.Function selectFunction(ir.Function[] functions, ir.Variable[] arguments, Location location, bool throwOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(functions, types, [], location, throwOnError);
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
	version (Volt) assert(false); // If
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

ir.Function selectFunction(ir.FunctionSet fset, ir.Type[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	return selectFunction(fset, arguments, [], location, throwOnError);
}

ir.Function selectFunction(ir.FunctionSet fset, ir.Type[] arguments, ir.Exp[] exps, Location location, bool throwOnError = ThrowOnError)
{
	auto func = selectFunction(fset.functions, arguments, exps, location, throwOnError);
	if (func is null) {
		return null;
	}
	return fset.resolved(func);
}

ir.Function selectFunction(ir.Function[] functions, ir.Type[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	return selectFunction(functions, arguments, [], location, throwOnError);
}

ir.Function selectFunction(ir.Function[] functions, ir.Type[] arguments, ir.Exp[] exps, Location location, bool throwOnError = ThrowOnError)
{
	assert(functions.length > 0);

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
	version (Volt) {
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
		version (Volt) {
			runSort(functions.length, cmp, swap);
		} else {
			sort(cast(Object[])functions, &specialisationComparison);
		}
	}
	void throwError(scope ir.Function[] functions)
	{
		if (functions.length > 1 && highestMatchLevel > 1) {
			throw makeMultipleFunctionsMatch(location, functions);
		} else {
			throw makeCannotDisambiguate(location, functions, arguments);
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
				bool homogenous = func.type.homogenousVariadic && i == func.type.params.length - 1;
				auto exp = i < exps.length ? exps[i] : null;
				if (homogenous && i >= arguments.length) {
					panicAssert(func, i == func.params.length - 1);
					matchLevels.sink(3);
					break;
				} else if (func.type.hasVarArgs) {
					/* Because the extyper has added the two extra variadic
					 * parameters, consider them here.
					 * TODO: Remove this once the lowerer lowers variadics.
					 */
					if (i >= func.params.length - 2) {
						matchLevels.sink(3);
					} else {
						matchLevels.sink(.matchLevel(true, arguments[i], param, exp));
					}
				} else { 
					matchLevels.sink(.matchLevel(homogenous, arguments[i], param, exp));
				}
			}
		}
		if (func.type.homogenousVariadic && arguments.length >= func.params.length) {
			matchLevels.popLast();
			auto toCheck = arguments[func.type.params.length - 1 .. $];
			auto arr = cast(ir.ArrayType) realType(func.type.params[$-1]);
			assert(arr !is null);
			foreach (arg; toCheck) {
				auto atype = cast(ir.ArrayType) arg;
				if (atype !is null && isVoid(atype.base)) {
					matchLevels.sink(2);
				} else {
					auto ml1 = .matchLevel(true, arg, arr.base);
					auto ml2 = .matchLevel(true, arg, arr);
					matchLevels.sink(ml1 > ml2 ? ml1 : ml2);
					// Given foo(T[]...) and foo(T) passing a T, the latter should be preferred.
					if (matchLevels.getLast() == 4) {
						matchLevels.setLast(3);
					}
				}
			}
		}
		_matchLevel = int.max;
		version (Volt) matchLevels.toSink(matchSink);
		else matchLevels.toSink(&matchSink);
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
			throw makeNoValidFunction(location, functions[0].name, arguments);
		} else {
			return null;
		}
	}

	matchLevels.reset();
	version (Volt) matchDgt = cast(int delegate(ir.Function))matchLevel;
	else matchDgt = &matchLevel;
	version (Volt) outFunctions.toSink(getFunctionMatchLevels);
	else outFunctions.toSink(&getFunctionMatchLevels);

	highestMatchLevel = -1;
	while (matchLevels.length > 0) {
		if (matchLevels.getLast() >= highestMatchLevel) {
			highestMatchLevel = matchLevels.getLast();
		}
		matchLevels.popLast();
	}
	assert(highestMatchLevel >= 0);

	matchedFunctions.reset();
	version (Volt) outFunctions.toSink(getMatchedFunctions);
	else outFunctions.toSink(&getMatchedFunctions);

	version (Volt) matchedFunctions.toSink(sortFunctions);
	else matchedFunctions.toSink(&sortFunctions);
	if (matchedFunctions.length == 1 || specialisationComparison(matchedFunctions.get(0), matchedFunctions.get(1)) > 0) {
		if (highestMatchLevel > 1) {
			return matchedFunctions.get(0);
		}
	}

	if (throwOnError) {
		version (Volt) matchedFunctions.toSink(throwError);
		else matchedFunctions.toSink(&throwError);
	} else {
		return null;
	}
	assert(false); // If
}
