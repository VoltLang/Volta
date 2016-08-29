// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.scopemanager;

import watt.text.format : format;

import ir = volt.ir.ir;

import volt.errors;
import volt.visitor.visitor;
import volt.token.location : Location;


class ScopeManager : NullVisitor
{
public:
	ir.Scope current;
	ir.Function[] functionStack;

private:
	ir.Module mThisModule;

public:
	override Status enter(ir.Module m)
	{
		assert(current is null);
		mThisModule = m;
		current = m.myScope;
		return Continue;
	}

	override Status leave(ir.Module m)
	{
		if (current !is m.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(m),
			           ir.getNodeAddressString(current.node));
			throw panic(m.location, str);
		}

		current = null;
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		checkPreScope(s.location, s.myScope);
		current = s.myScope;
		return Continue;
	}

	override Status leave(ir.Struct s)
	{
		if (current !is s.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(s),
			           ir.getNodeAddressString(current.node));
			throw panic(s.location, str);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		checkPreScope(u.location, u.myScope);
		current = u.myScope;
		return Continue;
	}

	override Status leave(ir.Union u)
	{
		if (current !is u.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(u),
			           ir.getNodeAddressString(current.node));
			throw panic(u.location, str);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		checkPreScope(c.location, c.myScope);
		current = c.myScope;
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		if (current !is c.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(c),
			           ir.getNodeAddressString(current.node));
			throw panic(c.location, str);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		checkPreScope(i.location, i.myScope);
		current = i.myScope;
		return Continue;
	}

	override Status leave(ir._Interface i)
	{
		if (current !is i.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(i),
			           ir.getNodeAddressString(current.node));
			throw panic(i.location, str);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Annotation ui)
	{
		checkPreScope(ui.location, ui.myScope);
		current = ui.myScope;
		return Continue;
	}

	override Status leave(ir.Annotation ui)
	{
		if (current !is ui.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(ui),
			           ir.getNodeAddressString(current.node));
			throw panic(ui.location, str);
		}
		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		checkPreScope(func.location, func.myScope);
		functionStack ~= func;
		current = func.myScope;
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		assert(functionStack.length > 0 && functionStack[$-1] is func);
		functionStack = functionStack[0 .. $-1];


		if (current !is func.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(func),
			           ir.getNodeAddressString(current.node));
			throw panic(func.location, str);
		}

		current = current.parent;

		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		checkPreScope(bs.location, bs.myScope);
		current = bs.myScope;
		return Continue;
	}

	override Status leave(ir.BlockStatement bs)
	{
		if (current !is bs.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(bs),
			           ir.getNodeAddressString(current.node));
			throw panic(bs.location, str);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		checkPreScope(e.location, e.myScope);
		current = e.myScope;
		return Continue;
	}

	override Status leave(ir.Enum e)
	{
		if (current !is e.myScope) {
			auto str = format("invalid scope layout should be %s is %s",
			           ir.getNodeAddressString(e),
			           ir.getNodeAddressString(current.node));
			throw panic(e.location, str);
		}

		current = current.parent;
		return Continue;
	}

private:
	void checkPreScope(Location loc, ir.Scope _scope)
	{
		if (current !is _scope.parent) {
			auto str = format("invalid scope layout (parent) should be %s is %s",
		           ir.getNodeAddressString(current.node),
			   ir.getNodeAddressString(_scope.node));
			throw panic(loc, str);
		}
	}
}
