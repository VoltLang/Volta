// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.type;

import std.conv : to;

import lib.llvm.core;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.llvm.type;
import volt.llvm.state;
import volt.llvm.constant;
static import volt.semantic.mangle;


/**
 * Base class for a LLVM backend types.
 */
class Type
{
public:
	ir.Type irType;
	LLVMTypeRef llvmType;

protected:
	this(State state, ir.Type irType, LLVMTypeRef llvmType)
	in {
		assert(state !is null);
		assert(irType !is null);
		assert(llvmType !is null);

		assert(irType.mangledName !is null);
		assert((irType.mangledName in state.typeStore) is null);
	}
	body {
		state.typeStore[irType.mangledName] = this;

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
 * Void @link volt.ir.type.PrimitiveType PrimtiveType@endlink.
 */
class VoidType : Type
{
public:
	this(State state, ir.PrimitiveType pt)
	{
		super(state, pt, LLVMVoidTypeInContext(state.context));
	}
}

/**
 * Integer @link volt.ir.type.PrimitiveType PrimtiveType@endlink but not void.
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
			llvmType = LLVMInt1TypeInContext(state.context);
			break;
		case Byte:
			signed = true;
			goto case Char;
		case Char:
		case Ubyte:
			bits = 8;
			llvmType = LLVMInt8TypeInContext(state.context);
			break;
		case Short:
			signed = true;
			goto case Ushort;
		case Ushort:
			bits = 16;
			llvmType = LLVMInt16TypeInContext(state.context);
			break;
		case Int:
			signed = true;
			goto case Uint;
		case Uint:
			bits = 32;
			llvmType = LLVMInt32TypeInContext(state.context);
			break;
		case Long:
			signed = true;
			goto case Ulong;
		case Ulong:
			bits = 64;
			llvmType = LLVMInt64TypeInContext(state.context);
			break;
		case Float:
			bits = 32;
			floating = true;
			llvmType = LLVMFloatTypeInContext(state.context);
			break;
		case Double:
			bits = 64;
			floating = true;
			llvmType = LLVMDoubleTypeInContext(state.context);
			break;
		case Real:
			throw CompilerPanic(pt.location, "PrmitiveType.Real not handled");
		case Void:
			throw CompilerPanic(pt.location, "PrmitiveType.Void not handled");
		}

		super(state, pt, llvmType);
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

		auto voidT = cast(VoidType) base;
		if (voidT !is null) {
			llvmType = LLVMPointerType(LLVMInt8Type(), 0);
		} else {
			llvmType = LLVMPointerType(base.llvmType, 0);
		}
		super(state, pt, llvmType);
	}
}

/**
 * Array type.
 */
class ArrayType : Type
{
public:
	Type base;
	PointerType ptrType;
	PrimitiveType lengthType;

	Type types[2];

	immutable size_t ptrIndex = 0;
	immutable size_t lengthIndex = 1;

public:
	this(State state, ir.ArrayType at)
	{
		llvmType = LLVMStructCreateNamed(state.context, at.mangledName);
		super(state, at, llvmType);

		// Avoid creating void[] arrays turn them into ubyte[] instead.
		base = state.fromIr(at.base);
		if (base is state.voidType) {
			base = state.ubyteType;
		}

		auto irPtr = new ir.PointerType(base.irType);
		addMangledName(irPtr);
		ptrType = cast(PointerType)state.fromIr(irPtr);
		base = ptrType.base;

		/// @todo get the correct size here (size_t).
		lengthType = state.uintType;

		types[ptrIndex] = ptrType;
		types[lengthIndex] = lengthType;

		LLVMTypeRef[2] mt;
		mt[ptrIndex] = ptrType.llvmType;
		mt[lengthIndex] = lengthType.llvmType;

		LLVMStructSetBody(llvmType, mt, false);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
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

	LLVMValueRef fromArrayLiteral(State state, ir.ArrayLiteral al)
	{
		assert(state.fromIr(al.type) is this);

		LLVMValueRef[] alVals;
		alVals.length = al.values.length;
		foreach(uint i, exp; al.values) {
			alVals[i] = state.getConstantValue(exp);
		}

		auto litConst = LLVMConstArray(base.llvmType, alVals);
		auto litGlobal = LLVMAddGlobal(state.mod, LLVMTypeOf(litConst), "__arrayLiteral");
		LLVMSetGlobalConstant(litGlobal, true);
		LLVMSetInitializer(litGlobal, litConst);

		LLVMValueRef[2] ind;
		ind[0] = LLVMConstNull(lengthType.llvmType);
		ind[1] = LLVMConstNull(lengthType.llvmType);

		auto strGep = LLVMConstInBoundsGEP(litGlobal, ind);

		LLVMValueRef[2] vals;
		vals[lengthIndex] = lengthType.fromNumber(state, cast(long)al.values.length);
		vals[ptrIndex] = strGep;

		return LLVMConstNamedStruct(llvmType, vals);
	}
}

/**
 * Base class for callable types FunctionType and DelegateType.
 */
abstract class CallableType : Type
{
public:
	Type ret;
	LLVMTypeRef llvmCallType;

public:
	this(State state, ir.CallableType ct, LLVMTypeRef llvmType)
	{
		super(state, ct, llvmType);
	}
}

/**
 * Function type.
 */
class FunctionType : CallableType
{
public:
	this(State state, ir.FunctionType ft)
	{
		ret = state.fromIr(ft.ret);

		LLVMTypeRef[] args;
		args.length = ft.params.length + ft.hiddenParameter;

		foreach(int i, param; ft.params) {
			auto type = state.fromIr(param.type);
			args[i] = type.llvmType;
		}

		if (ft.hiddenParameter) {
			args[$-1] = state.voidPtrType.llvmType;
		}

		llvmCallType = LLVMFunctionType(ret.llvmType, args, false);
		llvmType = LLVMPointerType(llvmCallType, 0);
		super(state, ft, llvmType);
	}
}

/**
 * Delegates are lowered here into a struct with two members.
 */
class DelegateType : CallableType
{
public:
	LLVMTypeRef llvmCallPtrType;

	immutable uint voidPtrIndex = 0;
	immutable uint funcIndex = 1;

public:
	this(State state, ir.DelegateType dt)
	{
		ret = state.fromIr(dt.ret);

		LLVMTypeRef[] args;
		args.length = dt.params.length + 1;

		foreach(int i, param; dt.params) {
			auto type = state.fromIr(param.type);
			args[i] = type.llvmType;
		}
		args[$-1] = state.voidPtrType.llvmType;

		llvmCallType = LLVMFunctionType(ret.llvmType, args, false);
		llvmCallPtrType = LLVMPointerType(llvmCallType, 0);

		LLVMTypeRef[2] mt;
		mt[voidPtrIndex] = state.voidPtrType.llvmType;
		mt[funcIndex] = llvmCallPtrType;

		llvmType = LLVMStructCreateNamed(state.context, dt.mangledName);
		LLVMStructSetBody(llvmType, mt, false);

		super(state, dt, llvmType);
	}
}

/**
 * Backend instance of a @link volt.ir.toplevel.Struct ir.Struct@endlink.
 */
class StructType : Type
{
public:
	uint[string] indices;
	Type[] types;

public:
	this(State state, ir.Struct irType)
	{
		uint index;
		LLVMTypeRef[] mt;

		/// @todo check packing.
		llvmType = LLVMStructCreateNamed(state.context, irType.mangledName);
		super(state, irType, llvmType);

		foreach(m; irType.members.nodes) {
			auto var = cast(ir.Variable)m;
			if (var is null)
				continue;

			if (var.storage != ir.Variable.Storage.None)
				continue;

			/// @todo handle anon types.
			assert(var.name !is null);

			indices[var.name] = index++;
			auto t = state.fromIr(var.type);
			mt ~= t.llvmType;
			types ~= t;
		}


		LLVMStructSetBody(llvmType, mt, false);
	}

	LLVMValueRef fromStructLiteral(State state, ir.StructLiteral sl)
	{
		LLVMValueRef[] vals;
		vals.length = indices.length;

		if (vals.length != sl.exps.length)
			throw CompilerPanic("struct literal has the wrong number of initializers");

		foreach(uint i, ref val; vals) {
			val = state.getConstantValue(sl.exps[i]);
		}

		return LLVMConstNamedStruct(llvmType, vals);
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
		assert(tr !is null);

		if (tr.type is null)
			throw CompilerPanic(irType.location, "TypeReference with null type");

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

	switch(irType.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto pt = cast(ir.PrimitiveType)irType;
		if (pt.type == ir.PrimitiveType.Kind.Void)
			return new .VoidType(state, pt);
		else
			return new .PrimitiveType(state, pt);
	case PointerType:
		auto pt = cast(ir.PointerType)irType;
		return new .PointerType(state, pt);
	case ArrayType:
		auto at = cast(ir.ArrayType)irType;
		return new .ArrayType(state, at);
	case FunctionType:
		auto ft = cast(ir.FunctionType)irType;
		return new .FunctionType(state, ft);
	case DelegateType:
		auto dt = cast(ir.DelegateType)irType;
		return new .DelegateType(state, dt);
	case Struct:
		auto strct = cast(ir.Struct)irType;
		return new .StructType(state, strct);
	case StorageType:
		auto storage = cast(ir.StorageType) irType;
		return fromIr(state, storage.base);
	default:
		auto emsg = format("Can't translate type %s (%s)", irType.nodeType, irType.mangledName);
		throw CompilerPanic(irType.location, emsg);
	}
}

/**
 * Populate the common types that hang off the state.
 */
void buildCommonTypes(State state)
{
	auto voidTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);

	auto boolTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
	auto byteTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Byte);
	auto ubyteTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Ubyte);
	auto intTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
	auto uintTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Uint);
	auto ulongTypeIr = new ir.PrimitiveType(ir.PrimitiveType.Kind.Ulong);

	auto voidPtrTypeIr = new ir.PointerType(voidTypeIr);
	auto voidFunctionTypeIr = new ir.FunctionType();
	voidFunctionTypeIr.ret = voidTypeIr;


	addMangledName(voidTypeIr);

	addMangledName(boolTypeIr);
	addMangledName(byteTypeIr);
	addMangledName(ubyteTypeIr);
	addMangledName(intTypeIr);
	addMangledName(uintTypeIr);
	addMangledName(ulongTypeIr);

	addMangledName(voidPtrTypeIr);
	addMangledName(voidFunctionTypeIr);

	state.voidType = cast(VoidType)state.fromIr(voidTypeIr);

	state.boolType = cast(PrimitiveType)state.fromIr(boolTypeIr);
	state.byteType = cast(PrimitiveType)state.fromIr(byteTypeIr);
	state.ubyteType = cast(PrimitiveType)state.fromIr(ubyteTypeIr);
	state.intType = cast(PrimitiveType)state.fromIr(intTypeIr);
	state.uintType = cast(PrimitiveType)state.fromIr(uintTypeIr);
	state.ulongType = cast(PrimitiveType)state.fromIr(ulongTypeIr);

	state.voidPtrType = cast(PointerType)state.fromIr(voidPtrTypeIr);
	state.voidFunctionType = cast(FunctionType)state.fromIr(voidFunctionTypeIr);


	assert(state.voidType !is null);

	assert(state.boolType !is null);
	assert(state.byteType !is null);
	assert(state.ubyteType !is null);
	assert(state.intType !is null);
	assert(state.uintType !is null);
	assert(state.ulongType !is null);

	assert(state.voidPtrType !is null);
	assert(state.voidFunctionType !is null);
}


private:


/**
 * Helper function for adding mangled name to ir types.
 */
string addMangledName(ir.Type irType)
{
	string m = volt.semantic.mangle.mangle(null, irType);
	irType.mangledName = m;
	return m;
}
