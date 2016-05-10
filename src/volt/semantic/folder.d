// Copyright © 2016, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.folder;

import volt.semantic.evaluate : foldBinOp, foldUnary;

import volt.interfaces : Pass;
import volt.visitor.visitor : accept, NullVisitor;
import ir = volt.ir.ir;


class ExpFolder : NullVisitor, Pass
{
	override void transform(ir.Module mod)
	{
		accept(mod, this);
	}

	override void close()
	{
	}

	override Status enter(ref ir.Exp exp, ir.BinOp binop)
	{
		auto constant = foldBinOp(exp, binop);
		return ContinueParent;
	}

	override Status enter(ref ir.Exp exp, ir.Unary unary)
	{
		auto constant = foldUnary(exp, unary);
		return ContinueParent;
	}
}
