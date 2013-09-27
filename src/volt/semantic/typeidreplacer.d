// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.typeidreplacer;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.typeinfo;
import volt.semantic.mangle;
import volt.semantic.lookup;


/**
 * Replaces typeid(...) expressions with a call
 * to the TypeInfo's constructor.
 */
class TypeidReplacer : NullVisitor, Pass
{
public:
	LanguagePass lp;

	ir.Struct typeinfoVtable;
	ir.Module thisModule;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	override void transform(ir.Module m)
	{
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ref ir.Exp exp, ir.Typeid _typeid)
	{
		assert(_typeid.type !is null);

		auto asTR = cast(ir.TypeReference) _typeid.type;
		ir.Aggregate asAggr;
		if (asTR !is null) {
			asAggr = cast(ir.Aggregate) asTR.type;
		}

		if (asAggr !is null) {
			assert(asAggr.typeInfo !is null);
			exp = buildExpReference(exp.location, asAggr.typeInfo, asAggr.typeInfo.name);
			return Continue;
		}

		string name = getTypeInfoVarName(_typeid.type);
		auto typeidStore = lookupOnlyThisScope(lp, thisModule.myScope, exp.location, name);
		if (typeidStore !is null) {
			auto asVar = cast(ir.Variable) typeidStore.node;
			exp = buildExpReference(exp.location, asVar, asVar.name);
			return Continue;
		}


		ir.Variable literalVar = buildTypeInfo(lp, thisModule.myScope, _typeid.type);

		thisModule.children.nodes = literalVar ~ thisModule.children.nodes;
		thisModule.myScope.addValue(literalVar, literalVar.name);

		exp = buildExpReference(exp.location, literalVar, literalVar.name);

		return Continue;
	}
}
