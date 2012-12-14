// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.expreplace;

import std.conv : to;
import std.string : format;

import volt.exceptions;
import volt.visitor.visitor;
import ir = volt.ir.ir;

interface ExpReplaceVisitor
{
public abstract:
	Visitor.Status enter(ref ir.Exp, ir.Postfix);
	Visitor.Status leave(ref ir.Exp, ir.Postfix);
	Visitor.Status enter(ref ir.Exp, ir.Unary);
	Visitor.Status leave(ref ir.Exp, ir.Unary);
	Visitor.Status enter(ref ir.Exp, ir.BinOp);
	Visitor.Status leave(ref ir.Exp, ir.BinOp);
	Visitor.Status enter(ref ir.Exp, ir.Ternary);
	Visitor.Status leave(ref ir.Exp, ir.Ternary);
	Visitor.Status enter(ref ir.Exp, ir.Array);
	Visitor.Status leave(ref ir.Exp, ir.Array);
	Visitor.Status enter(ref ir.Exp, ir.AssocArray);
	Visitor.Status leave(ref ir.Exp, ir.AssocArray);
	Visitor.Status enter(ref ir.Exp, ir.Assert);
	Visitor.Status leave(ref ir.Exp, ir.Assert);
	Visitor.Status enter(ref ir.Exp, ir.StringImport);
	Visitor.Status leave(ref ir.Exp, ir.StringImport);
	Visitor.Status enter(ref ir.Exp, ir.Typeid);
	Visitor.Status leave(ref ir.Exp, ir.Typeid);
	Visitor.Status enter(ref ir.Exp, ir.IsExp);
	Visitor.Status leave(ref ir.Exp, ir.IsExp);
	Visitor.Status enter(ref ir.Exp, ir.FunctionLiteral);
	Visitor.Status leave(ref ir.Exp, ir.FunctionLiteral);

	Visitor.Status visit(ref ir.Exp, ir.Constant);
	Visitor.Status visit(ref ir.Exp, ir.IdentifierExp);
}


Visitor.Status acceptExp(ref ir.Exp exp, ExpReplaceVisitor av)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		return acceptConstant(exp, cast(ir.Constant)exp, av);
	case IdentifierExp:
		return acceptIdentifierExp(exp, cast(ir.IdentifierExp)exp, av);
	case Postfix:
		return acceptPostfix(exp, cast(ir.Postfix)exp, av);
	case Unary:
		return acceptUnary(exp, cast(ir.Unary)exp, av);
	case BinOp:
		return acceptBinOp(exp, cast(ir.BinOp)exp, av);
	case Ternary:
		return acceptTernary(exp, cast(ir.Ternary)exp, av);
	case Array:
		return acceptArray(exp, cast(ir.Array)exp, av);
	case AssocArray:
		return acceptAssocArray(exp, cast(ir.AssocArray)exp, av);
	case Assert:
		return acceptAssert(exp, cast(ir.Assert)exp, av);
	case StringImport:
		return acceptStringImport(exp, cast(ir.StringImport)exp, av);
	case Typeid:
		return acceptTypeid(exp, cast(ir.Typeid)exp, av);
	case IsExp:
		auto asIs = cast(ir.IsExp)exp;
		return acceptIsExp(exp, asIs, av);
	case FunctionLiteral:
		auto asFunctionLiteral = cast(ir.FunctionLiteral)exp;
		return acceptFunctionLiteral(exp, asFunctionLiteral, av);
	default:
		throw CompilerPanic(exp.location, format("unhandled accept node: %s.", to!string(exp.nodeType)));
	}
}

Visitor.Status acceptPostfix(ref ir.Exp exp, ir.Postfix postfix, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, postfix);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(postfix.child, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, postfix);
}

Visitor.Status acceptUnary(ref ir.Exp exp, ir.Unary unary, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, unary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

/*
	if (unary.type !is null) {
		status = accept(unary.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}
*/

	status = acceptExp(unary.value, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, unary);
}

Visitor.Status acceptBinOp(ref ir.Exp exp, ir.BinOp binop, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, binop);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(binop.left, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(binop.right, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, binop);
}

Visitor.Status acceptTernary(ref ir.Exp exp, ir.Ternary ternary, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, ternary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(ternary.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(ternary.ifTrue, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(ternary.ifFalse, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, ternary);
}

Visitor.Status acceptArray(ref ir.Exp exp, ir.Array array, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (ref childExp; array.values) {
		status = acceptExp(childExp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, array);
}

Visitor.Status acceptAssocArray(ref ir.Exp exp, ir.AssocArray array, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (ref pair; array.pairs) {
		status = acceptExp(pair.key, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
		status = acceptExp(pair.value, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, array);
}

Visitor.Status acceptAssert(ref ir.Exp exp, ir.Assert _assert, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, _assert);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(_assert.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	if (_assert.message !is null) {
		status = acceptExp(_assert.message, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, _assert);
}

Visitor.Status acceptStringImport(ref ir.Exp exp, ir.StringImport strimport, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, strimport);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(strimport.filename, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, strimport);
}

Visitor.Status acceptTypeid(ref ir.Exp exp, ir.Typeid ti, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, ti);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (ti.exp !is null) {
		status = acceptExp(ti.exp, av);
	} else {
/*
		status = accept(ti.type, av);
*/
	}
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, ti);
}

Visitor.Status acceptIsExp(ref ir.Exp exp, ir.IsExp isExp, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, isExp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

/*
	status = accept(isExp.type, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	if (isExp.specType !is null) {
		status = accept(isExp.specType, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}
*/

	return av.leave(exp, isExp);
}

Visitor.Status acceptFunctionLiteral(ref ir.Exp exp, ir.FunctionLiteral functionLiteral, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, functionLiteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

/*
	foreach (statement; functionLiteral.block) {
		status = accept(statement, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}
*/

	return av.leave(exp, functionLiteral);
}

Visitor.Status acceptConstant(ref ir.Exp exp, ir.Constant constant, ExpReplaceVisitor av)
{
	return av.visit(exp, constant);
}

Visitor.Status acceptIdentifierExp(ref ir.Exp exp, ir.IdentifierExp identifier, ExpReplaceVisitor av)
{
	return av.visit(exp, identifier);
}
