// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.scopemanager;

import ir = volt.ir.ir;

import volt.exceptions;

import volt.visitor.visitor;
import volt.visitor.debugprinter;


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
		if (current !is m.myScope) {
			auto str = "invalid scope layout should be " ~
			           getNodeAddressString(m) ~ " is " ~
			           getNodeAddressString(current.node);
			throw CompilerPanic(m.location, str);
		}

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
		if (current !is s.myScope) {
			auto str = "invalid scope layout should be " ~
			           getNodeAddressString(s) ~ " is " ~
			           getNodeAddressString(current.node);
			throw CompilerPanic(s.location, str);
		}

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
		if (current !is c.myScope) {
			auto str = "invalid scope layout should be " ~
			           getNodeAddressString(c) ~ " is " ~
			           getNodeAddressString(current.node);
			throw CompilerPanic(c.location, str);
		}

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
		if (current !is i.myScope) {
			auto str = "invalid scope layout should be " ~
			           getNodeAddressString(i) ~ " is " ~
			           getNodeAddressString(current.node);
			throw CompilerPanic(i.location, str);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.UserAttribute ui)
	{
		current = ui.myScope;
		return Continue;
	}

	override Status leave(ir.UserAttribute ui)
	{
		if (current !is ui.myScope) {
			auto str = "invalid scope layout should be " ~
			           getNodeAddressString(ui) ~ " is " ~
			           getNodeAddressString(current.node);
			throw CompilerPanic(ui.location, str);
		}
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
		if (current !is fn.myScope) {
			auto str = "invalid scope layout should be " ~
			           getNodeAddressString(fn) ~ " is " ~
			           getNodeAddressString(current.node);
			throw CompilerPanic(fn.location, str);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		current = e.myScope;
		return Continue;
	}

	override Status leave(ir.Enum e)
	{
		if (current !is e.myScope) {
			auto str = "invalid scope layout should be " ~
			           getNodeAddressString(e) ~ " is " ~
			           getNodeAddressString(current.node);
			throw CompilerPanic(e.location, str);
		}

		current = current.parent;
		return Continue;
	}
}
