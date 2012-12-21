// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.context;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.languagepass;


class ContextBuilder : NullVisitor, Pass
{
public:
	ir.Scope current;
	ir.Struct[] structStack;

public:
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


	/**
	 * The scopes for types, classes, strucs and functions don't have
	 * a name, and for everyone except functions you need to get the scope
	 * from the ir.Node itself.
	 */
	ir.Scope newContext(ir.Node n)
	{
		return current = new ir.Scope(current, n, null);
	}

	/**
	 * Named scopes for imports and packages.
	 */
	ir.Scope newContext(ir.Node n, string name)
	{
		auto newCtx = new ir.Scope(current, n, name);
		current.addScope(n, current, name);
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
		m.myScope = current = new ir.Scope(m, "");
		m.internalScope = new ir.Scope(m, "");

		return Continue;
	}

	override Status leave(ir.Module m)
	{
		assert(current !is null);
		current = null;
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		current.addType(c, c.name);
		c.myScope = newContext(c);

		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		current.addType(i, i.name);
		i.myScope = newContext(i);

		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		current.addType(s, s.name);
		s.myScope = newContext(s);

		structStack ~= s;		

		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		current.addFunction(fn, fn.name);
		fn.myScope = newContext(fn);
		foreach (var; fn.type.params) {
			fn.myScope.addValue(var, var.name);
		}

		if (structStack.length == 0) {
			return Continue;
		}

		/// @todo not when the function is static

		auto tr = new ir.TypeReference();
		tr.location = structStack[$-1].location;
		tr.names ~= structStack[$-1].name;
		tr.type = structStack[$-1];

		auto thisVar = new ir.Variable();
		thisVar.location = structStack[$-1].location;
		thisVar.type = new ir.PointerType(tr);
		thisVar.name = "this";
		thisVar.mangledName = "this";

		fn.myScope.addValue(thisVar, thisVar.name);
		fn.type.params ~= thisVar;
		fn.type.hiddenParameter = true;

		return Continue;
	}

	override Status leave(ir.Class c) { pop(); return Continue; }
	override Status leave(ir._Interface i) { pop(); return Continue; }

	override Status leave(ir.Struct s) 
	{ 
		pop();
		assert(structStack.length > 0); 
		structStack = structStack[0 .. $-1];
		return Continue;
	}

	override Status leave(ir.Function fn) { pop(); return Continue; }
}
