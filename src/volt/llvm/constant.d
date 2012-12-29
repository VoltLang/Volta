// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.constant;

import std.conv : to;

import lib.llvm.core;

import volt.exceptions;
import volt.llvm.type;
import volt.llvm.value;
import volt.llvm.state;


/**
 * Returns the LLVMValueRef for the given constant expression,
 * does not require that state.builder is set.
 */
LLVMValueRef getConstantValue(State state, ir.Exp exp)
{

	auto v = new Value();
	getConstantValue(state, exp, v);
	return v.value;
}

void getConstantValue(State state, ir.Exp exp, Value result)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		auto cnst = cast(ir.Constant)exp;
		return handleConstant(state, cnst, result);
	case Unary:
		auto asUnary = cast(ir.Unary)exp;
		return handleUnary(state, asUnary, result);
	default:
		auto str = format(
			"could not get constant from expression '%s'",
			to!string(exp.nodeType));
		throw CompilerPanic(exp.location, str);
	}
}

void handleUnary(State state, ir.Unary asUnary, Value result)
{
	switch (asUnary.op) with (ir.Unary.Op) {
	case Cast:
		return handleCast(state, asUnary, result);
	case Plus:
	case Minus:
		return handlePlusMinus(state, asUnary, result);
	default:
		auto str = format(
			"could not handle unary operation '%s'",
			to!string(asUnary.op));
		throw CompilerPanic(asUnary.location, str);
	}
}

void handlePlusMinus(State state, ir.Unary asUnary, Value result)
{
	state.getConstantValue(asUnary.value, result);

	auto primType = cast(PrimitiveType)result.type;
	if (primType is null)
		throw CompilerPanic(asUnary.location, "must be primitive type");

	if (asUnary.op == ir.Unary.Op.Minus)
		result.value = LLVMConstNeg(result.value);
}

void handleCast(State state, ir.Unary asUnary, Value result)
{
	void error(string t) {
		auto str = format("error unary constant expression '%s'", t);
		throw CompilerPanic(asUnary.location, str);
	}

	if (asUnary.op != ir.Unary.Op.Cast)
		error("other unary op then cast");

	state.getConstantValue(asUnary.value, result);

	auto to = cast(PrimitiveType)state.fromIr(asUnary.type);
	auto from = cast(PrimitiveType)result.type;
	if (to is null || from is null)
		error("not integer constants");

	result.type = to;
	result.value =  LLVMConstIntCast(result.value, to.llvmType, from.signed);
}

void handleConstant(State state, ir.Constant asConst, Value result)
{
	assert(asConst.type !is null);

	// All of the error checking should have been
	// done in other passes and unimplemented features
	// is checked for in the called functions.

	result.type = state.fromIr(asConst.type);
	result.value = result.type.fromConstant(state, asConst);
}
