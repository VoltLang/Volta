// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.overload;

import std.algorithm : sort, max;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.semantic.classify;
import volt.semantic.typer;
import volt.semantic.extyper;


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
	return selectFunction(lp, functions, types, location, throwOnError);
}

ir.Function selectFunction(LanguagePass lp, ir.Scope current, ir.FunctionSet fset, ir.Exp[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(lp, arg, current);
	}
	return selectFunction(lp, fset, types, location, throwOnError);
}

ir.Function selectFunction(LanguagePass lp, ir.FunctionSet fset, ir.Variable[] arguments, Location location, bool throwOnError = ThrowOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(lp, fset, types, location, throwOnError);
}

ir.Function selectFunction(LanguagePass lp, ir.Function[] functions, ir.Variable[] arguments, Location location, bool throwOnError)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(lp, functions, types, location, throwOnError);
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

int matchLevel(bool homogenous, ir.Type argument, ir.Type parameter)
{
	if (typesEqual(argument, parameter)) {
		return 4;
	}
	if (typesEqual(removeRefAndOut(argument), removeRefAndOut(parameter))) {
		return 3;
	}
	auto asConst = new ir.StorageType();
	asConst.location = argument.location;
	asConst.type = ir.StorageType.Kind.Const;
	asConst.base = argument;
	if (typesEqual(asConst, parameter)) {
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

bool specialisationComparison(ir.Function a, ir.Function b)
{
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
	auto fn = selectFunction(lp, fset.functions, arguments, location, throwOnError);
	if (fn is null) {
		return null;
	}
	return fset.resolved(fn);
}

ir.Function selectFunction(LanguagePass lp, ir.Function[] functions, ir.Type[] arguments, Location location, bool throwOnError = ThrowOnError)
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
				matchLevels ~= .matchLevel(homogenous, arguments[i], param);
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
					matchLevels ~= max(.matchLevel(true, arg, arr.base), .matchLevel(true, arg, arr));
					// Given foo(T[]...) and foo(T) passing a T, the latter should be preferred.
					if (matchLevels[$-1] == 4) {
						matchLevels[$-1] = 3;
					}
				}
			}
		}
		int matchLevel = int.max;
		foreach (l; matchLevels) {
			if (l <= matchLevel) {
				matchLevel = l;
			}
		}
		assert(matchLevel < int.max);
		return matchLevel;
	}

	ir.Function[] outFunctions;
	foreach (fn; functions) {
		int defaultArguments;
		if (correctNumberOfArguments(fn, defaultArguments)) {
			outFunctions ~= fn;
		} else if (fn.params.length == arguments.length + defaultArguments) {
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

	sort!specialisationComparison(matchedFunctions);
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
}
