// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.overload;

import std.algorithm : sort;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.semantic.classify;
import volt.semantic.typer;


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

ir.Function selectFunction(LanguagePass lp, ir.Scope current, ir.Function[] functions, ir.Exp[] arguments, Location location)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(lp, arg, current);
	}
	return selectFunction(lp, functions, types, location);
}

ir.Function selectFunction(LanguagePass lp, ir.Scope current, ir.FunctionSet fset, ir.Exp[] arguments, Location location)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= getExpType(lp, arg, current);
	}
	return selectFunction(lp, fset, types, location);
}

ir.Function selectFunction(LanguagePass lp, ir.FunctionSet fset, ir.Variable[] arguments, Location location)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(lp, fset, types, location);
}

ir.Function selectFunction(LanguagePass lp, ir.Function[] functions, ir.Variable[] arguments, Location location)
{
	ir.Type[] types;
	foreach (arg; arguments) {
		types ~= arg.type;
	}
	return selectFunction(lp, functions, types, location);
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

/**
 * Returns true if argument converts into parameter.
 */
bool willConvert(ir.Type argument, ir.Type parameter)
{
	if (parameter.nodeType == ir.NodeType.StorageType && argument.nodeType == ir.NodeType.ArrayType) {
		auto _storage = cast(ir.StorageType) parameter;
		if (_storage.type == ir.StorageType.Kind.Ref) {
			return willConvert(argument, _storage.base);
		}
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
		auto lclass = cast(ir.Class) ifTypeRefDeRef(parameter);
		auto rclass = cast(ir.Class) ifTypeRefDeRef(argument);
		if (lclass is null || rclass is null) {
			return false;
		}
		return isOrInheritsFrom(rclass, lclass);
	case ArrayType:
		auto arr = cast(ir.ArrayType) parameter;
		if (arr is null || !isVoid(arr.base)) {
			return false;
		} else {
			return true;
		}
	case PointerType:
		auto ptr = cast(ir.PointerType) parameter;
		if (ptr is null || !isVoid(ptr.base)) {
			return false;
		} else {
			return true;
		}
	case NullType:
		auto nt = realType(parameter).nodeType;
		with (ir.NodeType) {
			return nt == PointerType || nt == Class || nt == ArrayType || nt == AAType || nt == DelegateType;
		}
	default: return false;
	}
}

int matchLevel(ir.Type argument, ir.Type parameter)
{
	if (typesEqual(argument, parameter)) {
		return 4;
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

ir.Function selectFunction(LanguagePass lp, ir.FunctionSet fset, ir.Type[] arguments, Location location)
{
	auto fn = selectFunction(lp, fset.functions, arguments, location);
	return fset.resolved(fn);
}

ir.Function selectFunction(LanguagePass lp, ir.Function[] functions, ir.Type[] arguments, Location location)
{
	assert(functions.length > 0);

	bool correctNumberOfArguments(ir.Function fn, out int defaultArguments)
	{
		foreach (param; fn.params) {
			if (param.assign !is null) {
				defaultArguments++;
			}
		}
		return fn.type.params.length == arguments.length;
	}

	int matchLevel(ir.Function fn)
	{
		assert(fn.type.params.length >= arguments.length);
		if (fn.type.params.length == 0) {
			return 4;
		}
		int[] matchLevels;
		foreach (i, param; fn.type.params) {
			if (i >= arguments.length) {
				assert(fn.params[i].assign !is null);
				matchLevels ~= 4;
			} else {
				matchLevels ~= .matchLevel(arguments[i], param);
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
		}
	}
	if (outFunctions.length == 0) {
		throw makeNoValidFunction(location, functions[0].name, arguments);
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


	throw makeCannotDisambiguate(location, matchedFunctions);
}
