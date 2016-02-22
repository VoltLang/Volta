// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.constant;

import watt.text.format : format;

import volt.errors;
import volt.ir.util;

import volt.llvm.common;
import volt.llvm.interfaces;

static import volt.semantic.mangle;


void getConstantValue(State state, ir.Exp exp, Value result)
{
	result.isPointer = false;
	switch (exp.nodeType) with (ir.NodeType) {
	case Unary:
		auto asUnary = cast(ir.Unary)exp;
		assert(asUnary !is null);
		return handleConstUnary(state, asUnary, result);
	case Constant:
		auto cnst = cast(ir.Constant)exp;
		assert(cnst !is null);
		return handleConstant(state, cnst, result);
	case ExpReference:
		auto expRef = cast(ir.ExpReference)exp;
		assert(expRef !is null);
		return handleConstExpReference(state, expRef, result);
	case ArrayLiteral:
		auto al = cast(ir.ArrayLiteral)exp;
		assert(al !is null);
		return handleArrayLiteral(state, al, result);
	case StructLiteral:
		auto sl = cast(ir.StructLiteral)exp;
		assert(sl !is null);
		return handleStructLiteral(state, sl, result);
	case UnionLiteral:
		auto ul = cast(ir.UnionLiteral)exp;
		assert(ul !is null);
		return handleUnionLiteral(state, ul, result);
	case ClassLiteral:
		auto literal = cast(ir.ClassLiteral)exp;
		assert(literal !is null);
		return handleClassLiteral(state, literal, result);
	default:
		auto str = format(
			"could not get constant from expression '%s'",
			ir.nodeToString(exp));
		throw panic(exp.location, str);
	}
}

private:
/*
 *
 * Handle functions.
 *
 */

void handleConstUnary(State state, ir.Unary asUnary, Value result)
{
	switch (asUnary.op) with (ir.Unary.Op) {
	case Cast:
		return handleConstCast(state, asUnary, result);
	case AddrOf:
		return handleConstAddrOf(state, asUnary, result);
	case Plus, Minus:
		return handleConstPlusMinus(state, asUnary, result);
	default:
		throw panicUnhandled(asUnary, ir.nodeToString(asUnary));
	}
}

void handleConstAddrOf(State state, ir.Unary de, Value result)
{
	auto expRef = cast(ir.ExpReference)de.value;
	assert(expRef !is null);
	assert(expRef.decl.declKind == ir.Declaration.Kind.Variable);

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

void handleConstPlusMinus(State state, ir.Unary asUnary, Value result)
{
	getConstantValue(state, asUnary.value, result);

	auto primType = cast(PrimitiveType)result.type;
	assert(primType !is null);
	assert(!result.isPointer);

	if (asUnary.op == ir.Unary.Op.Minus) {
		result.value = LLVMConstNeg(result.value);
	}
}

void handleConstCast(State state, ir.Unary asUnary, Value result)
{
	void error(string t) {
		auto str = format("error unary constant expression '%s'", t);
		throw panic(asUnary.location, str);
	}

	getConstantValue(state, asUnary.value, result);

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

	throw makeError(asUnary.location, "not a handle cast type.");
}

void handleConstExpReference(State state, ir.ExpReference expRef, Value result)
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
		if (!var.useBaseStorage) {
			throw panic(expRef.location, "variables needs '&' for constants");
		}

		Type type;
		auto v = state.getVariableValue(var, type);

		result.value = v;
		result.isPointer = false;
		result.type = type;
		break;
	case EnumDeclaration:
		auto edecl = cast(ir.EnumDeclaration)expRef.decl;
		result.value = state.getConstant(edecl.assign);
		result.isPointer = false;
		result.type = state.fromIr(edecl.type);
		break;
	default:
		throw panic(expRef.location, "invalid decl type");
	}
}
