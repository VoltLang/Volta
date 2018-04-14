/*#D*/
// Copyright 2015-2017, Bernard Helyer.
// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Module containing the @ref ScopeReplacer class.
 *
 * @ingroup passPost
 */
module volta.postparse.scopereplacer;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.util;
import volta.util.sinks;

import volta.errors;
import volta.interfaces;
import volta.visitor.visitor;
import volta.visitor.scopemanager;


/*!
 * Module containing the @ref ScopeReplacer class.
 *
 * @ingroup passes passLang passPost
 */
class ScopeReplacer : NullVisitor, Pass
{
public:
	ErrorSink errSink;


protected:
	FunctionSink mFuncStack;


public:
	this(ErrorSink errSink)
	{
		this.errSink = errSink;
	}

public:
	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	void transform(ir.Module m, ir.Function func, ir.BlockStatement bs)
	{
		enter(func);
		accept(bs, this);
		leave(func);
	}

	override void close()
	{
	}

	override Status enter(ir.Function func)
	{
		funcPush(func);
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		funcPop(func);
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		foreach (i, node; bs.statements) {
			switch (node.nodeType) with (ir.NodeType) {
			case TryStatement:
				auto t = cast(ir.TryStatement) node;
				bs.statements[i] = handleTry(t);
				break;
			case ScopeStatement:
				auto ss = cast(ir.ScopeStatement) node;
				bs.statements[i] = handleScope(ss);
				break;
			default:
			}
		}
		return Continue;
	}

	override Status visit(ir.TemplateDefinition td)
	{
		if (td._struct !is null) {
			return accept(td._struct, this);
		}
		if (td._union !is null) {
			return accept(td._union, this);
		}
		if (td._interface !is null) {
			return accept(td._interface, this);
		}
		if (td._class !is null) {
			return accept(td._class, this);
		}
		if (td._function !is null) {
			return accept(td._function, this);
		}
		panic(errSink, td, "Invalid TemplateDefinition");
		return Continue;
	}


protected:
	/*
	 *
	 * Stack code
	 *
	 */

	final @property ir.Function funcTop()
	{
		return mFuncStack.getLast();
	}

	final void funcPush(ir.Function func)
	{
		mFuncStack.sink(func);
	}

	final void funcPop(ir.Function func)
	{
		assert(mFuncStack.length > 0 && func is funcTop);
		mFuncStack.popLast();
	}


	/*
	 *
	 * Converting code.
	 *
	 */

	final ir.Node handleTry(ir.TryStatement t)
	{
		if (t.finallyBlock is null) {
			return t;
		}
		if (!passert(errSink, t, mFuncStack.length > 0)) {
			return null;
		}

		auto f = t.finallyBlock;
		t.finallyBlock = null;

		auto func = convertToFunction(
			ir.ScopeKind.Exit, f, funcTop);

		auto b = new ir.BlockStatement();
		b.loc = t.loc;
		b.statements = [func, t];

		return b;
	}

	final ir.Function handleScope(ir.ScopeStatement ss)
	{
		if (mFuncStack.length == 0) {
			errorMsg(errSink, ss, scopeOutsideFunctionMsg());
			return null;
		}

		return convertToFunction(ss.kind, ss.block, funcTop);
	}

	final ir.Function convertToFunction(ir.ScopeKind kind, ir.BlockStatement block, ir.Function parent)
	{
		auto func = new ir.Function();
		func.loc = block.loc;
		func.kind = ir.Function.Kind.Nested;

		func.type = new ir.FunctionType();
		func.type.loc = block.loc;
		func.type.ret = buildVoid(/*#ref*/block.loc);

		func.parsedBody = block;

		final switch (kind) with (ir.ScopeKind) {
		case Exit:
			func.isLoweredScopeExit = true;
			func.name = format("__v_scope_exit%s", parent.scopeExits.length);
			parent.scopeExits ~= func;
			break;
		case Success:
			func.isLoweredScopeSuccess = true;
			func.name = format("__v_scope_success%s", parent.scopeSuccesses.length);
			parent.scopeSuccesses ~= func;
			break;
		case Failure:
			func.isLoweredScopeFailure = true;
			func.name = format("__v_scope_failure%s", parent.scopeFailures.length);
			parent.scopeFailures ~= func;
			break;
		}

		return func;
	}
}
