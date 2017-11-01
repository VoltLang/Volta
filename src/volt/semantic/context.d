/*#D*/
// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.context;

import ir = volta.ir;

import volt.errors;
import volt.interfaces;
import volta.ir.location;
import volt.visitor.visitor;


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

	uint mLength;
	uint mParentIndex;
	uint mFunctionDepth;
	ir.Function[] mFunctionStack;
	ir.Exp[] mIndexChildren;
	ir.Exp[] mWithExps;

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

	/*!
	 * Returns how many functions deep this context currently is.
	 */
	final @property uint functionDepth()
	{
		return mFunctionDepth;
	}

	final @property ir.Exp[] withExps()
	{
		return mWithExps;
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
	final void enter(ir.Enum e) { push(e, e.myScope, null); }
	final void enter(ir.Function func) { push(func, func.myScope, func); }
	final void enter(ir.BlockStatement bs) { mCurrent = bs.myScope; }

	final void leave(ir.Module m) { pop(m, m.myScope, null); }
	final void leave(ir.Struct s) { pop(s, s.myScope, null); }
	final void leave(ir.Union u) { pop(u, u.myScope, null); }
	final void leave(ir.Class c) { pop(c, c.myScope, null); }
	final void leave(ir._Interface i) { pop(i, i.myScope, null); }
	final void leave(ir.Enum e) { pop(e, e.myScope, null); }
	final void leave(ir.Function func) { pop(func, func.myScope, func); }
	final void leave(ir.BlockStatement bs) { mCurrent = mCurrent.parent; }

	/*!
	 * Keep track of with statements and switch withs.
	 */
	final void pushWith(ir.Exp exp)
	{
		mWithExps ~= exp;
	}

	/*!
	 * Keep track of with statements and switch withs.
	 */
	final void popWith(ir.Exp exp)
	{
		if (mWithExps[$-1] !is exp) {
			throw panic(exp, "invalid layout");
		}

		mWithExps = mWithExps[0 .. $-1];
	}

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

	final void enter(ir.BuiltinExp bin)
	{
		mIndexChildren ~= bin.children;
	}

	final void leave(ir.BuiltinExp bin)
	{
		mIndexChildren = mIndexChildren[0 .. $-bin.children.length];
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

		size_t len = mFunctionStack.length;
		if (mLength + 1 > len) {
			auto newStack = new ir.Function[](len * 2 + 3);
			newStack[0 .. len] = mFunctionStack[0 .. len];
			mFunctionStack = newStack;
		}

		if (func !is null && currentFunction is null) {
			mParentIndex = mLength;
		}

		mFunctionStack[mLength++] = func;
		mCurrent = ctx;
	}

	void pop(ir.Node n, ir.Scope ctx, ir.Function func)
	{
		if (func !is null) {
			mFunctionDepth--;
		}

		debug if (mCurrent !is ctx) {
			auto str = "invalid scope layout should be " ~
			           ir.getNodeAddressString(n) ~ " is " ~
			           ir.getNodeAddressString(mCurrent.node);
			throw panic(/*#ref*/n.loc, str);
		}

		assert(mLength > 0);
		mFunctionStack[--mLength] = null;

		if (mLength <= mParentIndex) {
			mParentIndex = 0; // Module.
		}

		mCurrent = mCurrent.parent;
	}
}
