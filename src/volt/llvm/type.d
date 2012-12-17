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
	LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		throw CompilerPanic(cnst.location, "Can't from constant");
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
			throw CompilerPanic(pt.location, "PrmitiveType.Real not handled");
		case Void:
			throw CompilerPanic(pt.location, "PrmitiveType.Void not handled");
		}

		super(pt, llvmType);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		if (floating)
			throw CompilerPanic(cnst.location, "Can not handle float literals");

		long val;
		if (boolean) {
			if (cnst.value == "true")
				val = 1;
		} else if (signed) {
			val = to!long(cnst.value);
		} else if (bits == 8) {
			assert(cnst.arrayData.length == 1);
			val = (cast(ubyte[])cnst.arrayData)[0];
		} else {
			val = cast(long)to!ulong(cnst.value);
		}

		return LLVMConstInt(llvmType, val, signed);
	}

	LLVMValueRef fromNumber(State state, long val)
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
	uint[string] indices;
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

			indices[var.name] = index++;
			auto t = state.fromIr(var.type);
			mt ~= t.llvmType;
			types ~= t;
		}

		/// @todo check packing.
		llvmType = LLVMStructCreateNamed(state.context, irType.mangledName);
		LLVMStructSetBody(llvmType, mt, false);

		super(irType, llvmType);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		auto ptrIndex = indices["ptr"];
		auto lengthIndex = indices["length"];

		if (ptrIndex > 1 || lengthIndex > 1 || indices.length > 2)
			throw CompilerPanic(cnst.location, "constant can't be turned into array struct");


		auto ptrType = cast(PointerType)types[ptrIndex];
		auto lengthType = cast(PrimitiveType)types[lengthIndex];

		auto strConst = LLVMConstStringInContext(state.context, cast(char[])cnst.arrayData, true);
		auto strGlobal = LLVMAddGlobal(state.mod, LLVMTypeOf(strConst), "__arrayLiteral");
		LLVMSetGlobalConstant(strGlobal, true);
		LLVMSetInitializer(strGlobal, strConst);

		LLVMValueRef[2] ind;
		ind[0] = LLVMConstNull(lengthType.llvmType);
		ind[1] = LLVMConstNull(lengthType.llvmType);

		auto strGep = LLVMConstInBoundsGEP(strGlobal, ind);

		LLVMValueRef[2] vals;
		vals[lengthIndex] = lengthType.fromNumber(state, cast(long)cnst.arrayData.length);
		vals[ptrIndex] = strGep;

		return LLVMConstNamedStruct(llvmType, vals);
	}
}

/**
 * Populate the common types that hang off the state.
 */
void buildCommonTypes(State state)
{
	auto voidTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
	auto voidPtrTypeIr = new ir.PointerType(voidTypeIr);

	auto boolTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
	auto intTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
	auto uintTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
	auto ulongTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);


	addMangledName(voidTypeIr);
	addMangledName(voidPtrTypeIr);

	addMangledName(boolTypeIr);
	addMangledName(intTypeIr);
	addMangledName(uintTypeIr);
	addMangledName(ulongTypeIr);


	state.voidType = cast(VoidType)state.fromIr(voidTypeIr);
	state.voidPtrType = cast(PointerType)state.fromIr(voidPtrTypeIr);

	state.boolType = cast(PrimitiveType)state.fromIr(boolTypeIr);
	state.intType = cast(PrimitiveType)state.fromIr(intTypeIr);
	state.uintType = cast(PrimitiveType)state.fromIr(uintTypeIr);
	state.ulongType = cast(PrimitiveType)state.fromIr(ulongTypeIr);


	assert(state.voidType !is null);
	assert(state.voidPtrType !is null);

	assert(state.boolType !is null);
	assert(state.intType !is null);
	assert(state.uintType !is null);
	assert(state.ulongType !is null);
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
		auto m = addMangledName(irType);
		auto str = format("mangledName not set (%s)", m);
		warning(irType.location, str);
	}

	auto tCheck = irType.mangledName in state.typeStore;
	if (tCheck !is null)
		return *tCheck;

	auto t = uncachedFromIr(state, irType);
	state.typeStore[irType.mangledName] = t;
	return t;
}


private:


string addMangledName(ir.Type irType)
{
	string m = volt.semantic.mangle.mangle(null, irType);
	irType.mangledName = m;
	return m;
}

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
		throw CompilerPanic(irType.location, "Can't translate type");
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
