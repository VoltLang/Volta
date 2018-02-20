/*#D*/
// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.context;

import ir = volta.ir;

import watt.text.format : format;

import volt.errors;
import volt.interfaces;
import volta.ir.location;
import volta.visitor.visitor;
import volta.util.stack;
import volta.util.dup;


class Context
{
public:
	LanguagePass lp;
	Visitor extyper;

	bool isVarAssign;
	ir.Type overrideType;

private:
	ir.Scope mCurrent;
	ir.Module mThisModule;

	uint mParentIndex;
	uint mFunctionDepth;
	ir.Function mParentFunction;
	FunctionStack mFunctionStack;
	ExpStack mIndexChildren;
	ExpStack mWithExps;

public:
	this(LanguagePass lp, Visitor extyper)
	{
		this.lp = lp;
		this.extyper = extyper;
	}

	/*!
	 * Setup the context from a empty state.
	 */
	final void setupFromScope(ir.Scope _scope)
	{
		reversePush(_scope);
		mCurrent = _scope;
	}

	/*!
	 * Reset the context allowing it to be resued.
	 */
	final void reset()
	{
		mFunctionStack.clear();
		mCurrent = null;
	}

	/*
	 * State getter functions.
	 */

	final @property ir.Scope current()
	{
		return mCurrent;
	}

	final @property ir.Function parentFunction()
	{
		return mParentFunction;
	}

	final @property ir.Function currentFunction()
	{
		return mFunctionStack.length == 0 ? null : mFunctionStack.peek();
	}

	/*!
	 * Returns how many functions deep this context currently is.
	 */
	final @property uint functionDepth()
	{
		return mFunctionDepth;
	}

	final @property ir.Exp[] withExps()
	{
		return mWithExps.borrowUnsafe().dup();
	}

	final @property bool isNested()
	{
		assert(mFunctionStack.length > 1);
		auto top = mFunctionStack.pop();
		auto val = mFunctionStack.peek() !is null;
		mFunctionStack.push(top);
		return val;
	}

	final @property bool isFunction()
	{
		return currentFunction !is null;
	}

	final @property ir.Exp lastIndexChild()
	{
		return mIndexChildren.length > 0 ? mIndexChildren.peek() : null;
	}

	/*
	 * Traversal functions.
	 */

	final void enter(ir.Module m) { assert(mCurrent is null); mThisModule = m; push(m, m.myScope, null); }
	final void enter(ir.Struct s) { push(s, s.myScope, null); }
	final void enter(ir.Union u) { push(u, u.myScope, null); }
	final void enter(ir.Class c) { push(c, c.myScope, null); }
	final void enter(ir._Interface i) { push(i, i.myScope, null); }
	final void enter(ir.Enum e) { push(e, e.myScope, null); }
	final void enter(ir.Function func) { push(func, func.myScope, func); }
	final void enter(ir.TemplateInstance ti) { push(ti, ti.myScope, null); }
	final void enter(ir.BlockStatement bs) { mCurrent = bs.myScope; }

	final void leave(ir.Module m) { pop(m, m.myScope, null); }
	final void leave(ir.Struct s) { pop(s, s.myScope, null); }
	final void leave(ir.Union u) { pop(u, u.myScope, null); }
	final void leave(ir.Class c) { pop(c, c.myScope, null); }
	final void leave(ir._Interface i) { pop(i, i.myScope, null); }
	final void leave(ir.Enum e) { pop(e, e.myScope, null); }
	final void leave(ir.Function func) { pop(func, func.myScope, func); }
	final void leave(ir.TemplateInstance ti) { pop(ti, ti.myScope, null); }
	final void leave(ir.BlockStatement bs) { mCurrent = mCurrent.parent; }

	/*!
	 * Keep track of with statements and switch withs.
	 */
	final void pushWith(ir.Exp exp)
	{
		mWithExps.push(exp);
	}

	/*!
	 * Keep track of with statements and switch withs.
	 */
	final void popWith(ir.Exp exp)
	{
		if (mWithExps.peek() !is exp) {
			throw panic(exp, "invalid layout");
		}

		mWithExps.pop();
	}

	/*
	 * Keep track of index expressions for $ -> array.length replacement.
	 */
	final void enter(ir.Postfix postfix)
	{
		if (postfix.op == ir.Postfix.Op.Index || postfix.op == ir.Postfix.Op.Slice) {
			mIndexChildren.push(postfix.child);
		}
	}

	final void leave(ir.Postfix postfix)
	{
		if (postfix.op == ir.Postfix.Op.Index || postfix.op == ir.Postfix.Op.Slice) {
			mIndexChildren.pop();
		}
	}

	final void enter(ir.Unary unary)
	{
		if (unary.op == ir.Unary.Op.Dup) {
			mIndexChildren.push(unary.value);
		}
	}

	final void leave(ir.Unary unary)
	{
		if (unary.op == ir.Unary.Op.Dup) {
			mIndexChildren.pop();
		}
	}

	final void enter(ir.BuiltinExp bin)
	{
		mIndexChildren.push(bin);
	}

	final void leave(ir.BuiltinExp bin)
	{
		foreach (i; 0 .. bin.children.length) {
			mIndexChildren.pop();
		}
	}
private:
	/*!
	 * This function is called from setupFromScope.
	 *
	 * Since we are called from a inner scope we need to get the outer most
	 * scope and work our way back to the scope given to setupFromScope.
	 *
	 * TODO handle more then just functions, for example WithStatements.
	 */
	final void reversePush(ir.Scope _scope)
	{
		if (_scope.parent !is null) {
			reversePush(_scope.parent);
		}

		auto func = cast(ir.Function) _scope.node;
		if (func !is null) {
			push(func, _scope, func);
		}
	}

	void push(ir.Node n, ir.Scope ctx, ir.Function func)
	{
		if (func !is null) {
			mFunctionDepth++;
		}

		if (func !is null && currentFunction is null) {
			mParentFunction = func;
			mParentIndex = cast(uint)mFunctionStack.length;
		}

		mFunctionStack.push(func);
		mCurrent = ctx;
	}

	void pop(ir.Node n, ir.Scope ctx, ir.Function func)
	{
		if (func !is null) {
			mFunctionDepth--;
		}

		debug if (mCurrent !is ctx) {
			auto str = format("invalid scope layout should be %s (%s) is %s (%s)",
			                  ir.getNodeAddressString(n), ir.nodeToString(n.nodeType),
			                  ir.getNodeAddressString(mCurrent.node), ir.nodeToString(mCurrent.node.nodeType));
			throw panic(/*#ref*/n.loc, str);
		}

		mFunctionStack.pop();

		if (mFunctionStack.length <= mParentIndex) {
			mParentIndex = 0; // Module.
			mParentFunction = null;
		}

		mCurrent = mCurrent.parent;
	}
}
