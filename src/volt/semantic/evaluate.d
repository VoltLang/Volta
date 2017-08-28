// Copyright © 2013-2017, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.evaluate;

import watt.io.std;
import watt.conv : toString;
import watt.text.format : format;
import watt.text.sink;

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
import volt.semantic.typer;

/*
 *
 * CTEE folding functions.
 *
 */

ir.Constant fold(ref ir.Exp exp, TargetInfo target)
{
	bool needCopy;
	auto constant = fold(exp, needCopy, target);
	return (needCopy && constant !is null) ? cast(ir.Constant)copyExp(constant) : constant;
}

/*! Given two expressions, returns true if they are two constant array literals that are equal.
 */
bool areEqualConstantArrays(ir.Exp l, ir.Exp r, TargetInfo target)
{
	auto ltype = realType(getExpType(l));
	auto rtype = realType(getExpType(r));
	if (!typesEqual(ltype, rtype) || ltype.nodeType != ir.NodeType.ArrayType) {
		return false;
	}
	auto lliteral = cast(ir.ArrayLiteral)l;
	auto rliteral = cast(ir.ArrayLiteral)r;
	if (lliteral is null || rliteral is null || lliteral.exps.length != rliteral.exps.length) {
		return false;
	}

	for (size_t i = 0; i < lliteral.exps.length; ++i) {
		auto lelement = lliteral.exps[i];
		auto relement = rliteral.exps[i];
		auto letype = realType(getExpType(lelement));
		auto retype = realType(getExpType(relement));
		if (!typesEqual(letype, retype)) {
			return false;
		}
		if (letype.nodeType == ir.NodeType.ArrayType) {
			if (!areEqualConstantArrays(lelement, relement, target)) {
				return false;
			}
		} else {
			auto lc = fold(lelement, target);
			auto rc = fold(relement, target);
			if (lc is null || rc is null || !typesEqual(lc.type, rc.type)) {
				return false;
			}
			auto equalc = foldBinOpEqual(lc, rc, target);
			if (equalc is null || !equalc.u._bool) {
				return false;
			}
		}
	}

	return true;
}

ir.Constant fold(ref ir.Exp exp, out bool needCopy, TargetInfo target)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		auto c = cast(ir.Constant)exp;
		exp = c;
		return c;
	case Unary:
		auto unary = cast(ir.Unary)exp;
		auto c = foldUnary(exp, unary, target);
		if (c !is null) {
			exp = c;
		}
		return c;
	case BinOp:
		auto binop = cast(ir.BinOp)exp;
		auto c = foldBinOp(exp, binop, target);
		if (c !is null) {
			exp = c;
		}
		return c;
	case ExpReference:
		bool wasEnum;
		auto e = stripEnumIfEnum(exp, wasEnum);
		if (wasEnum) {
			needCopy = true;
			return fold(e, target);
		}
		return null;
	case AccessExp:
		auto c = foldAccessExp(exp, cast(ir.AccessExp)exp, target);
		if (c !is null) {
			exp = c;
		}
		return c;
	case Ternary:
		auto c = foldTernary(exp, cast(ir.Ternary)exp, target);
		if (c !is null) {
			exp = c;
		}
		return c;
	case ComposableString:
		auto cs = exp.toComposableStringFast();
		if (!cs.compileTimeOnly) {
			return null;
		}
		auto c = buildConstantString(exp.loc, getConstantComposableString(target, cs));
		exp = c;
		return c;
	default:
		return null;
	}
}

//! Fold a composable string.
string getConstantComposableString(TargetInfo target, ir.ComposableString cs)
{
	assert(cs.compileTimeOnly);
	StringSink ss;
	foreach (e; cs.components) {
		addConstantComposableStringComponent(target, ss.sink, e);
	}
	return ss.toString();
}

//! Add a components value to a composable string being folded.
void addConstantComposableStringComponent(TargetInfo target, Sink sink, ir.Exp e)
{
	auto c = fold(e, target); 
	if (c is null) {
		assert(false);
	}
	addConstantComposableStringComponent(sink, c);
}

//! Add a string component to an in progress composable string parse.
void addConstantComposableStringComponent(Sink sink, ir.Constant c)
{
	if (isString(c.type)) {
		sink(cast(string)c.arrayData);
		return;
	}
	switch (c.type.nodeType) {
	case ir.NodeType.PrimitiveType:
		auto pt = c.type.toPrimitiveTypeFast();
		addConstantComposableStringComponent(sink, c, pt);
		break;
	default:
		assert(false);
	}
}

//! Add a primitive type component to a composable string.
void addConstantComposableStringComponent(Sink sink, ir.Constant c, ir.PrimitiveType pt)
{
	final switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool:
		sink(c.u._bool ? "true" : "false");
		break;
	case Char:
	case Wchar:
	case Dchar:
		sink(c._string);
		break;
	case Ubyte:
		sink(toString(c.u._ubyte));
		break;
	case Byte:
		sink(toString(c.u._byte));
		break;
	case Ushort:
		sink(toString(c.u._ushort));
		break;
	case Short:
		sink(toString(c.u._short));
		break;
	case Uint:
		sink(toString(c.u._uint));
		break;
	case Int:
		sink(toString(c.u._int));
		break;
	case Ulong:
		sink(toString(c.u._ulong));
		break;
	case Long:
		sink(toString(c.u._long));
		break;
	case Float:
		sink(toString(c.u._float));
		break;
	case Double:
		sink(toString(c.u._double));
		break;
	case Real:
		assert(false);
	case ir.PrimitiveType.Kind.Invalid:
	case Void:
		assert(false);
	}
}

ir.Constant foldTernary(ref ir.Exp exp, ir.Ternary ternary, TargetInfo target)
{
	bool conditionCopy, trueCopy, falseCopy;
	auto condition = fold(ternary.condition, conditionCopy, target);
	auto ifTrue = fold(ternary.ifTrue, trueCopy, target);
	auto ifFalse = fold(ternary.ifFalse, trueCopy, target);
	if (condition is null || ifTrue is null || ifFalse is null) {
		return null;
	}
	if (!isBool(condition.type)) {
		return null;
	}
	if (condition.u._bool) {
		return ifTrue;
	} else {
		return ifFalse;
	}
}

ir.Constant foldAccessExp(ref ir.Exp exp, ir.AccessExp accessExp, TargetInfo target)
{
	assert(accessExp.child !is null);

	// Currently, only `typeid(_).size` is supported.
	if (accessExp.child.nodeType != ir.NodeType.Typeid ||
	    accessExp.field.name != "size") {
		return null;
	}
	auto tid = cast(ir.Typeid)accessExp.child;
	auto type = tid.type;
	if (tid.type is null && tid.exp !is null) {
		type = getExpType(tid.exp);
	}
	assert(type !is null);

	auto tsize = size(target, type);
	assert(tsize > 0);
	return buildConstantSizeT(exp.loc, target, tsize);
}

ir.Constant foldBinOp(ref ir.Exp exp, ir.BinOp binop, TargetInfo target)
{
	assert(binop !is null);
	assert(binop.left !is null);
	assert(binop.right !is null);
	bool copyLeft, copyRight;
	auto cl = fold(binop.left, copyLeft, target);
	auto cr = fold(binop.right, copyRight, target);
	if (cl is null || cr is null || !typesEqual(cl.type, cr.type)) {
		return null;
	}
	auto c = foldBinOp(exp, binop.op,
	                   copyLeft ? cast(ir.Constant)copyExp(cl) : cl,
			           copyRight ? cast(ir.Constant)copyExp(cr) : cr, target);
	if (c !is null) {
		exp = c;
	}
	return c;
}

ir.Constant foldUnary(ref ir.Exp exp, ir.Unary unary, TargetInfo target)
{
	assert(unary !is null);
	if (unary.value is null) {
		return null;
	}
	bool _copy;
	auto c = fold(unary.value, _copy, target);
	if (c is null) {
		return null;
	}
	auto uc = foldUnary(exp, unary, _copy ? cast(ir.Constant)copyExp(c) : c, target);
	if (uc !is null) {
		exp = uc;
	}
	return uc;
}

ir.Constant foldBinOp(ref ir.Exp exp, ir.BinOp.Op op, ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	switch (op) with (ir.BinOp.Op) {
	case OrOr: return foldBinOpOrOr(cl, cr, target);
	case AndAnd: return foldBinOpAndAnd(cl, cr, target);
	case Or: return foldBinOpOr(cl, cr, target);
	case Xor: return foldBinOpXor(cl, cr, target);
	case And: return foldBinOpAnd(cl, cr, target);
	case Equal: return foldBinOpEqual(cl, cr, target);
	case NotEqual: return foldBinOpNotEqual(cl, cr, target);
	case Less: return foldBinOpLess(cl, cr, target);
	case LessEqual: return foldBinOpLessEqual(cl, cr, target);
	case GreaterEqual: return foldBinOpGreaterEqual(cl, cr, target);
	case Greater: return foldBinOpGreater(cl, cr, target);
	case LS: return foldBinOpLS(cl, cr, target);
	case SRS: return foldBinOpSRS(cl, cr, target);
	case RS: return foldBinOpRS(cl, cr, target);
	case Add: return foldBinOpAdd(cl, cr, target);
	case Sub: return foldBinOpSub(cl, cr, target);
	case Mul: return foldBinOpMul(cl, cr, target);
	case Div: return foldBinOpDiv(cl, cr, target);
	case Mod: return foldBinOpMod(cl, cr, target);
	case Pow: return foldBinOpPow(cl, cr, target);
	default: return null;
	}
}

ir.Constant foldUnary(ref ir.Exp exp, ir.Unary u, ir.Constant c, TargetInfo target)
{
	switch (u.op) with (ir.Unary.Op) {
	case Minus: return foldUnaryMinus(c, target);
	case Plus: return foldUnaryPlus(c, target);
	case Not: return foldUnaryNot(c, target);
	case Complement: return foldUnaryComplement(c, target);
	case Cast: return foldUnaryCast(c, u.type, target);
	default: return null;
	}
}

private ir.Constant buildEmptyConstant(ir.Node n, ir.Type t)
{
	auto c = new ir.Constant();
	c.loc = n.loc;
	c.type = t;
	return c;
}

ir.Constant foldBinOpOrOr(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.loc));

	auto pt = cast(ir.PrimitiveType)cl.type;
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

ir.Constant foldBinOpAndAnd(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpOr(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpXor(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpAnd(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpEqual(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.loc));

	if (cl.type.nodeType != ir.NodeType.PrimitiveType) {
		return null;
	}

	auto pt = cast(ir.PrimitiveType)cl.type;
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

ir.Constant foldBinOpNotEqual(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.loc));

	if (cl.type.nodeType != ir.NodeType.PrimitiveType) {
		return null;
	}

	auto pt = cast(ir.PrimitiveType)cl.type;
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

ir.Constant foldBinOpLess(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.loc));

	auto pt = cast(ir.PrimitiveType)cl.type;
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

ir.Constant foldBinOpLessEqual(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.loc));

	auto pt = cast(ir.PrimitiveType)cl.type;
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

ir.Constant foldBinOpGreaterEqual(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.loc));

	auto pt = cast(ir.PrimitiveType)cl.type;
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

ir.Constant foldBinOpGreater(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	auto c = buildEmptyConstant(cl, buildBool(cl.loc));

	auto pt = cast(ir.PrimitiveType)cl.type;
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

ir.Constant foldBinOpLS(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpSRS(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpRS(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpAdd(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpSub(ir.Constant cl, ir.Constant cr, TargetInfo targert)
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

ir.Constant foldBinOpMul(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldBinOpDiv(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	void dieIfZero(bool isZero)
	{
		if (isZero) {
			throw makeError(cl.loc, "divide by zero.");
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

ir.Constant foldBinOpMod(ir.Constant cl, ir.Constant cr, TargetInfo target)
{
	void dieIfZero(bool isZero)
	{
		if (isZero) {
			throw makeError(cl.loc, "divide by zero.");
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

ir.Constant foldBinOpPow(ir.Constant cl, ir.Constant cr, TargetInfo target)
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

ir.Constant foldUnaryCast(ir.Constant c, ir.Type t, TargetInfo target)
{
	auto _enum = cast(ir.Enum)realType(t, false);
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
	auto loc = c.loc;
	ir.Constant outConstant;
	switch (toPrim.type) with (ir.PrimitiveType.Kind) {
	case Int:
		outConstant = buildConstantInt(loc, signed ? cast(int)signedFrom : cast(int)unsignedFrom);
		break;
	case Uint:
		outConstant = buildConstantUint(loc, signed ? cast(uint)signedFrom : cast(uint)unsignedFrom);
		break;
	case Long:
		outConstant = buildConstantLong(loc, signed ? cast(long)signedFrom : cast(long)unsignedFrom);
		break;
	case Ulong:
		outConstant = buildConstantUlong(loc, signed ? cast(ulong)signedFrom : cast(ulong)unsignedFrom);
		break;
	default:
		break;
	}
	if (_enum !is null && outConstant !is null) {
		outConstant.fromEnum = _enum;
	}
	return outConstant;
}

ir.Constant foldUnaryMinus(ir.Constant c, TargetInfo target)
{
	auto nc = cast(ir.Constant)copyExp(c);
	auto pt = cast(ir.PrimitiveType) c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int:
		nc.u._int = -c.u._int;
		break;
	case Uint:
		// Yes, this is 2's complement.
		nc.u._uint = -c.u._uint;
		break;
	case Long:
		nc.u._long = -c.u._long;
		break;
	case Ulong:
		// Yes, this is 2's complement.
		nc.u._ulong = -c.u._ulong;
		break;
	case Double:
		nc.u._double = -c.u._double;
		break;
	case Float:
		nc.u._float = -c.u._float;
		break;
	default:
		panicAssert(c, false);
		break;
	}
	return nc;
}

ir.Constant foldUnaryPlus(ir.Constant c, TargetInfo target)
{
	auto nc = cast(ir.Constant)copyExp(c);
	auto pt = cast(ir.PrimitiveType) c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int:
		nc.u._int = +c.u._int;
		break;
	case Uint:
		nc.u._uint = +c.u._uint;
		break;
	case Long:
		nc.u._long = +c.u._long;
		break;
	case Ulong:
		nc.u._ulong = +c.u._ulong;
		break;
	case Double:
		nc.u._double = -c.u._double;
		break;
	case Float:
		nc.u._float = -c.u._float;
		break;
	default:
		panicAssert(c, false);
		break;
	}
	return nc;
}

ir.Constant foldUnaryNot(ir.Constant c, TargetInfo target)
{
	auto nc = cast(ir.Constant)copyExp(c);
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool: nc.u._bool = !c.u._bool; break;
	default:
		panicAssert(c, false);
		break;
	}
	return nc;
}

ir.Constant foldUnaryComplement(ir.Constant c, TargetInfo target)
{
	auto nc = cast(ir.Constant)copyExp(c);
	auto pt = cast(ir.PrimitiveType)c.type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Int: nc.u._int = ~c.u._int; break;
	case Uint: nc.u._uint = ~c.u._uint; break;
	case Long: nc.u._long = ~c.u._long; break;
	case Ulong: nc.u._ulong = ~c.u._ulong; break;
	default:
		panicAssert(c, false);
		break;
	}
	return nc;
}

ir.Constant evaluateOrNull(TargetInfo target, ir.Exp exp)
{
	if (exp is null) {
		return null;
	}
	return fold(exp, target);
}

ir.Constant evaluateOrNull(LanguagePass lp, ir.Scope current, ir.Exp exp)
{
	return evaluateOrNull(lp.target, exp);
}

ir.Constant evaluate(LanguagePass lp, ir.Scope current, ir.Exp exp)
{
	auto constant = fold(exp, lp.target);
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

