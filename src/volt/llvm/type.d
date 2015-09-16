// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.type;

import lib.llvm.core;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.llvm.di : diBaseType, diPointerType, diStruct, diStructSetBody,
                      diFunctionType;
import volt.llvm.constant;
import volt.llvm.interfaces;
static import volt.semantic.mangle;
static import volt.semantic.classify;
static import volt.semantic.typer;


/**
 * Base class for a LLVM backend types.
 */
class Type
{
public:
	ir.Type irType;
	LLVMTypeRef llvmType;
	LLVMValueRef diType;

protected:
	this(State state, ir.Type irType, LLVMTypeRef llvmType,
	     LLVMValueRef diType)
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
		this.llvmType = llvmType;
		this.diType = diType;
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
	static VoidType fromIr(State state, ir.PrimitiveType pt)
	{
		return new VoidType(state, pt);
	}

private:
	this(State state, ir.PrimitiveType pt)
	{
		super(state, pt, LLVMVoidTypeInContext(state.context), null);
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
	static PrimitiveType fromIr(State state, ir.PrimitiveType pt)
	{
		return new PrimitiveType(state, pt);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		if (floating) {
			if (bits == 32) {
				return LLVMConstReal(llvmType, cnst.u._float);
			} else {
				assert(bits == 64);
				return LLVMConstReal(llvmType, cnst.u._double);
			}
		}

		ulong val;
		if (boolean) {
			if (cnst.u._bool)
				val = 1;
		} else if (signed) {
			val = cast(ulong)cnst.u._long;
		} else if (bits == 8) {
			assert(cnst.arrayData.length == 1);
			val = (cast(ubyte[])cnst.arrayData)[0];
		} else {
			val = cnst.u._ulong;
		}

		return LLVMConstInt(llvmType, val, signed);
	}

	LLVMValueRef fromNumber(State state, long val)
	{
		return LLVMConstInt(llvmType, cast(ulong)val, signed);
	}

private:
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

		super(state, pt, llvmType, null);
		diType = state.diBaseType(this, pt.type);
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
		auto base = .fromIr(state, pt.base);

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
		if (base.isVoid) {
			llvmType = LLVMPointerType(
				LLVMInt8TypeInContext(state.context), 0);
		} else {
			llvmType = LLVMPointerType(base.llvmType, 0);
		}
		diType = state.diPointerType(pt, base);
		super(state, pt, llvmType, diType);
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
	static ArrayType fromIr(State state, ir.ArrayType at)
	{
		.fromIr(state, at.base);

		auto test = state.getTypeNoCreate(at.mangledName);
		if (test !is null) {
			return cast(ArrayType)test;
		}
		return new ArrayType(state, at);
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

		auto strGep = LLVMConstInBoundsGEP(strGlobal, ind[]);

		LLVMValueRef[2] vals;
		vals[lengthIndex] = lengthType.fromNumber(state, cast(long)cnst.arrayData.length);
		vals[ptrIndex] = strGep;

		return LLVMConstNamedStruct(llvmType, vals[]);
	}

	LLVMValueRef fromArrayLiteral(State state, ir.ArrayLiteral al)
	{
		assert(state.fromIr(al.type) is this);

		// Handle null.
		if (al.values.length == 0) {
			LLVMValueRef[2] vals;
			vals[lengthIndex] = LLVMConstNull(lengthType.llvmType);
			vals[ptrIndex] = LLVMConstNull(ptrType.llvmType);
			return LLVMConstNamedStruct(llvmType, vals[]);
		}

		LLVMValueRef[] alVals;
		alVals.length = al.values.length;
		foreach (uint i, exp; al.values) {
			alVals[i] = state.getConstant(exp);
		}

		auto litConst = LLVMConstArray(base.llvmType, alVals);
		auto litGlobal = LLVMAddGlobal(state.mod, LLVMTypeOf(litConst), "");
		LLVMSetGlobalConstant(litGlobal, true);
		LLVMSetInitializer(litGlobal, litConst);

		LLVMValueRef[2] ind;
		ind[0] = LLVMConstNull(lengthType.llvmType);
		ind[1] = LLVMConstNull(lengthType.llvmType);

		auto strGep = LLVMConstInBoundsGEP(litGlobal, ind[]);

		LLVMValueRef[2] vals;
		vals[lengthIndex] = lengthType.fromNumber(state, cast(long)al.values.length);
		vals[ptrIndex] = strGep;

		return LLVMConstNamedStruct(llvmType, vals[]);
	}

private:
	this(State state, ir.ArrayType at)
	{
		diType = diStruct(state, at);
		llvmType = LLVMStructCreateNamed(state.context, at.mangledName);
		super(state, at, llvmType, diType);

		// Avoid creating void[] arrays turn them into ubyte[] instead.
		base = state.fromIr(at.base);
		if (base.isVoid) {
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

		LLVMStructSetBody(llvmType, mt[], false);

		if (ptrType.diType is null || lengthType.diType is null) {
			return;
		}

		version (D_Version2) static assert(ptrIndex < lengthIndex);
		version (D_Version2) diStructSetBody(state, cast(Type)this,
			[ptrType, lengthType],
			["ptr", "length"]);
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
	static StaticArrayType fromIr(State state, ir.StaticArrayType sat)
	{
		.fromIr(state, sat.base);

		auto test = state.getTypeNoCreate(sat.mangledName);
		if (test !is null) {
			return cast(StaticArrayType)test;
		}
		return new StaticArrayType(state, sat);
	}

	LLVMValueRef fromArrayLiteral(State state, ir.ArrayLiteral al)
	{
		assert(state.fromIr(al.type) is this);

		// Handle null.
		version (none) if (al.values.length == 0) {
			LLVMValueRef[2] vals;
			vals[lengthIndex] = LLVMConstNull(lengthType.llvmType);
			vals[ptrIndex] = LLVMConstNull(ptrType.llvmType);
			return LLVMConstNamedStruct(llvmType, vals);
		}

		LLVMValueRef[] alVals;
		alVals.length = al.values.length;
		foreach (uint i, exp; al.values) {
			alVals[i] = state.getConstant(exp);
		}

		auto litConst = LLVMConstArray(base.llvmType, alVals);

		/*
		 * This was apperently wrong
		 *
		 * auto litGlobal = LLVMAddGlobal(state.mod, LLVMTypeOf(litConst), "");
		 * LLVMSetGlobalConstant(litGlobal, true);
		 * LLVMSetInitializer(litGlobal, litConst);
		 */
		return litConst;
	}

private:
	this(State state, ir.StaticArrayType sat)
	{
		auto irArray = new ir.ArrayType(sat.base);
		addMangledName(irArray);
		arrayType = cast(ArrayType)state.fromIr(irArray);
		base = arrayType.base;
		ptrType = arrayType.ptrType;

		length = cast(uint)sat.length;
		llvmType = LLVMArrayType(base.llvmType, length);
		super(state, sat, llvmType, null);
	}
}

/**
 * Base class for callable types FunctionType and DelegateType.
 */
abstract class CallableType : Type
{
public:
	Type ret;
	ir.CallableType ct;
	Type[] params;

public:
	this(State state, ir.CallableType ct,
	     LLVMTypeRef llvmType, LLVMValueRef diType)
	{
		this.ct = ct;
		super(state, ct, llvmType, diType);
	}
}

/**
 * Function type.
 */
class FunctionType : CallableType
{
public:
	LLVMTypeRef llvmCallType;

public:
	static FunctionType fromIr(State state, ir.FunctionType ft)
	{
		Type[] params;
		Type ret;

		ret = .fromIr(state, ft.ret);
		foreach (param; ft.params) {
			params ~= .fromIr(state, param);
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
		this.params = params;
		this.ret = ret;
		LLVMTypeRef[] args;
		Type[] di;

		args = new typeof(args)(ft.params.length + ft.hiddenParameter);
		di = new typeof(di)(ft.params.length + ft.hiddenParameter);

		foreach (i, type; params) {
			if (ft.isArgRef[i] || ft.isArgOut[i]) {
				auto irPtr = new ir.PointerType(type.irType);
				addMangledName(irPtr);
				auto ptrType = cast(PointerType)state.fromIr(irPtr);

				args[i] = ptrType.llvmType;
				di[i] = type;
			} else {
				args[i] = type.llvmType;
				di[i] = type;
			}
		}

		if (ft.hiddenParameter) {
			args[$-1] = state.voidPtrType.llvmType;
			di[$-1] = state.voidPtrType;
		}

		llvmCallType = LLVMFunctionType(ret.llvmType, args, ft.hasVarArgs && ft.linkage == ir.Linkage.C);
		llvmType = LLVMPointerType(llvmCallType, 0);
		diType = diFunctionType(state, ret, di);
		super(state, ft, llvmType, diType);
	}
}

/**
 * Delegates are lowered here into a struct with two members.
 */
class DelegateType : CallableType
{
public:
	LLVMTypeRef llvmCallPtrType;

	enum uint voidPtrIndex = 0;
	enum uint funcIndex = 1;

public:
	static DelegateType fromIr(State state, ir.DelegateType dg)
	{
		Type[] params;
		Type ret;

		ret = .fromIr(state, dg.ret);
		foreach (param; dg.params) {
			.fromIr(state, param);
		}

		// FunctionPointers can via structs reference themself.
		auto test = state.getTypeNoCreate(dg.mangledName);
		if (test !is null) {
			return cast(DelegateType)test;
		}
		return new DelegateType(state, dg);
	}

	override LLVMValueRef fromConstant(State state, ir.Constant cnst)
	{
		if (!cnst.isNull) {
			throw panic(cnst.location, "can only fromConstant null pointers.");
		}
		LLVMValueRef[2] vals;
		auto vptr = LLVMPointerType(LLVMInt8TypeInContext(state.context), 0);
		vals[0] = LLVMConstNull(vptr);
		vals[1] = LLVMConstNull(vptr);
		return LLVMConstNamedStruct(llvmType, vals.ptr, 2);
	}

private:
	this(State state, ir.DelegateType dt)
	{
		diType = diStruct(state, dt);
		llvmType = LLVMStructCreateNamed(state.context, dt.mangledName);
		super(state, dt, llvmType, diType);

		auto irFuncType = new ir.FunctionType(dt);
		irFuncType.hiddenParameter = true;

		addMangledName(irFuncType);

		auto funcType = cast(FunctionType)state.fromIr(irFuncType);

		ret = funcType.ret;
		params = funcType.params;

		assert(funcType !is null);

		llvmCallPtrType = funcType.llvmType;

		LLVMTypeRef[2] mt;
		mt[voidPtrIndex] = state.voidPtrType.llvmType;
		mt[funcIndex] = llvmCallPtrType;

		LLVMStructSetBody(llvmType, mt[], false);

		version (D_Version2) static assert(voidPtrIndex < funcIndex);
		diStructSetBody(state, this,
			[state.voidPtrType, funcType],
			["ptr", "func"]);
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
	static StructType fromIr(State state, ir.Struct irType)
	{
		return new StructType(state, irType);
	}

	LLVMValueRef fromStructLiteral(State state, ir.StructLiteral sl)
	{
		LLVMValueRef[] vals;
		vals.length = indices.length;

		if (vals.length != sl.exps.length) {
			throw panic("struct literal has the wrong number of initializers");
		}

		foreach (uint i, ref val; vals) {
			val = state.getConstant(sl.exps[i]);
		}

		return LLVMConstNamedStruct(llvmType, vals);
	}

private:
	this(State state, ir.Struct irType)
	{
		auto c = cast(ir.Class) irType.loweredNode;
		auto mangled = c !is null ? c.mangledName : irType.mangledName;

		diType = state.diStruct(irType);
		llvmType = LLVMStructCreateNamed(state.context, mangled);
		super(state, irType, llvmType, diType);

		// This is adds the "reference" part of the class.
		if (c !is null) {
			auto ptr = buildPtrSmart(c.location, irType);
			addMangledName(ptr);
			addMangledName(ptr.base);

			auto old = ptr.mangledName;
			ptr.mangledName = mangled;

			auto p = PointerType.fromIr(state, ptr);

			state.addType(p, old);
			// This type is now aliased as:
			// pC3foo5Clazz14__layoutStruct
			// C3foo5Clazz
		}

		// @todo check packing.
		uint index;
		LLVMTypeRef[] mt;
		ir.Variable[] vars;

		foreach (m; irType.members.nodes) {

			auto var = cast(ir.Variable)m;
			if (var is null)
				continue;

			if (var.storage != ir.Variable.Storage.Field)
				continue;

			// @todo handle anon types.
			assert(var.name !is null);

			indices[var.name] = index++;
			auto t = state.fromIr(var.type);
			mt ~= t.llvmType;
			vars ~= var;
			types ~= t;
		}

		LLVMStructSetBody(llvmType, mt, false);
		diStructSetBody(state, diType, vars);
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
	ir.Union utype;

public:
	static UnionType fromIr(State state, ir.Union irType)
	{
		return new UnionType(state, irType);
	}

	LLVMValueRef fromStructLiteral(State state, ir.StructLiteral sl)
	{
		LLVMValueRef[] vals;
		vals.length = indices.length;

		if (vals.length != sl.exps.length) {
			throw panic("struct literal has the wrong number of initializers");
		}

		foreach (uint i, ref val; vals) {
			val = state.getConstant(sl.exps[i]);
		}

		return LLVMConstNamedStruct(llvmType, vals);
	}

	LLVMValueRef fromUnionLiteral(State state, ir.UnionLiteral ul)
	{
		if (indices.length != ul.exps.length) {
			throw panic("union literal has the wrong number of initializers");
		}

		uint count = LLVMCountStructElementTypes(llvmType);
		if (count != 1) {
			throw panic("union with more than one member");
		}

		size_t lastSize = 0;
		ir.Exp lastExp;

		foreach (i, t; types) {
			auto sz = volt.semantic.classify.size(state.lp, t.irType);
			if (sz > lastSize) {
				lastExp = ul.exps[i];
				lastSize = sz;
			}
		}

		auto vals = new LLVMValueRef[](1);
		vals[0] = state.getConstant(lastExp);

		return LLVMConstNamedStruct(llvmType, vals);
	}

private:
	this(State state, ir.Union irType)
	{
		this.llvmType = LLVMStructCreateNamed(state.context, irType.mangledName);
		this.utype = irType;
		super(state, irType, llvmType, diType);

		uint index;
		void handle(ir.Node m) {
			auto var = cast(ir.Variable)m;
			if (var is null)
				return;

			if (var.storage != ir.Variable.Storage.Field)
				return;

			// @todo handle anon members.
			assert(var.name !is null);

			indices[var.name] = index++;
			types ~= state.fromIr(var.type);
		}

		foreach (m; irType.members.nodes) {
			handle(m);
		}

		// @todo check packing.
		LLVMTypeRef[1] mt;
		mt[0] = LLVMArrayType(state.ubyteType.llvmType, cast(uint)irType.totalSize);
		LLVMStructSetBody(llvmType, mt[], false);
	}
}

/**
 * Looks up or creates the corresponding LLVMTypeRef
 * and Type for the given irType.
 */
Type fromIr(State state, ir.Type irType)
{
	Type result;

	if (irType.mangledName is null) {
		auto m = addMangledName(irType);
		auto str = format("mangledName not set (%s)", m);
		warning(irType.location, str);
	}

	auto test = state.getTypeNoCreate(irType.mangledName);
	if (test !is null) {
		result = test;
		return result;
	}

	auto scrubbed = scrubStorage(irType);

	auto type = fromIrImpl(state, scrubbed);
	if (scrubbed.mangledName != irType.mangledName) {
		state.addType(type, irType.mangledName);
	}
	result = type;
	return result;
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
		if (pt.type == ir.PrimitiveType.Kind.Void) {
			return .VoidType.fromIr(state, pt);
		} else {
			return .PrimitiveType.fromIr(state, pt);
		}
	case PointerType:
		auto pt = cast(ir.PointerType)irType;
		return .PointerType.fromIr(state, pt);
	case ArrayType:
		auto at = cast(ir.ArrayType)irType;
		return .ArrayType.fromIr(state, at);
	case StaticArrayType:
		auto sat = cast(ir.StaticArrayType)irType;
		return .StaticArrayType.fromIr(state, sat);
	case FunctionType:
		auto ft = cast(ir.FunctionType)irType;
		return .FunctionType.fromIr(state, ft);
	case DelegateType:
		auto dt = cast(ir.DelegateType)irType;
		return .DelegateType.fromIr(state, dt);
	case Struct:
		auto strct = cast(ir.Struct)irType;
		return .StructType.fromIr(state, strct);
	case Union:
		auto u = cast(ir.Union)irType;
		return .UnionType.fromIr(state, u);
	case AAType:
		auto aa = cast(ir.AAType)irType;
		return state.voidPtrType;
	case Enum:
		auto _enum = cast(ir.Enum)irType;
		return fromIr(state, _enum.base);
	case Class:
		auto _class = cast(ir.Class)irType;
		StructType.fromIr(state, _class.layoutStruct);
		return state.getTypeNoCreate(_class.mangledName);
	case UserAttribute:
		auto attr = cast(ir.UserAttribute)irType;
		assert(attr !is null);
		irType = attr.layoutClass;
		goto case Class;
	case TypeReference:
		auto tr = cast(ir.TypeReference)irType;

		assert(cast(ir.Aggregate)tr.type !is null);

		auto ret = fromIrImpl(state, tr.type);
		if (tr.mangledName != ret.irType.mangledName) {
			// Used for UserAttributes lowered class.
			state.addType(ret, tr.mangledName);
		}
		return ret;
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
	ir.Type outType;
	switch (type.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto asPt = cast(ir.PrimitiveType)type;
		auto pt = new ir.PrimitiveType(asPt.type);
		pt.location = asPt.location;
		outType = pt;
		break;
	case PointerType:
		auto asPt = cast(ir.PointerType)type;
		auto pt = new ir.PointerType();
		pt.location = asPt.location;
		pt.base = scrubStorage(asPt.base);
		outType = pt;
		break;
	case ArrayType:
		auto asAt = cast(ir.ArrayType)type;
		auto at = new ir.ArrayType();
		at.location = asAt.location;
		at.base = scrubStorage(asAt.base);
		outType = at;
		break;
	case StaticArrayType:
		auto asSat = cast(ir.StaticArrayType)type;
		auto sat = new ir.StaticArrayType();
		sat.location = asSat.location;
		sat.base = scrubStorage(asSat.base);
		sat.length = asSat.length;
		outType = sat;
		break;
	case AAType:
		auto asAA = cast(ir.AAType)type;
		auto aa = new ir.AAType();
		aa.location = asAA.location;
		aa.value = scrubStorage(asAA.value);
		aa.key = scrubStorage(asAA.key);
		outType = aa;
		break;
	case FunctionType:
		auto asFt = cast(ir.FunctionType)type;
		auto ft = new ir.FunctionType(asFt);
		ft.location = asFt.location;
		ft.ret = scrubStorage(ft.ret);
		foreach (i, ref t; ft.params) {
			t = scrubStorage(t);
		}
		// TODO a better fix for this.
		ft.isConst = false;
		ft.isScope = false;
		ft.isImmutable = false;
		outType = ft;
		break;
	case DelegateType:
		auto asDg = cast(ir.DelegateType)type;
		auto dg = new ir.DelegateType(asDg);
		dg.location = asDg.location;
		dg.ret = scrubStorage(dg.ret);
		foreach (i, ref t; dg.params) {
			t = scrubStorage(t);
		}
		// TODO a better fix for this.
		dg.isConst = false;
		dg.isScope = false;
		dg.isImmutable = false;
		outType = dg;
		break;
	case TypeReference:
		auto asTr = cast(ir.TypeReference)type;
		if (cast(ir.Aggregate)asTr.type is null) {
			outType = scrubStorage(asTr.type);
			break;
		}
		auto tr = new ir.TypeReference();
		tr.type = asTr.type;
		tr.location = asTr.location;
		tr.type = asTr.type;
		outType = tr;
		break;
	case UserAttribute:
	case Interface:
	case Struct:
	case Union:
	case Class:
	case Enum:
		return type;
	case StorageType:
	default:
		throw panicUnhandled(type, ir.nodeToString(type.nodeType));
	}
	addMangledName(outType);
	assert(outType.mangledName[0] != 'e');
	return outType;
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

/**
 * Helper function to tell if a type is Void.
 */
@property bool isVoid(Type type)
{
	return cast(VoidType)type !is null;
}
