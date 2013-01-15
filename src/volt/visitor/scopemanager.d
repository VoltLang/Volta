// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.scopemanager;

import ir = volt.ir.ir;

import volt.visitor.visitor;


class ScopeManager : NullVisitor
{
public:
	ir.Scope current;

public:
	override Status enter(ir.Module m)
	{
		assert(current is null);
		current = m.myScope;
		return Continue;
	}

	override Status leave(ir.Module m)
	{
		assert(current == m.myScope);

		current = null;
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		current = s.myScope;
		return Continue;
	}

	override Status leave(ir.Struct s)
	{
		assert(current == s.myScope);

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		current = c.myScope;
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		assert(current == c.myScope);

		current = current.parent;
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		current = i.myScope;
		return Continue;
	}

	override Status leave(ir._Interface i)
	{
		assert(current == i.myScope);

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		current = fn.myScope;
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		assert(current == fn.myScope);

		current = current.parent;
		return Continue;
	}
}
