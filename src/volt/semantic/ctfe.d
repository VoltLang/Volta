module volt.semantic.ctfe;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.semantic.lookup;

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
	default:
		string emsg = format("%s is currently unevaluatable at compile time.", to!string(exp.nodeType));
		throw new CompilerError(exp.location, emsg);
	}
	assert(false);
}

private:

ir.Constant evaluateUnary(LanguagePass lp, ir.Scope current, ir.Unary unary)
{
	assert(unary.op == ir.Unary.Op.Minus);
	auto constant = evaluate(lp, current, unary.value);
	auto prim = cast(ir.PrimitiveType) constant.type;
	assert(prim.type == ir.PrimitiveType.Kind.Int);
	constant._int = constant._int * -1;
	constant._string = "-" ~ constant._string;
	return constant;
}

ir.Constant evaluateBinOp(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	switch (binop.op) with (ir.BinOp.Type) {
	case Add:
		return evaluateBinOpAdd(lp, current, binop);
	default:
		string emsg = format("binary operation %s is currently unevaluatable at compile time.", binop.op);
		throw new CompilerError(binop.location, emsg);
	}
}

ir.Constant evaluateBinOpAdd(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto left = evaluate(lp, current, binop.left);
	auto right = evaluate(lp, current, binop.right);
	return buildConstantInt(binop.location, left._int + right._int);
}
