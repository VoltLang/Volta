module volt.semantic.ctfe;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.exceptions;
import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.semantic.lookup;

ir.Constant evaluateOrNull(LanguagePass lp, ir.Scope current, ir.Exp exp)
{
	try {
		return evaluate(lp, current, exp);
	} catch (CompilerError e) {
		return null;
	}
}

ir.Constant evaluate(LanguagePass lp, ir.Scope current, ir.Exp exp)
{
	switch (exp.nodeType) {
	case ir.NodeType.BinOp:
		auto binop = cast(ir.BinOp) exp;
		return evaluateBinOp(lp, current, binop);
	case ir.NodeType.Constant:
		auto constant = cast(ir.Constant) exp;
		return copy(constant);
	case ir.NodeType.Unary:
		auto unary = cast(ir.Unary) exp;
		return evaluateUnary(lp, current, unary);
	case ir.NodeType.Postfix:
		auto pfix = cast(ir.Postfix) exp;
		return evaluatePostfix(lp, current, pfix);
	default:
		throw makeNotAvailableInCTFE(exp, exp);
	}
	assert(false);
}

bool needsEvaluation(ir.Exp exp)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		return false;
	case ArrayLiteral:
		auto ar = cast(ir.ArrayLiteral) exp;
		foreach (value; ar.values) {
			if (needsEvaluation(value))
				return true;
		}
		return false;
	default:
		return true;
	}
}

private:

ir.Constant evaluatePostfix(LanguagePass lp, ir.Scope current, ir.Postfix pfix)
{
	auto iexp = cast(ir.IdentifierExp) pfix.child;
	if (iexp is null) {
		throw makeNotAvailableInCTFE(pfix, pfix);
	}
	if (pfix.identifier is null) {
		throw makeNotAvailableInCTFE(pfix, pfix);
	}
	auto store = lookup(lp, current, pfix.location, iexp.value);
	if (store is null) {
		throw makeNotAvailableInCTFE(pfix, pfix);
	}
	auto _enum = cast(ir.Enum) store.node;
	if (_enum is null) {
		throw makeNotAvailableInCTFE(pfix, pfix);
	}
	auto finalStore = lookup(lp, _enum.myScope, pfix.location, pfix.identifier.value); 
	if (finalStore is null) {
		throw makeNotAvailableInCTFE(pfix, pfix);
	}
	auto edecl = cast(ir.EnumDeclaration) finalStore.node;
	if (edecl is null) {
		throw makeNotAvailableInCTFE(pfix, pfix);
	}
	auto constant = cast(ir.Constant) edecl.assign;
	if (constant is null) {
		throw makeNotAvailableInCTFE(pfix, pfix);
	}
	return constant;
}

ir.Constant evaluateUnary(LanguagePass lp, ir.Scope current, ir.Unary unary)
{
	switch (unary.op) with (ir.Unary.Op) {
	case Minus:
		return evaluateUnaryMinus(lp, current, unary);
	case Not:
		return evaluateUnaryNot(lp, current, unary);
	default:
		throw makeNotAvailableInCTFE(unary, unary);
	}
}

ir.Constant evaluateUnaryNot(LanguagePass lp, ir.Scope current, ir.Unary unary)
{
	auto constant = evaluate(lp, current, unary.value);
	return buildConstantBool(unary.location, !constant._bool);
}

ir.Constant evaluateUnaryMinus(LanguagePass lp, ir.Scope current, ir.Unary unary)
{
	auto constant = evaluate(lp, current, unary.value);
	auto prim = cast(ir.PrimitiveType) constant.type;
	assert(prim.type == ir.PrimitiveType.Kind.Int);
	constant._int = constant._int * -1;
	constant._string = "-" ~ constant._string;
	return constant;
}

ir.Constant evaluateBinOp(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	switch (binop.op) with (ir.BinOp.Op) {
	case Add:
		return evaluateBinOpAdd(lp, current, binop);
	case Equal:
		return evaluateBinOpEqual(lp, current, binop);
	case And:
		return evaluateBinOpAnd(lp, current, binop);
	case Or:
		return evaluateBinOpOr(lp, current, binop);
	case LS:
		return evaluateBinOpLS(lp, current, binop);
	case RS:
		return evaluateBinOpRS(lp, current, binop);
	case AndAnd:
		return evaluateBinOpAndAnd(lp, current, binop);
	case OrOr:
		return evaluateBinOpOrOr(lp, current, binop);
	case GreaterEqual:
		return evaluateBinOpGreaterEqual(lp, current, binop);
	default:
		throw makeNotAvailableInCTFE(binop, binop);
	}
}

ir.Constant evaluateBinOpAdd(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantInt(binop.location, left._int + right._int);
}

ir.Constant evaluateBinOpAnd(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantInt(binop.location, left._int & right._int);
}

ir.Constant evaluateBinOpOr(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantInt(binop.location, left._int | right._int);
}

ir.Constant evaluateBinOpLS(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantInt(binop.location, left._int << right._int);
}

ir.Constant evaluateBinOpRS(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantInt(binop.location, left._int >> right._int);
}

ir.Constant evaluateBinOpEqual(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantBool(binop.location, left._int == right._int);
}

ir.Constant evaluateBinOpGreaterEqual(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantBool(binop.location, left._int >= right._int);
}

ir.Constant evaluateBinOpAndAnd(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantBool(binop.location, left._bool && right._bool);
}

ir.Constant evaluateBinOpOrOr(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantBool(binop.location, left._bool || right._bool);
}

