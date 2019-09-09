/*#D*/
// Copyright 2015-2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Home of @ref ExpReferenceReplacer.
 */
module volt.visitor.nodereplace;

import volta.visitor.visitor;

import volta.util.copy;
import ir = volta.ir;

class ExpReferenceReplacer : NullVisitor
{
public:
	this(ir.Declaration decl, ir.Exp exp)
	in {
		assert(decl !is null);
		assert(exp !is null);
	}
	body {
		this.fromDecl = decl;
		this.toExp = exp;
	}

public:
	ir.Declaration fromDecl;
	ir.Exp toExp;

public:
	override Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		if (eref.decl is fromDecl) {
			exp = copyExp(toExp);
		}
		return Continue;
	}
}
