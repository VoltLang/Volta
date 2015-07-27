// Copyright © 2015, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.scopereplacer;

import watt.text.format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

class ScopeReplacer : ScopeManager
{
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
		fn.myScope = new ir.Scope(current, fn, fn.name);

		fn.type = new ir.FunctionType();
		fn.type.location = ss.location;
		fn.type.ret = copyTypeSmart(ss.location, p.type.ret);

		// Not copying only works because we replace the SS entirely.
		fn._body = ss.block;
		fn._body.myScope.parent = fn.myScope;

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

