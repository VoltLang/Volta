/*#D*/
// Copyright 2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module volta.visitor.setExpLocationVisitor;

import visitor = volta.visitor.visitor;
import location = volta.ir.location;
import ir = volta.ir;

/*!
 * Set the `loc` field for expressions.
 *
 * Set `newLocation`, and call `acceptExp` on the expression.
 */
class SetExpLocationVisitor : visitor.NullVisitor
{
public:
	location.Location newLocation;

public override:
	Status enter(ref ir.Exp exp, ir.Postfix postfix)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.Unary unary)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.BinOp binop)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.Ternary ternary)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.ArrayLiteral literal)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.AssocArray aa)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.Assert _assert)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.StringImport simport)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.Typeid tid)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.IsExp iexp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.FunctionLiteral fliteral)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.StructLiteral sliteral)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.UnionLiteral uliteral)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.ClassLiteral cliteral)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.Constant _constant)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.TypeExp texp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.StatementExp sexp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.VaArgExp vexp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.PropertyExp pexp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.BuiltinExp bexp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.AccessExp aexp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.RunExp rexp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status enter(ref ir.Exp exp, ir.ComposableString cstring)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status visit(ref ir.Exp exp, ir.IdentifierExp iexp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status visit(ref ir.Exp exp, ir.TokenExp texp)
	{
		exp.loc = newLocation;
		return Continue;
	}

	Status visit(ref ir.Exp exp, ir.StoreExp storeExp)
	{
		exp.loc = newLocation;
		return Continue;
	}
}

