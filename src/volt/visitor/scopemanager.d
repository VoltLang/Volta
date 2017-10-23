/*#D*/
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
			nodeError(m, current.node);
		}

		current = null;
		return Continue;
	}

	override Status visit(ir.TemplateDefinition td)
	{
		if (td._struct !is null) {
			assert(td._struct.myScope is null);
		}
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		checkPreScope(/*#ref*/s.loc, s.myScope);
		current = s.myScope;
		return Continue;
	}

	override Status leave(ir.Struct s)
	{
		if (current !is s.myScope) {
			nodeError(s, current.node);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		checkPreScope(/*#ref*/u.loc, u.myScope);
		current = u.myScope;
		return Continue;
	}

	override Status leave(ir.Union u)
	{
		if (current !is u.myScope) {
			nodeError(u, current.node);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		checkPreScope(/*#ref*/c.loc, c.myScope);
		current = c.myScope;
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		if (current !is c.myScope) {
			nodeError(c, current.node);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		checkPreScope(/*#ref*/i.loc, i.myScope);
		current = i.myScope;
		return Continue;
	}

	override Status leave(ir._Interface i)
	{
		if (current !is i.myScope) {
			nodeError(i, current.node);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		checkPreScope(/*#ref*/func.loc, func.myScope);
		functionStack ~= func;
		current = func.myScope;
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		assert(functionStack.length > 0 && functionStack[$-1] is func);
		functionStack = functionStack[0 .. $-1];


		if (current !is func.myScope) {
			nodeError(func, current.node);
		}

		current = current.parent;

		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		checkPreScope(/*#ref*/bs.loc, bs.myScope);
		current = bs.myScope;
		return Continue;
	}

	override Status leave(ir.BlockStatement bs)
	{
		if (current !is bs.myScope) {
			nodeError(bs, current.node);
		}

		current = current.parent;
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		checkPreScope(/*#ref*/e.loc, e.myScope);
		current = e.myScope;
		return Continue;
	}

	override Status leave(ir.Enum e)
	{
		if (current !is e.myScope) {
			nodeError(e, current.node);
		}

		current = current.parent;
		return Continue;
	}

private:
	void nodeError(ir.Node a, ir.Node b)
	{
		auto str = format("invalid scope layout should be %s (%s) is %s (%s)",
			ir.getNodeAddressString(a), ir.nodeToString(a.nodeType),
			ir.getNodeAddressString(b), ir.nodeToString(b.nodeType));
		throw panic(/*#ref*/a.loc, str);
	}

	void checkPreScope(ref in Location loc, ir.Scope _scope)
	{
		if (current !is _scope.parent) {
			auto str = format("invalid scope layout (parent) should be %s (%s) is %s (%s)",
		           ir.getNodeAddressString(current.node), ir.nodeToString(current.node.nodeType),
			   ir.getNodeAddressString(_scope.node), ir.nodeToString(_scope.node.nodeType));
			throw panic(/*#ref*/loc, str);
		}
	}
}
