// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.typeinfo;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.semantic.classify;
import volt.semantic.lookup;
import volt.semantic.mangle;


/**
 * Makes the mangledName for the Variable holding the TypeInfo instance.
 */
string getTypeInfoVarName(ir.Type type)
{
	ensureMangled(type);
	return "_V__TypeInfo_" ~ type.mangledName;
}

/**
 * Builds a complete TypeInfo, for use on none aggregate Types.
 */
ir.Variable buildTypeInfo(LanguagePass lp, ir.Scope current, ir.Type type)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	auto assign = buildTypeInfoLiteral(lp, current, type);
	return buildTypeInfoVariable(lp, type, assign, false);
}

/**
 * Fills in the TypeInfo Variable on a Aggregate.
 */
void createAggregateVar(LanguagePass lp, ir.Aggregate aggr)
{
	if (aggr.typeInfo !is null) {
		return;
	}

	aggr.typeInfo = buildTypeInfoVariable(lp, aggr, null, true);
	aggr.members.nodes ~= aggr.typeInfo;
}

/**
 * Fills in the TypeInfo Variable assign, completing it.
 */
void fileInAggregateVar(LanguagePass lp, ir.Aggregate aggr)
{
	assert(aggr.typeInfo !is null);
	if (aggr.typeInfo.assign !is null) {
		return;
	}

	aggr.typeInfo.assign = buildTypeInfoLiteral(lp, aggr.myScope, aggr);
}


private:


ir.Variable buildTypeInfoVariable(LanguagePass lp, ir.Type type, ir.Exp assign, bool aggr)
{
	string varName = getTypeInfoVarName(type);

	auto literalVar = new ir.Variable();
	literalVar.location = type.location;
	literalVar.assign = assign;
	literalVar.type = buildTypeReference(type.location, lp.typeInfoClass, lp.typeInfoClass.name);
	literalVar.mangledName = varName;
	literalVar.name = varName;
	literalVar.isWeakLink = !aggr;
	literalVar.useBaseStorage = true;
	literalVar.storage = ir.Variable.Storage.Global;

	return literalVar;
}

ir.ClassLiteral buildTypeInfoLiteral(LanguagePass lp, ir.Scope current, ir.Type type)
{
	assert(type.mangledName !is null);

	int typeSize = size(type.location, lp, type);
	auto typeConstant = buildSizeTConstant(type.location, lp, typeSize);

	int typeTag = typeToRuntimeConstant(lp, current, type);
	auto typeTagConstant = new ir.Constant();
	typeTagConstant.location = type.location;
	typeTagConstant._int = typeTag;
	typeTagConstant.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
	typeTagConstant.type.location = type.location;

	auto mangledNameConstant = new ir.Constant();
	mangledNameConstant.location = type.location;
	mangledNameConstant._string = type.mangledName;
	mangledNameConstant.arrayData = cast(void[]) mangledNameConstant._string;
	mangledNameConstant.type = new ir.ArrayType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Char));

	bool mindirection = mutableIndirection(type);
	auto mindirectionConstant = new ir.Constant();
	mindirectionConstant.location = type.location;
	mindirectionConstant._bool = mindirection;
	mindirectionConstant.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
	mindirectionConstant.type.location = type.location;

	auto literal = new ir.ClassLiteral();
	literal.location = type.location;
	literal.useBaseStorage = true;
	literal.type = buildTypeReference(type.location, lp.typeInfoClass, lp.typeInfoClass.name);

	// TypeInfo.size, TypeInfo.type, TypeInfo.mangledName, and TypeInfo.mutableIndirection. 
	literal.exps ~= typeConstant;
	literal.exps ~= typeTagConstant;
	literal.exps ~= mangledNameConstant;
	literal.exps ~= mindirectionConstant;

	// TypeInfo.classVtable and TypeInfo.classSize.
	auto asClass = cast(ir.Class)type;
	if (asClass !is null) {
		literal.exps ~= buildCast(type.location, buildVoidPtr(type.location),
				buildAddrOf(type.location, buildExpReference(type.location, asClass.vtableVariable, "__vtable_instance")));
		auto s = size(type.location, lp, asClass.layoutStruct);
		literal.exps ~= buildSizeTConstant(type.location, lp, size(type.location, lp, asClass.layoutStruct));
	} else {
		literal.exps ~= buildConstantNull(type.location, buildVoidPtr(type.location));
		literal.exps ~= buildSizeTConstant(type.location, lp, 0);
	}

	// TypeInfo.base.
	auto asArray = cast(ir.ArrayType)type;
	auto asPointer = cast(ir.PointerType)type;
	auto asStaticArray = cast(ir.StaticArrayType)type;
	if (asArray !is null || asPointer !is null || asStaticArray !is null) {
		ir.Type base;
		if (asArray !is null) {
			base = asArray.base;
		} else if (asPointer !is null) {
			assert(asArray is null);
			base = asPointer.base;
		} else {
			assert(asArray is null && asPointer is null && asStaticArray !is null);
			base = asStaticArray.base;
		}
		assert(base !is null);

		auto baseVar = buildTypeInfo(lp, current, base);
		getModuleFromScope(current).children.nodes ~= baseVar;
		literal.exps ~= buildExpReference(type.location, baseVar);
	} else {
		literal.exps ~= buildConstantNull(type.location, lp.typeInfoClass);
	}

	// TypeInfo.staticArrayLength.
	if (asStaticArray !is null) {
		literal.exps ~= buildSizeTConstant(type.location, lp, cast(int) asStaticArray.length);
	} else {
		literal.exps ~= buildSizeTConstant(type.location, lp, 0);
	}

	// TypeInfo.key and TypeInfo.value.
	auto asAA = cast(ir.AAType)type;
	if (asAA !is null) {
		auto keyVar = buildTypeInfo(lp, current, asAA.key);
		auto valVar = buildTypeInfo(lp, current, asAA.value);
		getModuleFromScope(current).children.nodes ~= keyVar;
		getModuleFromScope(current).children.nodes ~= valVar;
		literal.exps ~= buildExpReference(type.location, keyVar);
		literal.exps ~= buildExpReference(type.location, valVar);
	} else {
		literal.exps ~= buildConstantNull(type.location, lp.typeInfoClass);
		literal.exps ~= buildConstantNull(type.location, lp.typeInfoClass);
	}

	// TypeInfo.ret and args.
	auto asCallable = cast(ir.CallableType)type;
	if (asCallable !is null) {
		auto retVar = buildTypeInfo(lp, current, asCallable.ret);
		getModuleFromScope(current).children.nodes ~= retVar;
		literal.exps ~= buildExpReference(type.location, retVar);

		ir.Exp[] exps;
		foreach (param; asCallable.params) {
			auto var = buildTypeInfo(lp, current, param);
			getModuleFromScope(current).children.nodes ~= var;
			exps ~= buildExpReference(type.location, var);
		}

		literal.exps ~= buildArrayLiteralSmart(type.location, buildArrayType(type.location, lp.typeInfoClass), exps);
	} else {
		literal.exps ~= buildConstantNull(type.location, lp.typeInfoClass);
		literal.exps ~= buildArrayLiteralSmart(type.location, buildArrayType(type.location, lp.typeInfoClass));
	}

	return literal;
}
