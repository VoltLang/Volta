// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.context;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;


class Context
{
public:
	LanguagePass lp;
	bool isVarAssign;
	ir.Type overrideType;

private:
	ir.Scope mCurrent;
	ir.Module mThisModule;

	uint mLength;
	uint mParentIndex;
	ir.Function[] mFunctionStack;
	ir.Exp[] mIndexChildren;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	/**
	 * Setup the context from a empty state.
	 */
	final void setupFromScope(ir.Scope _scope)
	{
		auto current = _scope;
		while  (current !is null) {
			auto fn = cast(ir.Function) current.node;
			if (fn !is null) {
				push(fn, current, fn);
			}
			current = current.parent;
		}
		mCurrent = _scope;
	}

	/**
	 * Reset the context allowing it to be resued.
	 */
	final void reset()
	{
		foreach (ref f; mFunctionStack[0 .. mLength]) {
			f = null;
		}
		mLength = 0;
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
		return mFunctionStack[mParentIndex];
	}

	final @property ir.Function currentFunction()
	{
		return mLength == 0 ? null : mFunctionStack[mLength-1];
	}

	final @property bool isNested()
	{
		assert(mLength > 1);
		return mFunctionStack[mLength-2] !is null;
	}

	final @property bool isFunction()
	{
		return currentFunction !is null;
	}

	final @property ir.Exp lastIndexChild()
	{
		return mIndexChildren.length > 0 ? mIndexChildren[$-1] : null;
	}

	/*
	 * Traversal functions.
	 */

	final void enter(ir.Module m) { assert(mCurrent is null); mThisModule = m; push(m, m.myScope, null); }
	final void enter(ir.Struct s) { push(s, s.myScope, null); }
	final void enter(ir.Union u) { push(u, u.myScope, null); }
	final void enter(ir.Class c) { push(c, c.myScope, null); }
	final void enter(ir._Interface i) { push(i, i.myScope, null); }
	final void enter(ir.UserAttribute ui) { push(ui, ui.myScope, null); }
	final void enter(ir.Enum e) { push(e, e.myScope, null); }
	final void enter(ir.Function fn) { push(fn, fn.myScope, fn); }
	final void enter(ir.BlockStatement bs) { mCurrent = bs.myScope; }

	final void leave(ir.Module m) { pop(m, m.myScope, null); }
	final void leave(ir.Struct s) { pop(s, s.myScope, null); }
	final void leave(ir.Union u) { pop(u, u.myScope, null); }
	final void leave(ir.Class c) { pop(c, c.myScope, null); }
	final void leave(ir._Interface i) { pop(i, i.myScope, null); }
	final void leave(ir.UserAttribute ui) { pop(ui, ui.myScope, null); }
	final void leave(ir.Enum e) { pop(e, e.myScope, null); }
	final void leave(ir.Function fn) { pop(fn, fn.myScope, fn); }
	final void leave(ir.BlockStatement bs) { mCurrent = mCurrent.parent; }

	/*
	 * Keep track of index expressions for $ -> array.length replacement.
	 */
	final void enter(ir.Postfix postfix)
	{
		if (postfix.op == ir.Postfix.Op.Index || postfix.op == ir.Postfix.Op.Slice) {
			mIndexChildren ~= postfix.child;
		}
	}

	final void leave(ir.Postfix postfix)
	{
		if (postfix.op == ir.Postfix.Op.Index || postfix.op == ir.Postfix.Op.Slice) {
			mIndexChildren = mIndexChildren[0 .. $-1];
		}
	}

	final void enter(ir.Unary unary)
	{
		if (unary.op == ir.Unary.Op.Dup) {
			mIndexChildren ~= unary.value;
		}
	}

	final void leave(ir.Unary unary)
	{
		if (unary.op == ir.Unary.Op.Dup) {
			mIndexChildren = mIndexChildren[0 .. $-1];
		}
	}

private:
	void push(ir.Node n, ir.Scope ctx, ir.Function fn)
	{
		size_t len = mFunctionStack.length;
		if (mLength + 1 > mFunctionStack.length)
			mFunctionStack.length = len * 2 + 3;

		if (fn !is null && currentFunction is null) {
			mParentIndex = mLength;
		}

		mFunctionStack[mLength++] = fn;
		mCurrent = ctx;
	}

	void pop(ir.Node n, ir.Scope ctx, ir.Function fn)
	{
		debug if (mCurrent !is ctx) {
			auto str = "invalid scope layout should be " ~
			           ir.getNodeAddressString(n) ~ " is " ~
			           ir.getNodeAddressString(mCurrent.node);
			throw panic(n.location, str);
		}

		assert(mLength > 0);
		mFunctionStack[--mLength] = null;

		if (mLength <= mParentIndex) {
			mParentIndex = 0; // Module.
		}

		mCurrent = mCurrent.parent;
	}
}
