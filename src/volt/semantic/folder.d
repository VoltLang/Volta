/*#D*/
// Copyright © 2016-2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.folder;

import volt.semantic.evaluate : foldBinOp, foldUnary;

import volt.interfaces : Pass, TargetInfo;
import volt.visitor.visitor : accept, NullVisitor;
import ir = volt.ir.ir;


/*!
 * Folds any expressions into Constants.
 *
 * @ingroup passes passLang passSem
 */
class ExpFolder : NullVisitor, Pass
{
public:
	TargetInfo target;

public:
	this(TargetInfo target)
	{
		this.target = target;
	}

public:
	override void transform(ir.Module mod)
	{
		accept(mod, this);
	}

	override void close()
	{
	}

	override Status enter(ref ir.Exp exp, ir.BinOp binop)
	{
		auto constant = foldBinOp(/*#ref*/exp, binop, target);
		return ContinueParent;
	}

	override Status enter(ref ir.Exp exp, ir.Unary unary)
	{
		auto constant = foldUnary(/*#ref*/exp, unary, target);
		return ContinueParent;
	}
}
