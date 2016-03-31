// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.manglewriter;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;

import volt.semantic.mangle;
import volt.semantic.classify;


/**
 * Apply mangle symbols to Types and Functions.
 *
 * @ingroup passes passLang
 */
class MangleWriter : NullVisitor, Pass
{
public:
	LanguagePass lp;
	string[] parentNames;
	int functionDepth;
	int aggregateDepth;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	override void transform(ir.Module m)
	{
		parentNames = m.name.strings;
		accept(m, this);
	}

	override void close()
	{
	}

	final void push(string name)
	{
		parentNames ~= [name];
		aggregateDepth++;
	}

	final void pop(string name)
	{
		assert(parentNames[$-1] == name);
		parentNames = parentNames[0 .. $-1];
		aggregateDepth--;
	}

	override Status enter(ir.Struct s) { push(s.name); return Continue; }
	override Status leave(ir.Struct s) { pop(s.name); return Continue; }

	override Status enter(ir.Union u) { push(u.name); return Continue; }
	override Status leave(ir.Union u) { pop(u.name); return Continue; }

	override Status enter(ir.UserAttribute ui) { push(ui.name); return Continue; }
	override Status leave(ir.UserAttribute ui) { pop(ui.name); return Continue; }

	override Status enter(ir.Class c) { push(c.name); return Continue; }
	override Status leave(ir.Class c) { pop(c.name); return Continue; }

	override Status enter(ir.Function func)
	{
		assert(func.name !is null);

		/// @todo check other linkage as well.
		/// @TODO this should live in the mangle code.
		if (func.mangledName !is null) {
			// Do nothing.
		} else if (func.name == "main" &&
		           func.type.linkage != ir.Linkage.C) {
			func.mangledName = "vmain";
		} else if (func.loadDynamic) {
			// @TODO mangle this so that it becomes a variable.
			assert(func.name !is null);
			func.mangledName = mangle(parentNames, func);
		} else if (func.type.linkage == ir.Linkage.C ||
		           func.type.linkage == ir.Linkage.Windows) {
			func.mangledName = func.name;
		} else {
			assert(func.name !is null);
			func.mangledName = mangle(parentNames, func);
		}

		push(func.name);
		functionDepth++;
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		pop(func.name);
		functionDepth--;
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		if (a.type is null ||
		    a.type.mangledName != "") {
			return Continue;
		}
		a.type.mangledName = mangle(a.type);
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		if (v.mangledName !is null) {
			return Continue;
		}
		if (functionDepth > 0) {
			// @todo mangle static variables, but we need static for that.
			return Continue;
		}
		if (aggregateDepth == 0) {
			// Module level -- ensure global or local is specified.
			if (v.storage != ir.Variable.Storage.Local &&
			    v.storage != ir.Variable.Storage.Global) { 
				throw makeExpected(v, "global or local");
			}
		}

		if (v.linkage != ir.Linkage.C && v.linkage != ir.Linkage.Windows) {
			v.mangledName = mangle(parentNames, v);
		} else {
			v.mangledName = v.name;
		}

		return Continue;
	}

	override Status debugVisitNode(ir.Node n)
	{
		auto t = cast(ir.Type) n;
		if (t is null) {
			return Continue;
		}

		if (t.mangledName != "") {
			return Continue;
		}
		t.mangledName = mangle(t);
		return Continue;
	}
}
