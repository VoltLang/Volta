// Copyright © 2014, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.strace;

import volt.ir.util;
import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;

/**
 * A pass that inserts code to print the function name as the first
 * statement in every function.
 *
 * @ingroup passes passLang
 */
class SimpleTrace : NullVisitor, Pass
{
public:
	LanguagePass lp;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	override void transform(ir.Module m)
	{
		if (!lp.settings.simpleTrace) {
			return;
		}
		accept(m, this);
	}

	override void close()
	{
	}

	/**
	 * Visitor functions.
	 */
	override Status enter(ir.Function fn)
	{
		if (fn._body is null) {
			return Continue;
		}
		// Build vrt_print(__FUNCTION__).
		auto l = fn.location;
		auto eref = buildExpReference(l, lp.printFunc, "vrt_print");
		auto call = buildCall(l, eref, [cast(ir.Exp) buildTokenExp(l, ir.TokenExp.Type.Function)]);
		auto estat = buildExpStat(l, call);
		// Add the print to the top of the function.
		fn._body.statements = estat ~ fn._body.statements;
		return Continue;
	}
}
