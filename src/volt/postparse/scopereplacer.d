// Copyright © 2015, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.postparse.scopereplacer;

import watt.text.format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.errors;
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

	override Status enter(ir.Function fn)
	{
		functionStack ~= fn;
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		assert(functionStack.length > 0 && fn is functionStack[$-1]);
		functionStack = functionStack[0 .. $-1];
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		super.enter(bs);
		foreach (i, node; bs.statements) {
			auto ss = cast(ir.ScopeStatement) node;
			if (ss is null) {
				continue;
			}
			if (functionStack.length == 0) {
				throw makeScopeOutsideFunction(ss.location);
			}
			auto fn = scopeStatementToFunction(ss);
			final switch (ss.kind) with (ir.ScopeStatement.Kind) {
			case Exit: functionStack[$-1].scopeExits ~= fn; break;
			case Success: functionStack[$-1].scopeSuccesses ~= fn; break;
			case Failure: functionStack[$-1].scopeFailures ~= fn; break;
			}
			bs.statements[i] = fn;
		}
		return Continue;
	}

	private ir.Function scopeStatementToFunction(ir.ScopeStatement ss)
	{
		assert(functionStack.length > 0);
		auto p = functionStack[$-1];
		auto fn = new ir.Function();
		fn.name = generateName(ss);
		fn.location = ss.location;
		fn.kind = ir.Function.Kind.Function;

		fn.type = new ir.FunctionType();
		fn.type.location = ss.location;
		fn.type.ret = buildVoid(ss.location);

		fn._body = ss.block;

		return fn;
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

