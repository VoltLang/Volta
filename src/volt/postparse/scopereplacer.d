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
			auto ss = cast(ir.ScopeStatement) node;
			if (ss is null) {
				continue;
			}
			if (functionStack.length == 0) {
				throw makeScopeOutsideFunction(ss.location);
			}
			auto p = functionStack[$-1];
			auto func = scopeStatementToFunction(ss);
			final switch (ss.kind) with (ir.ScopeStatement.Kind) {
			case Exit:
				p.scopeExits ~= func;
				func.isLoweredScopeExit = true;
				warning(ss.location, "scope (exit) only partly supported.");
				break;
			case Success:
				p.scopeSuccesses ~= func;
				func.isLoweredScopeSuccess = true;
				break;
			case Failure:
				p.scopeFailures ~= func;
				func.isLoweredScopeFailure = true;
				warning(ss.location, "scope (failure) not supported.");
				break;
			}
			bs.statements[i] = func;
		}
		return Continue;
	}

	private ir.Function scopeStatementToFunction(ir.ScopeStatement ss)
	{
		assert(functionStack.length > 0);
		auto p = functionStack[$-1];
		auto func = new ir.Function();
		func.name = generateName(ss);
		func.location = ss.location;
		func.kind = ir.Function.Kind.Function;

		func.type = new ir.FunctionType();
		func.type.location = ss.location;
		func.type.ret = buildVoid(ss.location);

		func._body = ss.block;

		return func;
	}

	private string generateName(ir.ScopeStatement ss)
	{
		assert(functionStack.length > 0);
		auto p = functionStack[$-1];
		final switch (ss.kind) with (ir.ScopeStatement.Kind) {
		case Exit: return format("__v_scope_exit%s", p.scopeExits.length);
		case Success: return format("__v_scope_success%s", p.scopeSuccesses.length);
		case Failure: return format("__v_scope_failure%s", p.scopeFailures.length);
		}
	}
}
