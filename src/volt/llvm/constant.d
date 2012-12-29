// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.constant;

import lib.llvm.core;

import volt.exceptions;
import volt.llvm.type;
import volt.llvm.value;
import volt.llvm.state;
import volt.llvm.expression;


/**
 * Returns the LLVMValueRef for the given constant expression,
 * does not require that state.builder is set.
 */
LLVMValueRef getConstantValue(State state, ir.Exp exp)
{
	void error(string t) {
		auto str = format("could not get constant from expression '%s'", t);
		throw CompilerPanic(exp.location, str);
	}

	if (exp.nodeType == ir.NodeType.Constant)
		return getValue(state, exp);
	if (exp.nodeType != ir.NodeType.Unary)
		error("other exp then unary or constant");

	auto asUnary = cast(ir.Unary)exp;
	if (asUnary.op != ir.Unary.Op.Cast)
		error("other unary op then cast");

	auto c = cast(ir.Constant)asUnary.value;
	if (c is null)
		error("not cast from constant");

	auto to = cast(PrimitiveType)state.fromIr(asUnary.type);
	auto from = cast(PrimitiveType)state.fromIr(c.type);
	if (to is null || from is null)
		error("not integer constants");

	auto v = from.fromConstant(state, c);
	return LLVMConstIntCast(v, to.llvmType, from.signed);
}
