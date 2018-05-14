/*#D*/
// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.typeinfo;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.util;

import volt.exceptions;
import volt.interfaces;
import volt.errors;

import volta.ir.location;

import volt.semantic.typer;
import volt.semantic.lookup;
import volt.semantic.mangle;
import volt.semantic.classify;
import volt.semantic.util;


/*!
 * Makes the mangledName for the Variable holding the TypeInfo instance.
 */
string getTypeInfoVarName(ir.Type type)
{
	ensureMangled(type);
	return format("_V__TypeInfo_%s", type.mangledName);
}

/*!
 * Returns the type info for type, builds a complete TypeInfo if needed.
 */
ir.Variable getTypeInfo(LanguagePass lp, ir.Module mod, ir.Type type)
{
	if (type.nodeType == ir.NodeType.TypeReference) {
		auto asTR = cast(ir.TypeReference) type;
		type = asTR.type;
	}

	ir.Aggregate asAggr = cast(ir.Aggregate) type;
	if (asAggr !is null) {
		createAggregateVar(lp, asAggr);
		return asAggr.typeInfo;
	}

	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}
	string name = getTypeInfoVarName(type);

	auto typeidStore = lookupInGivenScopeOnly(lp, mod.myScope, /*#ref*/mod.loc, name);
	if (typeidStore !is null) {
		auto asVar = cast(ir.Variable) typeidStore.node;
		return asVar;
	}

	auto literalVar = buildTypeInfoVariable(lp, type, null, false);

	mod.children.nodes ~= literalVar;
	ir.Status status;
	mod.myScope.addValue(literalVar, literalVar.name, /*#out*/status);
	if (status != ir.Status.Success) {
		throw panic(/*#ref*/mod.loc, "value redefinition");
	}

	auto lit = buildTypeInfoLiteral(lp, mod, type);
	literalVar.assign = lit;
	literalVar.type = copyTypeSmart(/*#ref*/type.loc, lit.type);

	return literalVar;
}

/*!
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

/*!
 * Fills in the TypeInfo Variable assign, completing it.
 */
void fillInAggregateVar(LanguagePass lp, ir.Aggregate aggr)
{
	assert(aggr.typeInfo !is null);
	if (aggr.typeInfo.assign !is null) {
		return;
	}

	auto mod = getModuleFromScope(/*#ref*/aggr.loc, aggr.myScope);
	auto lit = buildTypeInfoLiteral(lp, mod, aggr);
	aggr.typeInfo.assign = lit;
	aggr.typeInfo.type = copyTypeSmart(/*#ref*/aggr.loc, lit.type);
}


private:


ir.Variable buildTypeInfoVariable(LanguagePass lp, ir.Type type, ir.Exp assign, bool aggr)
{
	string varName = getTypeInfoVarName(type);

	auto literalVar = new ir.Variable();
	literalVar.loc = type.loc;
	literalVar.isResolved = true;
	literalVar.assign = assign;
	literalVar.type = buildTypeReference(/*#ref*/type.loc, lp.tiTypeInfo, lp.tiTypeInfo.name);
	literalVar.mangledName = varName;
	literalVar.name = varName;
	literalVar.isMergable = !aggr;
	literalVar.useBaseStorage = true;
	literalVar.storage = ir.Variable.Storage.Global;

	return literalVar;
}

ir.ClassLiteral buildTypeInfoLiteral(LanguagePass lp, ir.Module mod, ir.Type type)
{
	assert(type.nodeType != ir.NodeType.TypeReference);
	assert(type.mangledName.length > 0);
	type = realType(type);

	resolveChildStructsAndUnions(lp, type);

	auto typeSize = size(lp.target, type);
	auto typeConstant = buildConstantSizeT(/*#ref*/type.loc, lp.target, typeSize);

	int typeTag = typeToRuntimeConstant(lp, mod.myScope, type);
	auto typeTagConstant = new ir.Constant();
	typeTagConstant.loc = type.loc;
	typeTagConstant.u._int = typeTag;
	typeTagConstant.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
	typeTagConstant.type.loc = type.loc;

	auto mangledNameConstant = new ir.Constant();
	mangledNameConstant.loc = type.loc;
	mangledNameConstant._string = type.mangledName;
	mangledNameConstant.arrayData = cast(immutable(void)[]) mangledNameConstant._string;
	mangledNameConstant.type = new ir.ArrayType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Char));

	bool mindirection = mutableIndirection(type);
	auto mindirectionConstant = new ir.Constant();
	mindirectionConstant.loc = type.loc;
	mindirectionConstant.u._bool = mindirection;
	mindirectionConstant.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
	mindirectionConstant.type.loc = type.loc;

	auto literal = new ir.ClassLiteral();
	literal.loc = type.loc;
	literal.useBaseStorage = true;
	literal.type = buildTypeReference(/*#ref*/type.loc, lp.tiTypeInfo, lp.tiTypeInfo.name);

	// TypeInfo.size, TypeInfo.type, TypeInfo.mangledName, and TypeInfo.mutableIndirection. 
	literal.exps ~= typeConstant;
	literal.exps ~= typeTagConstant;
	literal.exps ~= mangledNameConstant;
	literal.exps ~= mindirectionConstant;

	// TypeInfo.classVtable and TypeInfo.classSize.
	auto asClass = type.toClassChecked();
	if (asClass !is null) {
		literal.exps ~= buildCast(/*#ref*/type.loc, buildVoidPtr(/*#ref*/type.loc),
				buildAddrOf(/*#ref*/type.loc, buildExpReference(/*#ref*/type.loc, asClass.initVariable, "__cinit")));
		lp.actualize(asClass.layoutStruct);
		auto s = size(lp.target, asClass.layoutStruct);
		literal.exps ~= buildConstantSizeT(/*#ref*/type.loc, lp.target, size(lp.target, asClass.layoutStruct));
	} else {
		literal.exps ~= buildConstantNull(/*#ref*/type.loc, buildVoidPtr(/*#ref*/type.loc));
		literal.exps ~= buildConstantSizeT(/*#ref*/type.loc, lp.target, 0);
	}

	// TypeInfo.base.
	auto asArray = type.toArrayTypeChecked();
	auto asPointer = type.toPointerTypeChecked();
	auto asStaticArray = type.toStaticArrayTypeChecked();
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
		literal.exps ~= buildTypeInfoCast(lp.tiTypeInfo, buildExpReference(/*#ref*/type.loc, baseVar));
	} else {
		literal.exps ~= buildConstantNull(/*#ref*/type.loc, lp.tiTypeInfo);
	}

	// TypeInfo.staticArrayLength.
	if (asStaticArray !is null) {
		literal.exps ~= buildConstantSizeT(/*#ref*/type.loc, lp.target, asStaticArray.length);
	} else {
		literal.exps ~= buildConstantSizeT(/*#ref*/type.loc, lp.target, 0);
	}

	// TypeInfo.key and TypeInfo.value.
	auto asAA = type.toAATypeChecked();
	if (asAA !is null) {
		auto keyVar = getTypeInfo(lp, mod, asAA.key);
		auto valVar = getTypeInfo(lp, mod, asAA.value);
		literal.exps ~= buildTypeInfoCast(lp.tiTypeInfo, buildExpReference(/*#ref*/type.loc, keyVar));
		literal.exps ~= buildTypeInfoCast(lp.tiTypeInfo, buildExpReference(/*#ref*/type.loc, valVar));
	} else {
		literal.exps ~= buildConstantNull(/*#ref*/type.loc, lp.tiTypeInfo);
		literal.exps ~= buildConstantNull(/*#ref*/type.loc, lp.tiTypeInfo);
	}

	// TypeInfo.ret and args.
	auto asCallable = cast(ir.CallableType)type;
	if (asCallable !is null) {
		auto retVar = getTypeInfo(lp, mod, asCallable.ret);
		literal.exps ~= buildTypeInfoCast(lp.tiTypeInfo, buildExpReference(/*#ref*/type.loc, retVar));

		ir.Exp[] exps;
		foreach (param; asCallable.params) {
			auto var = getTypeInfo(lp, mod, param);
			exps ~= buildTypeInfoCast(lp.tiTypeInfo, buildExpReference(/*#ref*/type.loc, var));
		}

		literal.exps ~= buildArrayLiteralSmart(/*#ref*/type.loc, buildArrayType(/*#ref*/type.loc, lp.tiTypeInfo), exps);
	} else {
		literal.exps ~= buildConstantNull(/*#ref*/type.loc, lp.tiTypeInfo);
		literal.exps ~= buildArrayLiteralSmart(/*#ref*/type.loc, buildArrayType(/*#ref*/type.loc, lp.tiTypeInfo));
	}

	// TypeInfo.classinfo
	if (asClass !is null) {
		literal.type = buildTypeReference(/*#ref*/type.loc, lp.tiClassInfo, lp.tiClassInfo.name);
		literal.exps ~= getClassInfo(/*#ref*/type.loc, mod, lp, asClass);
	}

	return literal;
}

ir.Exp[] getClassInfo(ref in Location loc, ir.Module mod, LanguagePass lp, ir.Class asClass)
{
	ir.Exp[] exps;
	ir.Exp[] interfaceLits;
	panicAssert(asClass, asClass.parentInterfaces.length <= asClass.interfaceOffsets.length);
	foreach (i, iface; asClass.parentInterfaces) {
		auto lit = new ir.ClassLiteral();
		lit.type = buildTypeReference(/*#ref*/loc, lp.tiInterfaceInfo, lp.tiInterfaceInfo.name);
		lit.loc = loc;

		if (iface.mangledName is null) {
			iface.mangledName = mangle(iface);
		}
		auto ifaceVar = getTypeInfo(lp, mod, iface);
		lit.exps ~= buildTypeInfoCast(lp.tiTypeInfo, buildExpReference(/*#ref*/loc, ifaceVar));

		lit.exps ~= buildConstantSizeT(/*#ref*/loc, lp.target, asClass.interfaceOffsets[i]);
		interfaceLits ~= lit;
	}
	exps ~= buildArrayLiteralSmart(/*#ref*/loc, buildArrayType(/*#ref*/loc, lp.tiInterfaceInfo), interfaceLits);
	return exps;
}
