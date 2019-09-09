/*#D*/
// Copyright 2012-2013, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module volt.lowerer.typeidreplacer;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.util;

import volt.exceptions;
import volt.interfaces;
import volta.visitor.visitor;

import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.typeinfo;


/*!
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
		exp = buildExpReference(/*#ref*/exp.loc, literalVar, literalVar.name);

		return Continue;
	}
}
