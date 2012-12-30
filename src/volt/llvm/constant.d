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
	case StructLiteral:
		auto sl = cast(ir.StructLiteral)exp;
		handleStructLiteral(state, sl, result);
		break;
	case ExpReference:
		auto expRef = cast(ir.ExpReference)exp;
		handleExpReference(state, expRef, result);
		break;
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
	case AddrOf:
		return handleAddrOf(state, asUnary, result);
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

void handleAddrOf(State state, ir.Unary de, Value result)
{
	auto expRef = cast(ir.ExpReference)de.value;
	if (expRef is null)
		throw CompilerPanic(de.value.location, "not a ExpReference");

	if (expRef.decl.declKind != ir.Declaration.Kind.Variable)
		throw CompilerPanic(de.value.location, "must be a variable");

	auto var = cast(ir.Variable)expRef.decl;
	Type type;

	auto v = state.getVariableValue(var, type);

	auto pt = new ir.PointerType();
	pt.base = type.irType;
	assert(pt.base !is null);
	pt.mangledName = volt.semantic.mangle.mangle(null, pt);

	result.value = v;
	result.type = state.fromIr(pt);
	result.isPointer = false;
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

	state.getConstantValue(asUnary.value, result);

	auto newType = state.fromIr(asUnary.type);
	auto oldType = result.type;

	{
		auto newPrim = cast(PrimitiveType)newType;
		auto oldPrim = cast(PrimitiveType)oldType;

		if (newPrim !is null && oldPrim !is null) {
			result.type = newType;
			result.value = LLVMConstIntCast(result.value, newPrim.llvmType, oldPrim.signed);
			return;
		}
	}

	{
		auto newTypePtr = cast(PointerType)newType;
		auto oldTypePtr = cast(PointerType)oldType;
		auto newTypeFn = cast(FunctionType)newType;
		auto oldTypeFn = cast(FunctionType)oldType;

		if ((newTypePtr !is null || newTypeFn !is null) &&
		    (oldTypePtr !is null || oldTypeFn !is null)) {
			result.type = newType;
			result.value = LLVMConstBitCast(result.value, newType.llvmType);
			return;
		}
	}

	error("not a handle cast type");
}


/*
 *
 * Misc functions.
 *
 */



void handleExpReference(State state, ir.ExpReference expRef, Value result)
{
	switch(expRef.decl.declKind) with (ir.Declaration.Kind) {
	case Function:
		auto fn = cast(ir.Function)expRef.decl;
		result.isPointer = false;
		result.value = state.getFunctionValue(fn, result.type);
		break;
	case Variable:
		throw CompilerPanic("variables needs '&' for constants");
	default:
		throw CompilerPanic(expRef.location, "invalid decl type");
	}
}
