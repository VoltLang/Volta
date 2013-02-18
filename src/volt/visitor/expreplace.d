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
	Visitor.Status enter(ref ir.Exp, ir.ArrayLiteral);
	Visitor.Status leave(ref ir.Exp, ir.ArrayLiteral);
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
	Visitor.Status enter(ref ir.Exp, ir.StructLiteral);
	Visitor.Status leave(ref ir.Exp, ir.StructLiteral);
	Visitor.Status enter(ref ir.Exp, ir.ClassLiteral);
	Visitor.Status leave(ref ir.Exp, ir.ClassLiteral);

	Visitor.Status visit(ref ir.Exp, ir.Constant);
	Visitor.Status visit(ref ir.Exp, ir.IdentifierExp);
	Visitor.Status visit(ref ir.Exp, ir.ExpReference);
}

/**
 * A Visitor and an ExpReplaceVisitor that visits 
 * Expressions in their various hidey holes suitable
 * for replacing with the ExpReplaceVisitor methods.
 */
class NullExpReplaceVisitor : NullVisitor, ExpReplaceVisitor
{
public:
	override Visitor.Status enter(ir.ExpStatement expStatement)
	{
		acceptExp(expStatement.exp, this);
		return Continue;
	}

	override Visitor.Status enter(ir.Variable variable)
	{
		if (variable.assign !is null) {
			acceptExp(variable.assign, this);
		}
		return Continue;
	}

	override Visitor.Status enter(ir.ReturnStatement returnStatement)
	{
		if (returnStatement.exp !is null) {
			acceptExp(returnStatement.exp, this);
		}
		return Continue;
	}

	override Visitor.Status enter(ir.IfStatement ifStatement)
	{
		acceptExp(ifStatement.exp, this);
		return Continue;
	}

	override Visitor.Status enter(ir.WhileStatement whileStatement)
	{
		acceptExp(whileStatement.condition, this);
		return Continue;
	}

	override Visitor.Status enter(ir.DoStatement doStatement)
	{
		acceptExp(doStatement.condition, this);
		return Continue;
	}

	override Visitor.Status enter(ir.ForStatement forStatement)
	{
		foreach (ref initExp; forStatement.initExps) {
			acceptExp(initExp, this);
		}

		if (forStatement.test !is null) {
			acceptExp(forStatement.test, this);
		}

		foreach (ref increment; forStatement.increments) {
			acceptExp(increment, this);
		}
		return Continue;
	}

	override Visitor.Status enter(ir.SwitchStatement switchStatement)
	{
		acceptExp(switchStatement.condition, this);
		foreach (switchCase; switchStatement.cases) {
			if (switchCase.firstExp !is null) acceptExp(switchCase.firstExp, this);
			if (switchCase.secondExp !is null) acceptExp(switchCase.secondExp, this);
			foreach (ref exp; switchCase.exps) {
				acceptExp(exp, this);
			}
		}
		return Continue;
	}

	override Visitor.Status enter(ir.GotoStatement gotoStatement)
	{
		if (gotoStatement.exp !is null) {
			acceptExp(gotoStatement.exp, this);
		}
		return Continue;
	}

	override Visitor.Status enter(ir.WithStatement withStatement)
	{
		acceptExp(withStatement.exp, this);
		return Continue;
	}

	override Visitor.Status enter(ir.SynchronizedStatement syncStatement)
	{
		if (syncStatement.exp !is null) {
			acceptExp(syncStatement.exp, this);
		}
		return Continue;
	}

	override Visitor.Status enter(ir.ThrowStatement throwStatement)
	{
		acceptExp(throwStatement.exp, this);
		return Continue;
	}

	override Visitor.Status enter(ir.PragmaStatement pragmaStatement)
	{
		foreach (ref arg; pragmaStatement.arguments) {
			acceptExp(arg, this);
		}
		return Continue;
	}

	override Visitor.Status enter(ref ir.Exp, ir.Postfix) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.Postfix) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.Unary) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.Unary) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.BinOp) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.BinOp) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.Ternary) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.Ternary) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.ArrayLiteral) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.ArrayLiteral) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.AssocArray) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.AssocArray) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.Assert) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.Assert) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.StringImport) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.StringImport) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.Typeid) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.Typeid) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.IsExp) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.IsExp) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.FunctionLiteral) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.FunctionLiteral) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.StructLiteral) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.StructLiteral) { return Continue; }
	override Visitor.Status enter(ref ir.Exp, ir.ClassLiteral) { return Continue; }
	override Visitor.Status leave(ref ir.Exp, ir.ClassLiteral) { return Continue; }

	override Visitor.Status visit(ref ir.Exp, ir.Constant) { return Continue; }
	override Visitor.Status visit(ref ir.Exp, ir.IdentifierExp) { return Continue; }
	override Visitor.Status visit(ref ir.Exp, ir.ExpReference) { return Continue; }
}

/**
 * The same as NullExpReplaceVisitor but also tracks scopes.
 */
class ScopeExpReplaceVisitor : NullExpReplaceVisitor
{
public:
	ir.Scope current;

public:
	override Visitor.Status enter(ir.Module m)
	{
		assert(current is null);
		current = m.myScope;
		return Continue;
	}

	override Visitor.Status leave(ir.Module m)
	{
		assert(current == m.myScope);

		current = null;
		return Continue;
	}

	override Visitor.Status enter(ir.Struct s)
	{
		current = s.myScope;
		return Continue;
	}

	override Visitor.Status leave(ir.Struct s)
	{
		assert(current == s.myScope);

		current = current.parent;
		return Continue;
	}

	override Visitor.Status enter(ir.Class c)
	{
		current = c.myScope;
		return Continue;
	}

	override Visitor.Status leave(ir.Class c)
	{
		assert(current == c.myScope);

		current = current.parent;
		return Continue;
	}

	override Visitor.Status enter(ir._Interface i)
	{
		current = i.myScope;
		return Continue;
	}

	override Visitor.Status leave(ir._Interface i)
	{
		assert(current == i.myScope);

		current = current.parent;
		return Continue;
	}

	override Visitor.Status enter(ir.Function fn)
	{
		current = fn.myScope;
		return Continue;
	}

	override Visitor.Status leave(ir.Function fn)
	{
		assert(current == fn.myScope);

		current = current.parent;
		return Continue;
	}

	override Visitor.Status enter(ir.UserAttribute ua)
	{
		current = ua.myScope;
		return Continue;
	}

	override Visitor.Status leave(ir.UserAttribute ua)
	{
		assert(current == ua.myScope);

		current = current.parent;
		return Continue;
	}
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
	case ArrayLiteral:
		return acceptArrayLiteral(exp, cast(ir.ArrayLiteral)exp, av);
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
	case ExpReference:
		auto asExpRef = cast(ir.ExpReference) exp;
		assert(asExpRef !is null);
		return acceptExpReference(exp, asExpRef, av);
	case StructLiteral:
		auto asStructLiteral = cast(ir.StructLiteral) exp;
		assert(asStructLiteral !is null);
		return acceptStructLiteral(exp, asStructLiteral, av);
	case ClassLiteral:
		auto asClassLiteral = cast(ir.ClassLiteral) exp;
		assert(asClassLiteral !is null);
		return acceptClassLiteral(exp, asClassLiteral, av);
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

	// If exp has been replaced
	if (exp !is postfix) {
		return acceptExp(exp, av);
	}

	status = acceptExp(postfix.child, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	foreach (ref arg; postfix.arguments) {
		status = acceptExp(arg, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, postfix);
}

Visitor.Status acceptUnary(ref ir.Exp exp, ir.Unary unary, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, unary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is unary) {
		return acceptExp(exp, av);
	}

	if (unary.value !is null) {
		status = acceptExp(unary.value, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (ref arg; unary.argumentList) {
		status = acceptExp(arg, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, unary);
}

Visitor.Status acceptBinOp(ref ir.Exp exp, ir.BinOp binop, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, binop);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is binop) {
		return acceptExp(exp, av);
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

	// If exp has been replaced
	if (exp !is ternary) {
		return acceptExp(exp, av);
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

Visitor.Status acceptArrayLiteral(ref ir.Exp exp, ir.ArrayLiteral array, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is array) {
		return acceptExp(exp, av);
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

	// If exp has been replaced
	if (exp !is array) {
		return acceptExp(exp, av);
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

	// If exp has been replaced
	if (exp !is _assert) {
		return acceptExp(exp, av);
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

	// If exp has been replaced
	if (exp !is strimport) {
		return acceptExp(exp, av);
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

	// If exp has been replaced
	if (exp !is ti) {
		return acceptExp(exp, av);
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

	// If exp has been replaced
	if (exp !is isExp) {
		return acceptExp(exp, av);
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

	// If exp has been replaced
	if (exp !is functionLiteral) {
		return acceptExp(exp, av);
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

Visitor.Status acceptStructLiteral(ref ir.Exp exp, ir.StructLiteral sliteral, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, sliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is sliteral) {
		return acceptExp(exp, av);
	}

	foreach (ref sexp; sliteral.exps) {
		status = acceptExp(sexp, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, sliteral);
}

Visitor.Status acceptClassLiteral(ref ir.Exp exp, ir.ClassLiteral cliteral, ExpReplaceVisitor av)
{
	auto status = av.enter(exp, cliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is cliteral) {
		return acceptExp(exp, av);
	}

	foreach (ref sexp; cliteral.exps) {
		status = acceptExp(sexp, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, cliteral);
}

Visitor.Status acceptExpReference(ref ir.Exp exp, ir.ExpReference expref, ExpReplaceVisitor av)
{
	return av.visit(exp, expref);
}

Visitor.Status acceptConstant(ref ir.Exp exp, ir.Constant constant, ExpReplaceVisitor av)
{
	return av.visit(exp, constant);
}

Visitor.Status acceptIdentifierExp(ref ir.Exp exp, ir.IdentifierExp identifier, ExpReplaceVisitor av)
{
	return av.visit(exp, identifier);
}
