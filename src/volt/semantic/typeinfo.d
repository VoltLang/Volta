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
ir.Variable buildTypeInfo(LanguagePass lp, ir.Type type)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	auto assign = buildTypeInfoLiteral(lp, type);
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

	aggr.typeInfo.assign = buildTypeInfoLiteral(lp, aggr);
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

ir.ClassLiteral buildTypeInfoLiteral(LanguagePass lp, ir.Type type)
{
	assert(type.mangledName !is null);

	int typeSize = size(type.location, lp, type);
	auto typeConstant = buildSizeTConstant(type.location, lp, typeSize);

	int typeTag = typeToRuntimeConstant(type);
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

	literal.exps ~= typeConstant;
	literal.exps ~= typeTagConstant;
	literal.exps ~= mangledNameConstant;
	literal.exps ~= mindirectionConstant;

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

	return literal;
}
