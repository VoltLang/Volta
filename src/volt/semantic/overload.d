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
import volt.semantic.implicit;


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

	int matchLevel(ir.Function func)
	{
		if (arguments.length > func.type.params.length) {
			assert(func.type.homogenousVariadic);
		} else {
			assert(func.type.params.length >= arguments.length);
		}
		if (func.type.params.length == 0) {
			return 4;
		}
		int[] matchLevels;
		foreach (i, param; func.type.params) {
			if (i >= arguments.length && !func.type.homogenousVariadic) {
				assert(func.params[i].assign !is null);
				matchLevels ~= 4;
			} else {
				bool homogenous = func.type.homogenousVariadic && i == func.type.params.length - 1;
				auto exp = i < exps.length ? exps[i] : null;
				if (homogenous && i >= arguments.length) {
					panicAssert(func, i == func.params.length - 1);
					matchLevels ~= 3;
					break;
				} else {
					matchLevels ~= .matchLevel(homogenous, arguments[i], param, exp);
				}
			}
		}
		if (func.type.homogenousVariadic && arguments.length >= func.params.length) {
			matchLevels = matchLevels[0 .. $ - 1];
			auto toCheck = arguments[func.type.params.length - 1 .. $];
			auto arr = cast(ir.ArrayType) realType(func.type.params[$-1]);
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
		panicAssert(func, _matchLevel < int.max);
		return _matchLevel;
	}

	ir.Function[] outFunctions;
	foreach (func; functions) {
		int defaultArguments;
		if (correctNumberOfArguments(func, defaultArguments)) {
			outFunctions ~= func;
		} else if (func.params.length == arguments.length + cast(size_t)defaultArguments) {
			outFunctions ~= func;
		} else if (func.type.homogenousVariadic && arguments.length >= (func.params.length - 1)) {
			panicAssert(func, func.params.length > 0);
			outFunctions ~= func;
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
	foreach (func; outFunctions) {
		matchLevels ~= matchLevel(func);
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
	foreach (func; outFunctions) {
		if (matchLevel(func) >= highestMatchLevel) {
			matchedFunctions ~= func;
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
			throw makeCannotDisambiguate(location, matchedFunctions, arguments);
		}
	} else {
		return null;
	}
	version (Volt) assert(false); // If
}
