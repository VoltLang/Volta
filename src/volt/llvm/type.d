// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.type;

import std.conv : to;

import lib.llvm.core;

import ir = volt.ir.ir;
import volt.exceptions;
import volt.llvm.state;
static import volt.semantic.mangle;


/**
 *
 */
class Type
{
public:
	ir.Type irType;
	LLVMTypeRef llvmType;


protected:
	this(ir.Type irType, LLVMTypeRef llvmType)
	out {
		assert(irType !is null);
		assert(llvmType !is null);
	}
	body {
		this.irType = irType;
		this.llvmType = llvmType;
	}


public:
	LLVMValueRef fromConstant(ir.Constant cnst)
	{
		throw new CompilerPanic(cnst.location, "Can't from constant");
	}
}

/**
 *
 */
class VoidType : Type
{
public:
	this(State state, ir.PrimitiveType pt)
	{
		super(pt, LLVMVoidType());
	}
}

/**
 *
 */
class PrimitiveType : Type
{
public:
	bool boolean;
	bool signed;
	bool floating;
	uint bits;


public:
	this(State state, ir.PrimitiveType pt)
	{
		final switch(pt.type) with (ir.PrimitiveType.Kind) {
		case Bool:
			bits = 1;
			boolean = true;
			llvmType = LLVMInt1Type();
			break;
		case Byte:
			signed = true;
			goto case Char;
		case Char:
		case Ubyte:
			bits = 8;
			llvmType = LLVMInt8Type();
			break;
		case Short:
			signed = true;
			goto case Ushort;
		case Ushort:
			bits = 16;
			llvmType = LLVMInt16Type();
			break;
		case Int:
			signed = true;
			goto case Uint;
		case Uint:
			bits = 32;
			llvmType = LLVMInt32Type();
			break;
		case Long:
			signed = true;
			goto case Ulong;
		case Ulong:
			bits = 64;
			llvmType = LLVMInt64Type();
			break;
		case Float:
			bits = 32;
			floating = true;
			llvmType = LLVMFloatType();
			break;
		case Double:
			bits = 64;
			floating = true;
			llvmType = LLVMDoubleType();
			break;
		case Real:
			throw new CompilerPanic(pt.location, "PrmitiveType.Real not handled");
		case Void:
			throw new CompilerPanic(pt.location, "PrmitiveType.Void not handled");
		}

		super(pt, llvmType);
	}

	override LLVMValueRef fromConstant(ir.Constant cnst)
	{
		if (floating)
			throw new CompilerPanic(cnst.location, "Can not handle float literals");

		long val;
		if (boolean) {
			if (cnst.value == "true")
				val = 1;
		} else if (signed) {
			val = to!long(cnst.value);
		} else if (bits == 8) {
			/// @todo this should not be done here.

			auto v = cnst.value;
			assert(v.length >= 3);
			assert(v[0] == '\'');

			val = v[1];
			if (val == '\\') {
				switch (v[2]) {
				case 'n': val = '\n'; break;
				case 'r': val = '\r'; break;
				case 't': val = '\t'; break;
				case '0': val = '\0'; break;
				case 'f': val = '\f'; break;
				case 'b': val = '\b'; break;
				case 'a': val = '\a'; break;
				case 'v': val = '\v'; break;
				default:
					throw new CompilerPanic(cnst.location, "unhandled escape");
				}
			}
		} else {
			val = cast(long)to!ulong(cnst.value);
		}

		return LLVMConstInt(llvmType, val, signed);
	}

	LLVMValueRef fromNumber(long val)
	{
		return LLVMConstInt(llvmType, val, signed);
	}
}

/**
 * PointerType represents a standard C pointer.
 */
class PointerType : Type
{
public:
	Type base;

public:
	this(State state, ir.PointerType pt)
	{
		base = state.fromIr(pt.base);

		llvmType = LLVMPointerType(base.llvmType, 0);
		super(pt, llvmType);
	}
}

/**
 *
 */
class FunctionType : Type
{
public:
	Type ret;


public:
	this(State state, ir.FunctionType ft)
	{
		ret = state.fromIr(ft.ret);

		LLVMTypeRef[] args;
		args.length = ft.params.length;

		foreach(int i, param; ft.params) {
			auto type = state.fromIr(param.type);
			args[i] = type.llvmType;
		}

		auto llvmType = LLVMFunctionType(ret.llvmType, args, false);
		super(ft, llvmType);
	}
}

/*
 *
 */
class StructType : Type
{
	uint[string] indecies;
	Type[] types;

	this(State state, ir.Struct irType)
	{
		uint index;
		LLVMTypeRef[] mt;

		foreach(m; irType.members.nodes) {
			auto var = cast(ir.Variable)m;
			if (var is null)
				continue;

			/// @todo figure out if Variable is member or not.
			/// @todo handle anon types.
			assert(var.name !is null);

			indecies[var.name] = index++;
			auto t = state.fromIr(var.type);
			mt ~= t.llvmType;
			types ~= t;
		}

		/// @todo check packing.
		llvmType = LLVMStructCreateNamed(state.context, irType.mangledName);
		LLVMStructSetBody(llvmType, mt, false);

		super(irType, llvmType);
	}
}

/**
 * Looks up or creates the corresponding LLVMTypeRef
 * and Type for the given irType.
 */
Type fromIr(State state, ir.Type irType)
{
	if (irType.nodeType == ir.NodeType.TypeReference) {
		auto tr = cast(ir.TypeReference)irType;
		return state.fromIr(tr.type);
	}

	if (irType.mangledName is null) {
		auto m = volt.semantic.mangle.mangle(null, irType);
		auto str = format("mangledName not set (%s)", m);
		warning(irType.location, str);
		irType.mangledName = m;
	}

	auto tCheck = irType.mangledName in state.typeStore;
	if (tCheck !is null)
		return *tCheck;

	auto t = uncachedFromIr(state, irType);
	state.typeStore[irType.mangledName] = t;
	return t;
}


private:


Type uncachedFromIr(State state, ir.Type irType)
{
	switch(irType.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		return state.primitiveTypeFromIr(cast(ir.PrimitiveType)irType);
	case PointerType:
		return state.pointerTypeFromIr(cast(ir.PointerType)irType);
	case FunctionType:
		return state.functionTypeFromIr(cast(ir.FunctionType)irType);
	case Struct:
		return state.structTypeFromIr(cast(ir.Struct)irType);
	default:
		throw new CompilerPanic(irType.location, "Can't translate type");
	}
}

Type primitiveTypeFromIr(State state, ir.PrimitiveType pt)
{
	if (pt.type == ir.PrimitiveType.Kind.Void)
		return new VoidType(state, pt);
	else
		return new PrimitiveType(state, pt);
}

Type pointerTypeFromIr(State state, ir.PointerType pt)
{
	return new PointerType(state, pt);
}

Type functionTypeFromIr(State state, ir.FunctionType ft)
{
	return new FunctionType(state, ft);
}

Type structTypeFromIr(State state, ir.Struct strct)
{
	return new StructType(state, strct);
}
