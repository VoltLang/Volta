// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.typeidreplacer;

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

		auto literalVar = getTypeInfo(lp, thisModule, _typeid.type);
		exp = buildExpReference(exp.location, literalVar, literalVar.name);

		return Continue;
	}
}
