// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.type;

import std.conv : to;

import lib.llvm.core;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.llvm.constant;
import volt.llvm.interfaces;
static import volt.semantic.mangle;
static import volt.semantic.classify;


/**
 * Base class for a LLVM backend types.
 */
class Type
{
public:
	ir.Type irType;
	LLVMTypeRef llvmType;
	bool structType; // Is the type a LLVM struct.

protected:
	this(State state, ir.Type irType, bool structType, LLVMTypeRef llvmType)
	in {
		assert(state !is null);
		assert(irType !is null);
		assert(llvmType !is null);

		assert(irType.mangledName !is null);
		assert(state.getTypeNoCreate(irType.mangledName) is null);
	}
	body {
		state.addType(this, irType.mangledName);

		this.irType = irType;
		this.structType = structType;
		this.llvmType = llvmType;
	}

public:
	LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		throw panic(cnst.location, "Can't from constant");
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
		super(state, pt, false, LLVMVoidTypeInContext(state.context));
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
		case Wchar:
			bits = 16;
			llvmType = LLVMInt16TypeInContext(state.context);
			break;
		case Int:
			signed = true;
			goto case Uint;
		case Uint:
		case Dchar:
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
			throw panic(pt.location, "PrmitiveType.Real not handled");
		case Void:
			throw panic(pt.location, "PrmitiveType.Void not handled");
		}

		super(state, pt, false, llvmType);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		if (floating) {
			if (bits == 32) {
				return LLVMConstReal(llvmType, cnst._float);
			} else {
				assert(bits == 64);
				return LLVMConstReal(llvmType, cnst._double);
			}
		}

		long val;
		if (boolean) {
			if (cnst._bool)
				val = 1;
		} else if (signed) {
			val = cnst._long;
		} else if (bits == 8) {
			assert(cnst.arrayData.length == 1);
			val = (cast(ubyte[])cnst.arrayData)[0];
		} else {
			val = cnst._ulong;
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
	static PointerType fromIr(State state, ir.PointerType pt)
	{
		auto base = state.fromIr(pt.base);

		// Pointers can via structs reference themself.
		auto test = state.getTypeNoCreate(pt.mangledName);
		if (test !is null) {
			return cast(PointerType)test;
		}
		return new PointerType(state, pt, base);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		if (!cnst.isNull) {
			throw panic(cnst.location, "can only fromConstant null pointers.");
		}
		return LLVMConstPointerNull(llvmType);
	}

private:
	this(State state, ir.PointerType pt, Type base)
	{
		this.base = base;

		auto voidT = cast(VoidType) base;
		if (voidT !is null) {
			llvmType = LLVMPointerType(LLVMInt8TypeInContext(state.context), 0);
		} else {
			llvmType = LLVMPointerType(base.llvmType, 0);
		}
		super(state, pt, false, llvmType);
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

	Type[2] types;

	enum size_t ptrIndex = 0;
	enum size_t lengthIndex = 1;

public:
	this(State state, ir.ArrayType at)
	{
		llvmType = LLVMStructCreateNamed(state.context, at.mangledName);
		super(state, at, true, llvmType);

		// Avoid creating void[] arrays turn them into ubyte[] instead.
		base = state.fromIr(at.base);
		if (base is state.voidType) {
			base = state.ubyteType;
		}

		auto irPtr = new ir.PointerType(base.irType);
		addMangledName(irPtr);
		ptrType = cast(PointerType)state.fromIr(irPtr);
		base = ptrType.base;

		lengthType = state.sizeType;

		types[ptrIndex] = ptrType;
		types[lengthIndex] = lengthType;

		LLVMTypeRef[2] mt;
		mt[ptrIndex] = ptrType.llvmType;
		mt[lengthIndex] = lengthType.llvmType;

		LLVMStructSetBody(llvmType, mt, false);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		auto strConst = LLVMConstStringInContext(state.context, cast(char[])cnst.arrayData, false);
		auto strGlobal = LLVMAddGlobal(state.mod, LLVMTypeOf(strConst), "");
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

		// Handle null.
		if (al.values.length == 0) {
			LLVMValueRef[2] vals;
			vals[lengthIndex] = LLVMConstNull(lengthType.llvmType);
			vals[ptrIndex] = LLVMConstNull(ptrType.llvmType);
			return LLVMConstNamedStruct(llvmType, vals);
		}

		LLVMValueRef[] alVals;
		alVals.length = al.values.length;
		foreach(uint i, exp; al.values) {
			alVals[i] = state.getConstantValue(exp);
		}

		auto litConst = LLVMConstArray(base.llvmType, alVals);
		auto litGlobal = LLVMAddGlobal(state.mod, LLVMTypeOf(litConst), "");
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
 * Static array type.
 */
class StaticArrayType : Type
{
public:
	Type base;
	uint length;

	ArrayType arrayType;
	PointerType ptrType;

public:
	this(State state, ir.StaticArrayType sat)
	{
		auto irArray = new ir.ArrayType(sat.base);
		addMangledName(irArray);
		arrayType = cast(ArrayType)state.fromIr(irArray);
		base = arrayType.base;
		ptrType = arrayType.ptrType;

		length = cast(uint)sat.length;
		llvmType = LLVMArrayType(base.llvmType, length);
		super(state, sat, true, llvmType);
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
	ir.CallableType ct;

public:
	this(State state, ir.CallableType ct, bool passByVal, LLVMTypeRef llvmType)
	{
		this.ct = ct;
		super(state, ct, passByVal, llvmType);
	}
}

/**
 * Function type.
 */
class FunctionType : CallableType
{
public:
	static FunctionType fromIr(State state, ir.FunctionType ft)
	{
		Type ret;
		Type[] params;

		ret = state.fromIr(ft.ret);
		foreach(int i, param; ft.params) {
			params ~= state.fromIr(param);
		}

		// FunctionPointers can via structs reference themself.
		auto test = state.getTypeNoCreate(ft.mangledName);
		if (test !is null) {
			return cast(FunctionType)test;
		}
		return new FunctionType(state, ft, ret, params);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		if (!cnst.isNull) {
			throw panic(cnst.location, "can only fromConstant null pointers.");
		}
		return LLVMConstPointerNull(llvmType);
	}

private:
	this(State state, ir.FunctionType ft, Type ret, Type[] params)
	{
		LLVMTypeRef[] args;
		args.length = ft.params.length + ft.hiddenParameter;

		this.ret = ret;
		foreach(int i, type; params) {
			args[i] = type.llvmType;
			if (volt.semantic.classify.isRef(ft.params[i])) {
				args[i] = LLVMPointerType(args[i], 0);
			}
		}

		if (ft.hiddenParameter) {
			args[$-1] = state.voidPtrType.llvmType;
		}

		llvmCallType = LLVMFunctionType(ret.llvmType, args, ft.hasVarArgs);
		llvmType = LLVMPointerType(llvmCallType, 0);
		super(state, ft, false, llvmType);
	}
}

/**
 * Delegates are lowered here into a struct with two members.
 */
class DelegateType : CallableType
{
public:
	LLVMTypeRef llvmCallPtrType;

	enum size_t voidPtrIndex = 0;
	enum size_t funcIndex = 1;

public:
	this(State state, ir.DelegateType dt)
	{
		llvmType = LLVMStructCreateNamed(state.context, dt.mangledName);
		super(state, dt, true, llvmType);

		ret = state.fromIr(dt.ret);

		LLVMTypeRef[] args;
		args.length = dt.params.length + 1;

		foreach(int i, param; dt.params) {
			auto type = state.fromIr(param);
			args[i] = type.llvmType;
			if (volt.semantic.classify.isRef(param)) {
				args[i] = LLVMPointerType(args[i], 0);
			}
		}
		args[$-1] = state.voidPtrType.llvmType;

		llvmCallType = LLVMFunctionType(ret.llvmType, args, dt.hasVarArgs);
		llvmCallPtrType = LLVMPointerType(llvmCallType, 0);

		LLVMTypeRef[2] mt;
		mt[voidPtrIndex] = state.voidPtrType.llvmType;
		mt[funcIndex] = llvmCallPtrType;

		LLVMStructSetBody(llvmType, mt, false);
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
		auto c = cast(ir.Class)irType.loweredNode;
		auto mangled = c !is null ? c.mangledName : irType.mangledName;

		llvmType = LLVMStructCreateNamed(state.context, mangled);
		super(state, irType, true, llvmType);

		/// @todo check packing.
		uint index;
		LLVMTypeRef[] mt;

		foreach(m; irType.members.nodes) {
			auto var = cast(ir.Variable)m;
			if (var is null)
				continue;

			if (var.storage != ir.Variable.Storage.Field)
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
			throw panic("struct literal has the wrong number of initializers");

		foreach(uint i, ref val; vals) {
			val = state.getConstantValue(sl.exps[i]);
		}

		return LLVMConstNamedStruct(llvmType, vals);
	}
}

/**
 * Backend instance of a @link volt.ir.toplevel.Union ir.Union@endlink.
 */
class UnionType : Type
{
public:
	uint[string] indices;
	Type[] types;

public:
	this(State state, ir.Union irType)
	{
		llvmType = LLVMStructCreateNamed(state.context, irType.mangledName);
		super(state, irType, true, llvmType);

		uint index;
		foreach(m; irType.members.nodes) {
			auto var = cast(ir.Variable)m;
			if (var is null)
				continue;

			if (var.storage != ir.Variable.Storage.Field)
				continue;

			/// @todo handle anon members.
			assert(var.name !is null);

			indices[var.name] = index++;
			types ~= state.fromIr(var.type);
		}

		/// @todo check packing.
		LLVMTypeRef[1] mt;
		mt[0] = LLVMArrayType(state.ubyteType.llvmType, irType.totalSize);
		LLVMStructSetBody(llvmType, mt, false);
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
			throw panic(irType.location, "TypeReference with null type");

		return state.fromIr(tr.type);
	} else if (irType.nodeType == ir.NodeType.StorageType) {
		auto st = cast(ir.StorageType)irType;
		assert(st !is null);

		if (st.base is null)
			throw panic(irType.location, "StorageType with null base");

		return state.fromIr(st.base);
	}

	if (irType.mangledName is null) {
		auto m = addMangledName(irType);
		auto str = format("mangledName not set (%s)", m);
		warning(irType.location, str);
	}

	auto test = state.getTypeNoCreate(irType.mangledName);
	if (test !is null) {
		return test;
	}

	auto scrubbed = scrubStorage(irType);

	auto type = fromIrImpl(state, scrubbed);
	if (scrubbed.mangledName != irType.mangledName) {
		state.addType(type, irType.mangledName);
	}
	return type;
}

Type fromIrImpl(State state, ir.Type irType)
{
	auto test = state.getTypeNoCreate(irType.mangledName);
	if (test !is null) {
		return test;
	}

	switch(irType.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto pt = cast(ir.PrimitiveType)irType;
		if (pt.type == ir.PrimitiveType.Kind.Void)
			return new .VoidType(state, pt);
		else
			return new .PrimitiveType(state, pt);
	case PointerType:
		auto pt = cast(ir.PointerType)irType;
		return .PointerType.fromIr(state, pt);
	case ArrayType:
		auto at = cast(ir.ArrayType)irType;
		return new .ArrayType(state, at);
	case StaticArrayType:
		auto sat = cast(ir.StaticArrayType)irType;
		return new .StaticArrayType(state, sat);
	case FunctionType:
		auto ft = cast(ir.FunctionType)irType;
		return .FunctionType.fromIr(state, ft);
	case DelegateType:
		auto dt = cast(ir.DelegateType)irType;
		return new .DelegateType(state, dt);
	case Struct:
		auto strct = cast(ir.Struct)irType;
		return new .StructType(state, strct);
	case Union:
		auto u = cast(ir.Union)irType;
		return new .UnionType(state, u);
	case Class:
		auto _class = cast(ir.Class)irType;
		auto pointer = buildPtrSmart(_class.location, _class.layoutStruct);
		addMangledName(pointer);
		return fromIr(state, pointer);
	case UserAttribute:
		auto attr = cast(ir.UserAttribute)irType;
		assert(attr !is null);
		irType = attr.layoutClass;
		goto case Class;
	case Enum:
		auto _enum = cast(ir.Enum)irType;
		return fromIr(state, _enum.base);
	default:
		auto emsg = format("Can't translate type %s (%s)", irType.nodeType, irType.mangledName);
		throw panic(irType.location, emsg);
	}
}

/**
 * Populate the common types that hang off the state.
 */
void buildCommonTypes(State state, bool V_P64)
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

	if (V_P64) {
		state.sizeType = state.ulongType;
	} else {
		state.sizeType = state.uintType;
	}

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

/**
 * Does a smart copy of a type.
 *
 * Meaning that well copy all types, but skipping
 * TypeReferences, but inserting one when it comes
 * across a named type.
 */
ir.Type scrubStorage(ir.Type type)
{
	switch (type.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto asPt = cast(ir.PrimitiveType)type;
		auto pt = new ir.PrimitiveType(asPt.type);
		pt.location = asPt.location;
		addMangledName(pt);
		return pt;
	case PointerType:
		auto asPt = cast(ir.PointerType)type;
		auto pt = new ir.PointerType(scrubStorage(asPt.base));
		pt.location = asPt.location;
		addMangledName(pt);
		return pt;
	case ArrayType:
		auto asAt = cast(ir.ArrayType)type;
		auto at = new ir.ArrayType(scrubStorage(asAt.base));
		at.location = asAt.location;
		addMangledName(at);
		return at;
	case StaticArrayType:
		auto asSat = cast(ir.StaticArrayType)type;
		auto sat = new ir.StaticArrayType();
		sat.location = asSat.location;
		sat.base = scrubStorage(asSat.base);
		sat.length = asSat.length;
		addMangledName(sat);
		return sat;
	case AAType:
		auto asAA = cast(ir.AAType)type;
		auto aa = new ir.AAType();
		aa.location = asAA.location;
		aa.value = scrubStorage(asAA.value);
		aa.key = scrubStorage(asAA.key);
		addMangledName(aa);
		return aa;
	case FunctionType:
		auto asFt = cast(ir.FunctionType)type;
		auto ft = new ir.FunctionType(asFt);
		ft.location = asFt.location;
		ft.ret = scrubStorage(ft.ret);
		foreach(ref t; ft.params) {
			t = scrubStorage(t);
		}
		addMangledName(ft);
		return ft;
	case DelegateType:
		auto asDg = cast(ir.DelegateType)type;
		auto dg = new ir.DelegateType(asDg);
		dg.location = asDg.location;
		dg.ret = scrubStorage(dg.ret);
		foreach(ref t; dg.params) {
			t = scrubStorage(t);
		}
		addMangledName(dg);
		return dg;
	case StorageType:
		auto asSt = cast(ir.StorageType)type;
		if (asSt.type != ir.StorageType.Kind.Ref) {
			return scrubStorage(asSt.base);
		}
		auto at = new ir.StorageType();
		at.location = asSt.location;
		at.type = asSt.type;
		at.base = scrubStorage(asSt.base);
		addMangledName(at);
		return at;
	case TypeReference:
		auto tr = cast(ir.TypeReference)type;
		return scrubStorage(tr.type);
	case UserAttribute:
	case Interface:
	case Struct:
	case Union:
	case Class:
	case Enum:
		return type;
	default:
		assert(false, "foo " ~ to!string(type.nodeType));
	}
}

/**
 * Helper function for adding mangled name to ir types.
 */
string addMangledName(ir.Type irType)
{
	string m = volt.semantic.mangle.mangle(irType);
	irType.mangledName = m;
	return m;
}
