// Copyright © 2015, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.postparse.scopereplacer;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.scopemanager;


class ScopeReplacer : NullVisitor, Pass
{
	ir.Function[] functionStack;

	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Function func)
	{
		functionStack ~= func;
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		assert(functionStack.length > 0 && func is functionStack[$-1]);
		functionStack = functionStack[0 .. $-1];
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


private:
	ir.Node handleTry(ir.TryStatement t)
	{
		if (t.finallyBlock is null) {
			return t;
		}
		panicAssert(t, functionStack.length > 0);

		auto f = t.finallyBlock;
		t.finallyBlock = null;

		auto func = convertToFunction(
			ir.ScopeKind.Exit, f, functionStack[$-1]);

		auto b = new ir.BlockStatement();
		b.location = t.location;
		b.statements = [func, t];

		return b;
	}

	ir.Function handleScope(ir.ScopeStatement ss)
	{
		if (functionStack.length == 0) {
			throw makeScopeOutsideFunction(ss.location);
		}

		return convertToFunction(ss.kind, ss.block, functionStack[$-1]);
	}

	ir.Function convertToFunction(ir.ScopeKind kind, ir.BlockStatement block, ir.Function parent)
	{
		auto func = new ir.Function();
		func.location = block.location;
		func.kind = ir.Function.Kind.Nested;

		func.type = new ir.FunctionType();
		func.type.location = block.location;
		func.type.ret = buildVoid(block.location);

		func._body = block;

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
