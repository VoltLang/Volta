// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.typeinfo;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.errors;

import volt.token.location;

import volt.semantic.typer;
import volt.semantic.lookup;
import volt.semantic.mangle;
import volt.semantic.classify;


/**
 * Makes the mangledName for the Variable holding the TypeInfo instance.
 */
string getTypeInfoVarName(ir.Type type)
{
	ensureMangled(type);
	return "_V__TypeInfo_" ~ type.mangledName;
}

/**
 * Returns the type info for type, builds a complete TypeInfo if needed.
 */
ir.Variable getTypeInfo(LanguagePass lp, ir.Module mod, ir.Type type)
{
	auto asTR = cast(ir.TypeReference)type;
	auto asAggr = cast(ir.Aggregate) (asTR !is null ? asTR.type : type);
	if (asAggr !is null) {
		createAggregateVar(lp, asAggr);
		return asAggr.typeInfo;
	}

	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}
	string name = getTypeInfoVarName(type);

	auto typeidStore = lookupInGivenScopeOnly(lp, mod.myScope, mod.location, name);
	if (typeidStore !is null) {
		auto asVar = cast(ir.Variable) typeidStore.node;
		return asVar;
	}

	auto literalVar = buildTypeInfoVariable(lp, type, null, false);

	mod.children.nodes ~= literalVar;
	mod.myScope.addValue(literalVar, literalVar.name);

	auto lit = buildTypeInfoLiteral(lp, mod, type);
	literalVar.assign = lit;
	literalVar.type = copyTypeSmart(type.location, lit.type);

	return literalVar;
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

	auto mod = getModuleFromScope(aggr.location, aggr.myScope);
	auto lit = buildTypeInfoLiteral(lp, mod, aggr);
	aggr.typeInfo.assign = lit;
	aggr.typeInfo.type = copyTypeSmart(aggr.location, lit.type);
}


private:


ir.Variable buildTypeInfoVariable(LanguagePass lp, ir.Type type, ir.Exp assign, bool aggr)
{
	string varName = getTypeInfoVarName(type);

	auto literalVar = new ir.Variable();
	literalVar.location = type.location;
	literalVar.isResolved = true;
	literalVar.assign = assign;
	literalVar.type = buildTypeReference(type.location, lp.typeInfoClass, lp.typeInfoClass.name);
	literalVar.mangledName = varName;
	literalVar.name = varName;
	literalVar.isWeakLink = !aggr;
	literalVar.useBaseStorage = true;
	literalVar.storage = ir.Variable.Storage.Global;

	return literalVar;
}

ir.ClassLiteral buildTypeInfoLiteral(LanguagePass lp, ir.Module mod, ir.Type type)
{
	assert(type.mangledName !is null);

	type = realType(type, false);  // Strip storage type.

	auto typeSize = size(lp, type);
	auto typeConstant = buildConstantSizeT(type.location, lp, typeSize);

	int typeTag = typeToRuntimeConstant(lp, mod.myScope, type);
	auto typeTagConstant = new ir.Constant();
	typeTagConstant.location = type.location;
	typeTagConstant.u._int = typeTag;
	typeTagConstant.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
	typeTagConstant.type.location = type.location;

	auto mangledNameConstant = new ir.Constant();
	mangledNameConstant.location = type.location;
	mangledNameConstant._string = type.mangledName;
	mangledNameConstant.arrayData = cast(immutable(void)[]) mangledNameConstant._string;
	mangledNameConstant.type = new ir.ArrayType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Char));

	bool mindirection = mutableIndirection(type);
	auto mindirectionConstant = new ir.Constant();
	mindirectionConstant.location = type.location;
	mindirectionConstant.u._bool = mindirection;
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
				buildAddrOf(type.location, buildExpReference(type.location, asClass.initVariable, "__cinit")));
		auto s = size(lp, asClass.layoutStruct);
		literal.exps ~= buildConstantSizeT(type.location, lp, size(lp, asClass.layoutStruct));
	} else {
		literal.exps ~= buildConstantNull(type.location, buildVoidPtr(type.location));
		literal.exps ~= buildConstantSizeT(type.location, lp, 0);
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

		auto baseVar = getTypeInfo(lp, mod, base);
		literal.exps ~= buildTypeInfoCast(lp, buildExpReference(type.location, baseVar));
	} else {
		literal.exps ~= buildConstantNull(type.location, lp.typeInfoClass);
	}

	// TypeInfo.staticArrayLength.
	if (asStaticArray !is null) {
		literal.exps ~= buildConstantSizeT(type.location, lp, asStaticArray.length);
	} else {
		literal.exps ~= buildConstantSizeT(type.location, lp, 0);
	}

	// TypeInfo.key and TypeInfo.value.
	auto asAA = cast(ir.AAType)type;
	if (asAA !is null) {
		auto keyVar = getTypeInfo(lp, mod, asAA.key);
		auto valVar = getTypeInfo(lp, mod, asAA.value);
		literal.exps ~= buildTypeInfoCast(lp, buildExpReference(type.location, keyVar));
		literal.exps ~= buildTypeInfoCast(lp, buildExpReference(type.location, valVar));
	} else {
		literal.exps ~= buildConstantNull(type.location, lp.typeInfoClass);
		literal.exps ~= buildConstantNull(type.location, lp.typeInfoClass);
	}

	// TypeInfo.ret and args.
	auto asCallable = cast(ir.CallableType)type;
	if (asCallable !is null) {
		auto retVar = getTypeInfo(lp, mod, asCallable.ret);
		literal.exps ~= buildTypeInfoCast(lp, buildExpReference(type.location, retVar));

		ir.Exp[] exps;
		foreach (param; asCallable.params) {
			auto var = getTypeInfo(lp, mod, param);
			exps ~= buildTypeInfoCast(lp, buildExpReference(type.location, var));
		}

		literal.exps ~= buildArrayLiteralSmart(type.location, buildArrayType(type.location, lp.typeInfoClass), exps);
	} else {
		literal.exps ~= buildConstantNull(type.location, lp.typeInfoClass);
		literal.exps ~= buildArrayLiteralSmart(type.location, buildArrayType(type.location, lp.typeInfoClass));
	}

	// TypeInfo.classinfo
	if (asClass !is null) {
		literal.type = buildTypeReference(type.location, lp.classInfoClass, lp.classInfoClass.name);
		literal.exps ~= getClassInfo(type.location, mod, lp, asClass);
	}

	return literal;
}

ir.Exp[] getClassInfo(Location l, ir.Module mod, LanguagePass lp, ir.Class asClass)
{
	ir.Exp[] exps;
	ir.Exp[] interfaceLits;
	panicAssert(asClass, asClass.parentInterfaces.length <= asClass.interfaceOffsets.length);
	foreach (i, iface; asClass.parentInterfaces) {
		auto lit = new ir.ClassLiteral();
		lit.type = buildTypeReference(l, lp.interfaceInfoClass, lp.interfaceInfoClass.name);
		lit.location = l;

		if (iface.mangledName is null) {
			iface.mangledName = mangle(iface);
		}
		auto ifaceVar = getTypeInfo(lp, mod, iface);
		lit.exps ~= buildTypeInfoCast(lp, buildExpReference(l, ifaceVar));

		lit.exps ~= buildConstantSizeT(l, lp, asClass.interfaceOffsets[i]);
		interfaceLits ~= lit;
	}
	exps ~= buildArrayLiteralSmart(l, buildArrayType(l, lp.interfaceInfoClass), interfaceLits);
	return exps;
}
