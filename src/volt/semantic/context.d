// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.context;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.languagepass;

/**
 * Builds populates ir.volt.context.Scopes on
 * Modules, Classes, Structs and the like.
 *
 * @ingroup passes passLang
 */
class ContextBuilder : NullVisitor, Pass
{
public:
	LanguagePass lp;
	ir.Scope current;
	ir.Type[] thisStack;
	bool[] funStack;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	void close()
	{
	}

	void transform(ir.Module m)
	{
		if (m.myScope !is null) {
			return;
		}

		accept(m, this);
	}

	ir.Scope newContext(ir.Node n, string name)
	{
		auto newCtx = new ir.Scope(current, n, name);
		return current = newCtx;
	}

	void pop()
	{
		current = current.parent;
	}


	/*
	 * New Scopes.
	 */


	override Status enter(ir.Module m)
	{
		assert(m !is null);
		assert(m.myScope is null);
		assert(current is null);
		// Name
		string name = m.name.identifiers[$-1].value;
		m.myScope = current = new ir.Scope(m, name);

		return Continue;
	}

	override Status leave(ir.Module m)
	{
		assert(current !is null);
		current = null;
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		if (v.storage != ir.Variable.Storage.Invalid) {
			return Continue;
		}

		if (funStack.length == 0) {
			throw new CompilerError(v.location, "module level variables must be explicitly global or local.");
		}

		if (funStack[$-1]) {
			v.storage = ir.Variable.Storage.Function;
		} else {
			v.storage = ir.Variable.Storage.Field;
		}

		return Continue;
	}

	override Status enter(ir.Class c)
	{
		if (c.name is null) {
			throw new CompilerError(c.location, "anonymous interfaces not supported");
		}

		current.addType(c, c.name);
		c.myScope = newContext(c, c.name);

		thisStack ~= c;
		funStack ~= false;

		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		if (i.name is null) {
			throw new CompilerError(i.location, "anonymous interfaces not supported");
		}

		current.addType(i, i.name);
		i.myScope = newContext(i, i.name);

		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		if (s.name is null) {
			throw new CompilerError(s.location, "anonymous structs not supported (yet)");
		}

		current.addType(s, s.name);
		s.myScope = newContext(s, s.name);

		thisStack ~= s;
		funStack ~= false;

		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		// We are in a function.
		funStack ~= true;

		if (fn.name !is null) {
			current.addFunction(fn, fn.name);
		}

		fn.myScope = newContext(fn, fn.name);

		foreach (var; fn.type.params) {
			if (var.name !is null) {
				fn.myScope.addValue(var, var.name);
			}
		}

		if (thisStack.length == 0) {
			return Continue;
		}

		/// @todo not when the function is static
		auto t = thisStack[$-1];

		auto tr = new ir.TypeReference();
		tr.location = t.location;
		tr.names ~= "__this";
		tr.type = t;

		auto thisVar = new ir.Variable();
		thisVar.location = fn.location;
		thisVar.type = tr;
		thisVar.name = "this";
		thisVar.storage = ir.Variable.Storage.Function;
		// For classes this needs to be set.
		thisVar.useBaseStorage = cast(ir.Class)t !is null;

		// Don't add it, it will get added by the variable code.
		fn.thisHiddenParameter = thisVar;
		fn.type.hiddenParameter = true;

		return Continue;
	}

	override Status leave(ir.Class c)
	{
		pop();
		assert(thisStack.length > 0);
		thisStack = thisStack[0 .. $-1];
		assert(funStack.length > 0);
		funStack = funStack[0 .. $-1];
		return Continue;
	}

	override Status leave(ir.Struct s) 
	{ 
		pop();
		assert(thisStack.length > 0);
		thisStack = thisStack[0 .. $-1];
		assert(funStack.length > 0);
		funStack = funStack[0 .. $-1];
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		pop();
		assert(funStack.length > 0);
		funStack = funStack[0 .. $-1];
		return Continue;
	}

	override Status leave(ir._Interface i) { pop(); return Continue; }
}
