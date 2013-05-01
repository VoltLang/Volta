// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.constant;

import std.conv : to;

import volt.errors;
import volt.ir.util;

import volt.llvm.interfaces;


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
	case ArrayLiteral:
		auto al = cast(ir.ArrayLiteral)exp;
		handleArrayLiteral(state, al, result);
		break;
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
	case ClassLiteral:
		auto literal = cast(ir.ClassLiteral)exp;
		assert(literal !is null);
		handleClassLiteral(state, literal, result);
		break;
	default:
		auto str = format(
			"could not get constant from expression '%s'",
			to!string(exp.nodeType));
		throw panic(exp.location, str);
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
		throw panicUnhandled(asUnary, to!string(asUnary.op));
	}
}

void handleAddrOf(State state, ir.Unary de, Value result)
{
	auto expRef = cast(ir.ExpReference)de.value;
	if (expRef is null)
		throw panic(de.value.location, "not a ExpReference");

	if (expRef.decl.declKind != ir.Declaration.Kind.Variable)
		throw panic(de.value.location, "must be a variable");

	auto var = cast(ir.Variable)expRef.decl;
	Type type;

	auto v = state.getVariableValue(var, type);

	auto pt = new ir.PointerType();
	pt.base = type.irType;
	assert(pt.base !is null);
	pt.mangledName = volt.semantic.mangle.mangle(pt);

	result.value = v;
	result.type = state.fromIr(pt);
	result.isPointer = false;
}

void handlePlusMinus(State state, ir.Unary asUnary, Value result)
{
	state.getConstantValue(asUnary.value, result);

	auto primType = cast(PrimitiveType)result.type;
	if (primType is null)
		throw panic(asUnary.location, "must be primitive type");

	if (asUnary.op == ir.Unary.Op.Minus)
		result.value = LLVMConstNeg(result.value);
}

void handleCast(State state, ir.Unary asUnary, Value result)
{
	void error(string t) {
		auto str = format("error unary constant expression '%s'", t);
		throw panic(asUnary.location, str);
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
		assert(fn !is null);
		result.isPointer = false;
		result.value = state.getFunctionValue(fn, result.type);
		break;
	case FunctionParam:
		auto fp = cast(ir.FunctionParam)expRef.decl;
		assert(fp !is null);

		Type type;
		auto v = state.getVariableValue(fp, type);

		result.value = v;
		result.isPointer = false;
		result.type = type;
		break;
	case Variable:
		auto var = cast(ir.Variable)expRef.decl;
		assert(var !is null);

		/**
		 * Whats going on here? Since constants ultimatly is handled
		 * by the linker, by either being just binary data in some
		 * segment or references to symbols, but not a copy of a
		 * values somewhere (which can later be changed), we can
		 * not statically load from a variable.
		 *
		 * But since useBaseStorage causes Variables to become a reference
		 * implicitly we can allow them trough. We use this for typeid.
		 * This might seem backwards but it works out.
		 */
		if (!var.useBaseStorage)
			throw panic("variables needs '&' for constants");

		Type type;
		auto v = state.getVariableValue(var, type);

		result.value = v;
		result.isPointer = false;
		result.type = type;
		break;
	default:
		throw panic(expRef.location, "invalid decl type");
	}
}
