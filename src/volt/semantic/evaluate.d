// Copyright © 2013-2015, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.evaluate;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.errors;
import volt.exceptions;
import volt.interfaces;
import volt.token.location;

import volt.semantic.lookup;
import volt.semantic.util;
import volt.semantic.classify;

/*
 *
 * CTEE folding functions.
 *
 */

ir.Constant fold(ref ir.Exp exp)
{
	bool needCopy;
	auto constant = fold(exp, needCopy);
	return (needCopy && constant !is null) ? cast(ir.Constant)copyExp(constant) : constant;
}

ir.Constant fold(ref ir.Exp exp, out bool needCopy)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		return cast(ir.Constant)exp;
	case Unary:
		auto unary = cast(ir.Unary)exp;
		return foldUnary(exp, unary);
	case BinOp:
		auto binop = cast(ir.BinOp)exp;
		return foldBinOp(exp, binop);
	case ExpReference:
		auto eref = cast(ir.ExpReference)exp;
		panicAssert(exp, eref !is null);
		if (eref.decl.nodeType != ir.NodeType.EnumDeclaration) {
			return null;
		}
		needCopy = true;
		auto ed = cast(ir.EnumDeclaration)eref.decl;
		return cast(ir.Constant)ed.assign;
	default:
		return null;
	}
}

ir.Constant foldBinOp(ref ir.Exp exp, ir.BinOp binop)
{
	bool copyLeft, copyRight;
	auto cl = fold(binop.left, copyLeft);
	auto cr = fold(binop.right, copyRight);
	if (cl is null || cr is null || !typesEqual(cl.type, cr.type)) {
		return null;
	}
	return foldBinOp(exp, binop.op,
	                 copyLeft ? cast(ir.Constant)copyExp(cl) : cl,
					 copyRight ? cast(ir.Constant)copyExp(cr) : cr);
}

ir.Constant foldUnary(ref ir.Exp exp, ir.Unary unary)
{
	auto c = fold(unary.value);
	if (c is null) {
		return null;
	}
	return foldUnary(exp, unary, c);
}

ir.Constant foldBinOp(ref ir.Exp exp, ir.BinOp.Op op, ir.Constant cl, ir.Constant cr)
{
	switch (op) with (ir.BinOp.Op) {
	case OrOr: return foldBinOpOrOr(cl, cr);
	case AndAnd: return foldBinOpAndAnd(cl, cr);
	case Or: return foldBinOpOr(cl, cr);
	case Xor: return foldBinOpXor(cl, cr);
	case And: return foldBinOpAnd(cl, cr);
	case Equal: return foldBinOpEqual(cl, cr);
	case NotEqual: return foldBinOpNotEqual(cl, cr);
	case Less: return foldBinOpLess(cl, cr);
	case LessEqual: return foldBinOpLessEqual(cl, cr);
	case GreaterEqual: return foldBinOpGreaterEqual(cl, cr);
	case Greater: return foldBinOpGreater(cl, cr);
	case LS: return foldBinOpLS(cl, cr);
	case SRS: return foldBinOpSRS(cl, cr);
	case RS: return foldBinOpRS(cl, cr);
	case Add: return foldBinOpAdd(cl, cr);
	case Sub: return foldBinOpSub(cl, cr);
	case Mul: return foldBinOpMul(cl, cr);
	case Div: return foldBinOpDiv(cl, cr);
	case Mod: return foldBinOpMod(cl, cr);
	case Pow: return foldBinOpPow(cl, cr);
	default: return null;
	}
}

ir.Constant foldUnary(ref ir.Exp exp, ir.Unary u, ir.Constant c)
{
	switch (u.op) with (ir.Unary.Op) {
	case Minus: return foldUnaryMinus(c);
	case Plus: return foldUnaryPlus(c);
	case Not: return foldUnaryNot(c);
	case Complement: return foldUnaryComplement(c);
	case Cast: return foldUnaryCast(c, u.type);
	default: return null;
	}
}

private ir.Constant buildEmptyConstant(ir.Node n, ir.Type t)
{
	auto c = new ir.Constant();
	c.location = n.location;
	c.type = t;
	return c;
}

ir.Constant foldBinOpOrOr(ir.Constant cl, ir.Constant cr)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.location));
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = cl.u._bool || cr.u._bool; break;
	case Int: c.u._bool = cl.u._int || cr.u._int; break;
	case Uint: c.u._bool = cl.u._uint || cr.u._uint; break;
	case Long: c.u._bool = cl.u._long || cr.u._long; break;
	case Ulong: c.u._bool = cl.u._ulong || cr.u._ulong; break;
	case Float: c.u._bool = cl.u._float || cr.u._float; break;
	case Double: c.u._bool = cl.u._double || cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpAndAnd(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = cl.u._bool && cr.u._bool; break;
	case Int: c.u._bool = cl.u._int && cr.u._int; break;
	case Uint: c.u._bool = cl.u._uint && cr.u._uint; break;
	case Long: c.u._bool = cl.u._long && cr.u._long; break;
	case Ulong: c.u._bool = cl.u._ulong && cr.u._ulong; break;
	case Float: c.u._bool = cl.u._float && cr.u._float; break;
	case Double: c.u._bool = cl.u._double && cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpOr(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int | cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint | cr.u._uint; break;
	case Long: c.u._long = cl.u._long | cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong | cr.u._ulong; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpXor(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int ^ cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint ^ cr.u._uint; break;
	case Long: c.u._long = cl.u._long ^ cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong ^ cr.u._ulong; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpAnd(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int & cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint & cr.u._uint; break;
	case Long: c.u._long = cl.u._long & cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong & cr.u._ulong; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpEqual(ir.Constant cl, ir.Constant cr)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.location));
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = cl.u._bool == cr.u._bool; break;
	case Int: c.u._bool = cl.u._int == cr.u._int; break;
	case Uint: c.u._bool = cl.u._uint == cr.u._uint; break;
	case Long: c.u._bool = cl.u._long == cr.u._long; break;
	case Ulong: c.u._bool = cl.u._ulong == cr.u._ulong; break;
	case Float: c.u._bool = cl.u._float == cr.u._float; break;
	case Double: c.u._bool = cl.u._double == cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpNotEqual(ir.Constant cl, ir.Constant cr)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.location));
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = cl.u._bool != cr.u._bool; break;
	case Int: c.u._bool = cl.u._int != cr.u._int; break;
	case Uint: c.u._bool = cl.u._uint != cr.u._uint; break;
	case Long: c.u._bool = cl.u._long != cr.u._long; break;
	case Ulong: c.u._bool = cl.u._ulong != cr.u._ulong; break;
	case Float: c.u._bool = cl.u._float != cr.u._float; break;
	case Double: c.u._bool = cl.u._double != cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpLess(ir.Constant cl, ir.Constant cr)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.location));
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = cl.u._bool < cr.u._bool; break;
	case Int: c.u._bool = cl.u._int < cr.u._int; break;
	case Uint: c.u._bool = cl.u._uint < cr.u._uint; break;
	case Long: c.u._bool = cl.u._long < cr.u._long; break;
	case Ulong: c.u._bool = cl.u._ulong < cr.u._ulong; break;
	case Float: c.u._bool = cl.u._float < cr.u._float; break;
	case Double: c.u._bool = cl.u._double < cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpLessEqual(ir.Constant cl, ir.Constant cr)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.location));
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = cl.u._bool <= cr.u._bool; break;
	case Int: c.u._bool = cl.u._int <= cr.u._int; break;
	case Uint: c.u._bool = cl.u._uint <= cr.u._uint; break;
	case Long: c.u._bool = cl.u._long <= cr.u._long; break;
	case Ulong: c.u._bool = cl.u._ulong <= cr.u._ulong; break;
	case Float: c.u._bool = cl.u._float <= cr.u._float; break;
	case Double: c.u._bool = cl.u._double <= cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpGreaterEqual(ir.Constant cl, ir.Constant cr)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.location));
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = cl.u._bool >= cr.u._bool; break;
	case Int: c.u._bool = cl.u._int >= cr.u._int; break;
	case Uint: c.u._bool = cl.u._uint >= cr.u._uint; break;
	case Long: c.u._bool = cl.u._long >= cr.u._long; break;
	case Ulong: c.u._bool = cl.u._ulong >= cr.u._ulong; break;
	case Float: c.u._bool = cl.u._float >= cr.u._float; break;
	case Double: c.u._bool = cl.u._double >= cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpGreater(ir.Constant cl, ir.Constant cr)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.location));
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = cl.u._bool > cr.u._bool; break;
	case Int: c.u._bool = cl.u._int > cr.u._int; break;
	case Uint: c.u._bool = cl.u._uint > cr.u._uint; break;
	case Long: c.u._bool = cl.u._long > cr.u._long; break;
	case Ulong: c.u._bool = cl.u._ulong > cr.u._ulong; break;
	case Float: c.u._bool = cl.u._float > cr.u._float; break;
	case Double: c.u._bool = cl.u._double > cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpLS(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int << cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint << cr.u._uint; break;
	case Long: c.u._long = cl.u._long << cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong << cr.u._ulong; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpSRS(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int >> cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint >> cr.u._uint; break;
	case Long: c.u._long = cl.u._long >> cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong >> cr.u._ulong; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpRS(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int >>> cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint >>> cr.u._uint; break;
	case Long: c.u._long = cl.u._long >>> cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong >>> cr.u._ulong; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpAdd(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int + cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint + cr.u._uint; break;
	case Long: c.u._long = cl.u._long + cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong + cr.u._ulong; break;
	case Float: c.u._float = cl.u._float + cr.u._float; break;
	case Double: c.u._double = cl.u._double + cr.u._double; break;
	case Char, Wchar, Dchar: return null;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpSub(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int - cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint - cr.u._uint; break;
	case Long: c.u._long = cl.u._long - cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong - cr.u._ulong; break;
	case Float: c.u._float = cl.u._float - cr.u._float; break;
	case Double: c.u._double = cl.u._double - cr.u._double; break;
	case Char, Wchar, Dchar: return null;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpMul(ir.Constant cl, ir.Constant cr)
{
	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = cl.u._int * cr.u._int; break;
	case Uint: c.u._uint = cl.u._uint * cr.u._uint; break;
	case Long: c.u._long = cl.u._long * cr.u._long; break;
	case Ulong: c.u._ulong = cl.u._ulong * cr.u._ulong; break;
	case Float: c.u._float = cl.u._float * cr.u._float; break;
	case Double: c.u._double = cl.u._double * cr.u._double; break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpDiv(ir.Constant cl, ir.Constant cr)
{
	void dieIfZero(bool isZero)
	{
		if (isZero) {
			throw makeError(cl.location, "divide by zero.");
		}
	}

	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: dieIfZero(cr.u._int == 0); c.u._int = cl.u._int / cr.u._int; break;
	case Uint: dieIfZero(cr.u._uint == 0); c.u._uint = cl.u._uint / cr.u._uint; break;
	case Long: dieIfZero(cr.u._long == 0); c.u._long = cl.u._long / cr.u._long; break;
	case Ulong:
		dieIfZero(cr.u._ulong == 0); c.u._ulong = cl.u._ulong / cr.u._ulong;
		break;
	case Float:
		dieIfZero(cr.u._float == 0); c.u._float = cl.u._float / cr.u._float;
		break;
	case Double:
		dieIfZero(cr.u._double == 0); c.u._double = cl.u._double / cr.u._double;
		break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpMod(ir.Constant cl, ir.Constant cr)
{
	void dieIfZero(bool isZero)
	{
		if (isZero) {
			throw makeError(cl.location, "divide by zero.");
		}
	}

	auto c = cl;
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Uint: dieIfZero(cr.u._uint == 0); c.u._uint = cl.u._uint % cr.u._uint; break;
	case Long: dieIfZero(cr.u._long == 0); c.u._long = cl.u._long % cr.u._long; break;
	case Ulong:
		dieIfZero(cr.u._ulong == 0); c.u._ulong = cl.u._ulong % cr.u._ulong;
		break;
	case Float:
		dieIfZero(cr.u._float == 0); c.u._float = cl.u._float % cr.u._float;
		break;
	case Double:
		dieIfZero(cr.u._double == 0); c.u._double = cl.u._double % cr.u._double;
		break;
	default: panicAssert(cl, false); break;
	}
	return c;
}

ir.Constant foldBinOpPow(ir.Constant cl, ir.Constant cr)
{
	version (Volt) {
		throw panicUnhandled(cl, "pow binop");
	} else {
		auto c = cl;
		auto pt = cast(ir.PrimitiveType)c.type;
		switch (pt.type) with (ir.PrimitiveType.Kind) {
		case Int: c.u._int = cl.u._int ^^ cr.u._int; break;
		case Uint: c.u._uint = cl.u._uint ^^ cr.u._uint; break;
		case Long: c.u._long = cl.u._long ^^ cr.u._long; break;
		case Ulong: c.u._ulong = cl.u._ulong ^^ cr.u._ulong; break;
		case Float: c.u._float = cl.u._float ^^ cr.u._float; break;
		case Double: c.u._double = cl.u._double ^^ cr.u._double; break;
		default: panicAssert(cl, false); break;
		}
		return c;
	}
}

ir.Constant foldUnaryCast(ir.Constant c, ir.Type t)
{
	auto fromPrim = cast(ir.PrimitiveType)c.type;
	auto toPrim = cast(ir.PrimitiveType)realType(t);
	if (fromPrim is null || toPrim is null) {
		return null;
	}
	bool signed;
	long signedFrom;
	ulong unsignedFrom;
	switch (fromPrim.type) with (ir.PrimitiveType.Kind) {
	case Int:
		signedFrom = c.u._int;
		signed = true;
		break;
	case Long:
		signedFrom = c.u._long;
		signed = true;
		break;
	case Uint:
		unsignedFrom = c.u._uint;
		break;
	case Ulong:
		unsignedFrom = c.u._ulong;
		break;
	default: return null;
	}
	auto loc = c.location;
	switch (toPrim.type) with (ir.PrimitiveType.Kind) {
	case Int:
		return buildConstantInt(loc, signed ? cast(int)signedFrom : cast(int)unsignedFrom);
	case Uint:
		return buildConstantUint(loc, signed ? cast(uint)signedFrom : cast(uint)unsignedFrom);
	case Long:
		return buildConstantLong(loc, signed ? cast(long)signedFrom : cast(long)unsignedFrom);
	case Ulong:
		return buildConstantUlong(loc, signed ? cast(ulong)signedFrom : cast(ulong)unsignedFrom);
	default:
		return null;
	}
	assert(false);
}

ir.Constant foldUnaryMinus(ir.Constant c)
{
	auto pt = cast(ir.PrimitiveType) c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int:
		c.u._int = -c.u._int;
		break;
	case Uint:
		// Yes, this is 2's complement.
		c.u._uint = -c.u._uint;
		break;
	case Long:
		c.u._long = -c.u._long;
		break;
	case Ulong:
		// Yes, this is 2's complement.
		c.u._ulong = -c.u._ulong;
		break;
	default:
		panicAssert(c, false);
		break;
	}
	return c;
}

ir.Constant foldUnaryPlus(ir.Constant c)
{
	auto pt = cast(ir.PrimitiveType) c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int:
		c.u._int = +c.u._int;
		break;
	case Uint:
		c.u._uint = +c.u._uint;
		break;
	case Long:
		c.u._long = +c.u._long;
		break;
	case Ulong:
		c.u._ulong = +c.u._ulong;
		break;
	default:
		panicAssert(c, false);
		break;
	}
	return c;
}

ir.Constant foldUnaryNot(ir.Constant c)
{
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: c.u._bool = !c.u._bool; break;
	default:
		panicAssert(c, false);
		break;
	}
	return c;
}

ir.Constant foldUnaryComplement(ir.Constant c)
{
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: c.u._int = ~c.u._int; break;
	case Uint: c.u._uint = ~c.u._uint; break;
	case Long: c.u._long = ~c.u._long; break;
	case Ulong: c.u._ulong = ~c.u._ulong; break;
	default:
		panicAssert(c, false);
		break;
	}
	return c;
}

ir.Constant evaluateOrNull(LanguagePass lp, ir.Scope current, ir.Exp exp)
{
	if (exp is null) {
		return null;
	}
	return fold(exp);
}

ir.Constant evaluate(LanguagePass lp, ir.Scope current, ir.Exp exp)
{
	auto constant = fold(exp);
	if (constant is null) {
		throw makeNotAvailableInCTFE(exp, exp);
	}
	return constant;
}

bool needsEvaluation(ir.Exp exp)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		return false;
	case ArrayLiteral:
		auto ar = cast(ir.ArrayLiteral) exp;
		foreach (value; ar.exps) {
			if (needsEvaluation(value))
				return true;
		}
		return false;
	default:
		return true;
	}
}

