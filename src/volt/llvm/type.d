/*#D*/
// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Code and classes for turning Volt Types into LLVM types.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.type;

import lib.llvm.core;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.util;

import volt.errors;
import volta.util.sinks;
import volt.llvm.common;
import volt.llvm.interfaces;
import volt.llvm.abi.base;

static import volt.semantic.mangle;
static import volt.semantic.classify;


/*!
 * Base class for a LLVM backend types. Contains a refernce to the irType
 * for this type, the llvmType and the debugging info for this type.
 *
 * @ingroup llvmbackend
 */
class Type
{
public:
	ir.Type irType;
	LLVMTypeRef llvmType;
	LLVMMetadataRef diType;
	bool passByValAttr;
	bool passByValPtr;

	version (LLVMVersion12AndAbove) {
		// Need to have typed byVal enums in 12 and above.
		LLVMAttributeRef byValTypeAttr;
	}

public:
	void from(State, ir.Constant, Value) { assert(false); }
	void from(State, ir.ArrayLiteral, Value) { assert(false); }
	void from(State, ir.UnionLiteral, Value) { assert(false); }
	void from(State, ir.StructLiteral, Value) { assert(false); }

protected:
	this(State state, ir.Type irType, LLVMTypeRef llvmType,
	     LLVMMetadataRef diType)
	in {
		assert(state !is null);
		assert(irType !is null);
		assert(llvmType !is null);
		version (LLVMVersion7AndAbove) if (!state.irMod.forceNoDebug) {
			assert(diType !is null || cast(VoidType) this !is null);
		}

		assert(irType.mangledName !is null);
		assert(state.getTypeNoCreate(irType.mangledName) is null);
	}
	body {
		state.addType(this, irType.mangledName);

		this.irType = irType;
		this.llvmType = llvmType;
		this.diType = diType;
	}
}

/*!
 * Void @link volta.ir.base.PrimitiveType PrimtiveType@endlink.
 *
 * @ingroup llvmbackend
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
		llvmType = LLVMVoidTypeInContext(state.context);
		super(state, pt, llvmType, diType);
	}
}

/*!
 * Integer @link volta.ir.base.PrimitiveType PrimtiveType@endlink but not void.
 *
 * @ingroup llvmbackend
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

	override void from(State state, ir.Constant cnst, Value result)
	{
		LLVMValueRef r;
		if (floating) {
			if (bits == 32) {
				r = LLVMConstReal(llvmType, cnst.u._float);
			} else {
				assert(bits == 64);
				r = LLVMConstReal(llvmType, cnst.u._double);
			}
		} else {
			ulong val;
			if (boolean) {
				val = cnst.u._bool;
			} else if (signed) {
				val = cast(ulong)cnst.u._long;
			} else if (bits == 8 && cnst.arrayData.length == 1) {
				val = (cast(ubyte[])cnst.arrayData)[0];
			} else {
				val = cnst.u._ulong;
			}
			r = LLVMConstInt(llvmType, val, signed);
		}

		result.type = this;
		result.value = r;
		result.isPointer = false;
	}

	LLVMValueRef fromNumber(State state, long val)
	{
		return LLVMConstInt(llvmType, cast(ulong)val, signed);
	}

private:
	this(State state, ir.PrimitiveType pt)
	{
		boolean = pt.type == ir.PrimitiveType.Kind.Bool;
		bits = getBits(pt);
		signed = getSigned(pt);
		floating = getFloating(pt);
		llvmType = makeLLVMType(state, pt);
		diType = diBaseType(state, pt);

		super(state, pt, llvmType, diType);
	}

	static bool getFloating(ir.PrimitiveType pt)
	{
		final switch (pt.type) with (ir.PrimitiveType.Kind) {
		case Bool, Byte, Ubyte, Char, Short, Ushort, Wchar,
		     Int, Uint, Dchar, Long, Ulong:
			return false;
		case Float, Double:
			return true;
		case Real:
			throw panic(pt, "PrmitiveType.Real not handled");
		case Void:
			throw panic(pt, "PrmitiveType.Void not handled");
		case Invalid:
			throw panic(pt, "PrmitiveType.Invalid not handled");
		}
	}

	static bool getSigned(ir.PrimitiveType pt)
	{
		final switch (pt.type) with (ir.PrimitiveType.Kind) {
		case Byte, Short, Int, Long:
			return true;
		case Bool, Char, Ubyte, Ushort, Wchar, Uint, Dchar, Ulong,
		     Float, Double:
			return false;
		case Real:
			throw panic(pt, "PrmitiveType.Real not handled");
		case Void:
			throw panic(pt, "PrmitiveType.Void not handled");
		case Invalid:
			throw panic(pt, "PrmitiveType.Invalid not handled");
		}
	}

	static uint getBits(ir.PrimitiveType pt)
	{
		final switch (pt.type) with (ir.PrimitiveType.Kind) {
		case Bool: return 1;
		case Byte, Ubyte, Char: return 8;
		case Short, Ushort, Wchar: return 16;
		case Int, Uint, Dchar, Float: return 32;
		case Long, Ulong, Double: return 64;
		case Real:
			throw panic(pt, "PrmitiveType.Real not handled");
		case Void:
			throw panic(pt, "PrmitiveType.Void not handled");
		case Invalid:
			throw panic(pt, "PrmitiveType.Invalid not handled");
		}
	}

	static LLVMTypeRef makeLLVMType(State state, ir.PrimitiveType pt)
	{
		final switch(pt.type) with (ir.PrimitiveType.Kind) {
		case Bool:
			return LLVMInt1TypeInContext(state.context);
		case Byte, Char, Ubyte:
			return LLVMInt8TypeInContext(state.context);
		case Short, Ushort, Wchar:
			return LLVMInt16TypeInContext(state.context);
		case Int, Uint, Dchar:
			return LLVMInt32TypeInContext(state.context);
		case Long, Ulong:
			return LLVMInt64TypeInContext(state.context);
		case Float:
			return LLVMFloatTypeInContext(state.context);
		case Double:
			return LLVMDoubleTypeInContext(state.context);
		case Real:
			throw panic(pt, "PrmitiveType.Real not handled");
		case Void:
			throw panic(pt, "PrmitiveType.Void not handled");
		case Invalid:
			throw panic(pt, "PrmitiveType.Invalid not handled");
		}
	}
}

/*!
 * PointerType represents a standard C pointer.
 *
 * @ingroup llvmbackend
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

	override void from(State state, ir.Constant cnst, Value result)
	{
		if (!cnst.isNull) {
			throw panic(/*#ref*/cnst.loc, "can only from null pointers.");
		}

		result.type = this;
		result.value = LLVMConstPointerNull(llvmType);
		result.isPointer = false;
	}

private:
	this(State state, ir.PointerType pt, Type base)
	{
		this.base = base;
		if (base.isVoid()) {
			llvmType = LLVMPointerType(
				LLVMInt8TypeInContext(state.context), 0);
		} else {
			llvmType = LLVMPointerType(base.llvmType, 0);
		}
		diType = state.diPointerType(pt, base);
		super(state, pt, llvmType, diType);
	}
}

/*!
 * Array type.
 *
 * @ingroup llvmbackend
 */
class ArrayType : Type
{
public:
	Type base;
	PointerType ptrType;
	PrimitiveType lengthType;

	Type[2] types;

	enum size_t lengthIndex = 0;
	enum size_t ptrIndex = 1;

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

	override void from(State state, ir.Constant cnst, Value result)
	{
		auto strConst = LLVMConstStringInContext(state.context, cast(char[])cnst.arrayData, false);
		auto strGlobal = state.makeAnonGlobalConstant(
			LLVMTypeOf(strConst), strConst);

		LLVMValueRef[2] ind;
		ind[0] = LLVMConstNull(lengthType.llvmType);
		ind[1] = LLVMConstNull(lengthType.llvmType);

		auto strGep = LLVMConstInBoundsGEP(strGlobal, ind[]);

		LLVMValueRef[2] vals;
		vals[lengthIndex] = lengthType.fromNumber(state, cast(long)cnst.arrayData.length);
		vals[ptrIndex] = strGep;

		result.type = this;
		result.value = LLVMConstNamedStruct(llvmType, vals[]);
		result.isPointer = false;
	}

	override void from(State state, ir.ArrayLiteral al, Value result)
	{
		assert(.fromIr(state, al.type) is this);

		LLVMValueRef[] alVals;

		// Handle null.
		if (al.exps.length >= 0) {
			alVals = new LLVMValueRef[](al.exps.length);
			foreach (i, exp; al.exps) {
				alVals[i] = state.getConstant(exp);
			}
		}

		result.type = this;
		result.value = from(state, alVals);
		result.isPointer = false;
	}

	LLVMValueRef from(State state, LLVMValueRef[] arr)
	{
		// Handle null.
		if (arr.length == 0) {
			LLVMValueRef[2] vals;
			vals[lengthIndex] = LLVMConstNull(lengthType.llvmType);
			vals[ptrIndex] = LLVMConstNull(ptrType.llvmType);

			return LLVMConstNamedStruct(llvmType, vals[]);
		}

		auto litConst = LLVMConstArray(base.llvmType, arr);
		auto litGlobal = state.makeAnonGlobalConstant(
			LLVMTypeOf(litConst), litConst);

		LLVMValueRef[2] ind;
		ind[0] = LLVMConstNull(lengthType.llvmType);
		ind[1] = LLVMConstNull(lengthType.llvmType);

		auto strGep = LLVMConstInBoundsGEP(litGlobal, ind[]);

		LLVMValueRef[2] vals;
		vals[lengthIndex] = lengthType.fromNumber(state, cast(long)arr.length);
		vals[ptrIndex] = strGep;

		return LLVMConstNamedStruct(llvmType, vals[]);
	}

private:
	this(State state, ir.ArrayType at)
	{
		diType = diForwardDeclareAggregate(state, at);
		llvmType = LLVMStructCreateNamed(state.context, at.mangledName);
		super(state, at, llvmType, diType);

		// Avoid creating void[] arrays turn them into ubyte[] instead.
		base = .fromIr(state, at.base);
		if (base.isVoid()) {
			base = state.ubyteType;
		}

		auto irPtr = new ir.PointerType(/*#ref*/at.loc, base.irType);
		addMangledName(irPtr);
		ptrType = cast(PointerType) .fromIr(state, irPtr);
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


		version (D_Version2) static assert(ptrIndex > lengthIndex);
		diStructReplace(state, /*#ref*/diType, cast(Type)this,
			[lengthType, ptrType],
			["length", "ptr"]);
	}
}

/*!
 * Static array type.
 *
 * @ingroup llvmbackend
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

	override void from(State state, ir.ArrayLiteral al, Value result)
	{
		assert(.fromIr(state, al.type) is this);

		// Handle null.
		version (none) if (al.exps.length == 0) {
			LLVMValueRef[2] vals;
			vals[lengthIndex] = LLVMConstNull(lengthType.llvmType);
			vals[ptrIndex] = LLVMConstNull(ptrType.llvmType);
			return LLVMConstNamedStruct(llvmType, vals);
		}

		auto alVals = new LLVMValueRef[](al.exps.length);
		foreach (i, exp; al.exps) {
			alVals[i] = state.getConstant(exp);
		}

		result.type = this;
		result.value = LLVMConstArray(base.llvmType, alVals);
		result.isPointer = false;
	}

private:
	this(State state, ir.StaticArrayType sat)
	{
		auto irArray = new ir.ArrayType(/*#ref*/sat.loc, sat.base);
		addMangledName(irArray);
		arrayType = cast(ArrayType) .fromIr(state, irArray);
		base = arrayType.base;
		ptrType = arrayType.ptrType;

		length = cast(uint)sat.length;
		llvmType = LLVMArrayType(base.llvmType, length);
		diType = diStaticArrayType(state, sat, base);
		super(state, sat, llvmType, diType);
	}
}

/*!
 * Base class for callable types FunctionType and DelegateType.
 *
 * @ingroup llvmbackend
 */
abstract class CallableType : Type
{
public:
	Type ret;
	ir.CallableType ct;
	Type[] params;

public:
	this(State state, ir.CallableType ct,
	     LLVMTypeRef llvmType, LLVMMetadataRef diType)
	{
		this.ct = ct;
		super(state, ct, llvmType, diType);
	}
}

/*!
 * Function type.
 *
 * @ingroup llvmbackend
 */
class FunctionType : CallableType
{
public:
	bool hasStructRet;
	LLVMTypeRef llvmCallType;
	LLVMMetadataRef diCallType;

public:
	static FunctionType fromIr(State state, ir.FunctionType ft)
	{
		Type[] params;
		Type ret;

		ret = .fromIr(state, ft.ret);
		params = new Type[](ft.params.length);
		foreach (i, param; ft.params) {
			params[i] = .fromIr(state, param);
		}

		// FunctionPointers can via structs reference themself.
		auto test = state.getTypeNoCreate(ft.mangledName);
		if (test !is null) {
			return cast(FunctionType)test;
		}
		return new FunctionType(state, ft, ret, params);
	}

	override void from(State state, ir.Constant cnst, Value result)
	{
		if (!cnst.isNull) {
			throw panic(/*#ref*/cnst.loc, "can only from null pointers.");
		}

		result.type = this;
		result.value = LLVMConstPointerNull(llvmType);
		result.isPointer = false;
	}

private:
	this(State state, ir.FunctionType ft, Type argRet, Type[] params)
	{
		this.params = params;
		this.ret = argRet;
		LLVMTypeRef[] args;
		Type[] di;

		// For C style returns of structs.
		auto strct = cast(StructType)argRet;
		if (strct !is null && ft.linkage == ir.Linkage.C) {
			auto irStruct = cast(ir.Struct)strct.irType;
			hasStructRet = shouldCUseStructRet(state.target, irStruct);
		}

		if (hasStructRet && ft.hiddenParameter) {
			throw panic("does not support hidden parameter and large struct returns.");
		}

		// Make the arrays that are used as inputs to various calls.
		size_t offset = ft.hiddenParameter || hasStructRet;
		bool voltVariadic = ft.hasVarArgs && ft.linkage == ir.Linkage.Volt;
		size_t argsLength = ft.params.length + offset + (voltVariadic ? 2 : 0);
		args = new typeof(args)(argsLength);
		di = new typeof(di)(argsLength);

		foreach (i, type; params) {
			if (ft.isArgRef[i] ||
			    ft.isArgOut[i] ||
			    type.passByValPtr ||
			    type.passByValAttr) {
				auto irPtr = new ir.PointerType(/*#ref*/type.irType.loc, type.irType);
				addMangledName(irPtr);
				auto ptrType = cast(PointerType) .fromIr(state, irPtr);

				args[i+offset] = ptrType.llvmType;
				di[i+offset] = type;
			} else {
				args[i+offset] = type.llvmType;
				di[i+offset] = type;
			}
		}

		if (voltVariadic) {
			panicAssert(ft, ft.typeInfo !is null);
			auto tinfoClass = ft.typeInfo;
			auto tr = buildTypeReference(/*#ref*/ft.loc, tinfoClass, tinfoClass.name);
			addMangledName(tr);

			auto arrayir = buildArrayType(/*#ref*/ft.loc, tr);
			addMangledName(arrayir);
			auto array = ArrayType.fromIr(state, arrayir);

			auto v = buildVoid(/*#ref*/ft.loc);
			addMangledName(v);
			auto argArrayir = buildArrayType(/*#ref*/ft.loc, v);
			addMangledName(argArrayir);
			auto argArray = ArrayType.fromIr(state, argArrayir);

			args[$ - 2] = array.llvmType;
			di  [$ - 2] = array;
			args[$ - 1] = argArray.llvmType;
			di  [$ - 1] = argArray;
		}

		if (ft.hiddenParameter) {
			args[offset - 1] = state.voidPtrType.llvmType;
			di[offset - 1] = state.voidPtrType;
		}

		// Handle return structs via arguments.
		if (hasStructRet) {
			auto irPtr = new ir.PointerType(/*#ref*/argRet.irType.loc, argRet.irType);
			addMangledName(irPtr);
			auto ptrType = cast(PointerType) .fromIr(state, irPtr);

			args[0] = ptrType.llvmType;
			di[0] = ptrType;
			argRet = state.voidType;
		}

		abiCoerceParameters(state, ft, /*#ref*/argRet.llvmType, /*#ref*/args);

		llvmCallType = LLVMFunctionType(argRet.llvmType, args, ft.hasVarArgs && ft.linkage == ir.Linkage.C);
		llvmType = LLVMPointerType(llvmCallType, 0);
		diType = diFunctionType(state, argRet, di, ft.mangledName, /*#out*/diCallType);
		super(state, ft, llvmType, diType);
	}
}

/*!
 * Delegates are lowered here into a struct with two members.
 *
 * @ingroup llvmbackend
 */
class DelegateType : CallableType
{
public:
	LLVMTypeRef llvmCallPtrType;

	enum uint voidPtrIndex = 0;
	enum uint funcIndex = 1;

public:
	static DelegateType fromIr(State state, ir.DelegateType dgt)
	{
		Type[] params;
		Type ret;

		ret = .fromIr(state, dgt.ret);
		foreach (param; dgt.params) {
			.fromIr(state, param);
		}

		// FunctionPointers can via structs reference themself.
		auto test = state.getTypeNoCreate(dgt.mangledName);
		if (test !is null) {
			return cast(DelegateType)test;
		}
		return new DelegateType(state, dgt);
	}

	override void from(State state, ir.Constant cnst, Value result)
	{
		if (!cnst.isNull) {
			throw panic(/*#ref*/cnst.loc, "can only from null pointers.");
		}
		LLVMValueRef[2] vals;
		auto vptr = LLVMPointerType(LLVMInt8TypeInContext(state.context), 0);
		vals[0] = LLVMConstNull(vptr);
		vals[1] = LLVMConstNull(vptr);

		result.type = this;
		result.value = LLVMConstNamedStruct(llvmType, vals);
		result.isPointer = false;
	}

private:
	this(State state, ir.DelegateType dt)
	{
		diType = diForwardDeclareAggregate(state, dt);
		llvmType = LLVMStructCreateNamed(state.context, dt.mangledName);
		super(state, dt, llvmType, diType);

		auto irFuncType = new ir.FunctionType(dt);
		irFuncType.hiddenParameter = true;

		addMangledName(irFuncType);

		auto funcType = cast(FunctionType) .fromIr(state, irFuncType);

		ret = funcType.ret;
		params = funcType.params;

		assert(funcType !is null);

		llvmCallPtrType = funcType.llvmType;

		LLVMTypeRef[2] mt;
		mt[voidPtrIndex] = state.voidPtrType.llvmType;
		mt[funcIndex] = llvmCallPtrType;

		LLVMStructSetBody(llvmType, mt[], false);

		version (D_Version2) static assert(voidPtrIndex < funcIndex);
		diStructReplace(state, /*#ref*/diType, this,
			[state.voidPtrType, funcType],
			["ptr", "func"]);
	}
}

/*!
 * Backend instance of a @link volta.ir.toplevel.Struct ir.Struct@endlink.
 *
 * @ingroup llvmbackend
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

	override void from(State state, ir.StructLiteral sl, Value result)
	{
		auto vals = new LLVMValueRef[](indices.length);

		if (vals.length != sl.exps.length) {
			throw panic("struct literal has the wrong number of initializers");
		}

		foreach (i, ref val; vals) {
			val = state.getConstant(sl.exps[i]);
		}

		result.type = this;
		result.value = LLVMConstNamedStruct(llvmType, vals);
		result.isPointer = false;
	}

private:
	string getMangled(ir.Struct irType)
	{
		auto c = cast(ir.Class) irType.loweredNode;
		if (c !is null) {
			return c.mangledName;
		}

		auto i = cast(ir._Interface) irType.loweredNode;
		if (i !is null) {
			return i.mangledName;
		}

		return irType.mangledName;
	}

	void createAlias(State state, ir.Struct irType, string mangled)
	{
		auto c = cast(ir.Class) irType.loweredNode;
		if (c !is null) {
			auto ptr = buildPtrSmart(/*#ref*/c.loc, irType);
			addMangledName(ptr);
			addMangledName(ptr.base);

			auto p = .PointerType.fromIr(state, ptr);

			state.addType(p, mangled);
			// This type is now aliased as:
			// pC3foo5Clazz14__layoutStruct
			// C3foo5Clazz
			return;
		}

		auto i = cast(ir._Interface) irType.loweredNode;
		if (i !is null) {
			auto ptr = buildPtrSmart(/*#ref*/i.loc, irType);
			auto ptrptr = buildPtr(/*#ref*/i.loc, ptr);
			addMangledName(ptrptr);
			addMangledName(ptr);
			addMangledName(ptr.base);

			.PointerType.fromIr(state, ptr);
			auto p = .PointerType.fromIr(state, ptrptr);

			state.addType(p, mangled);
			// This type is now aliased as:
			// ppI3foo5Iface14__layoutStruct
			// I3foo5Iface
			return;
		}
	}

	this(State state, ir.Struct irType)
	{
		auto mangled = getMangled(irType);

		diType = diForwardDeclareAggregate(state, irType);
		llvmType = LLVMStructCreateNamed(state.context, mangled);
		super(state, irType, llvmType, diType);

		auto semanticSize = volt.semantic.classify.size(state.target, irType);
		if (state.target.arch == Arch.AArch64) {
			this.passByValPtr = semanticSize > 16;
		} else {
			this.passByValAttr = semanticSize > 16;
			version (LLVMVersion12AndAbove) {
				// Need to have typed byVal enums in 12 and above.
				this.byValTypeAttr = LLVMCreateTypeAttribute(state.context, state.attrByValKind, llvmType);
			}
		}

		createAlias(state, irType, mangled);

		// @todo check packing.
		VariableSink sink;

		foreach (m; irType.members.nodes) {
			if (m.nodeType != ir.NodeType.Variable) {
				continue;
			}
			auto var = m.toVariableFast();
			if (var.storage != ir.Variable.Storage.Field) {
				continue;
			}
			sink.sink(var);
		}

		auto vars = sink.toArray();
		auto mt = new LLVMTypeRef[](vars.length);
		types = new Type[](vars.length);

		foreach (i, var; vars) {
			// @todo handle anon types.
			assert(var.name !is null);

			auto t = .fromIr(state, var.type);
			mt[i] = t.llvmType;
			types[i] = t;
			indices[var.name] = cast(uint)i;
		}

		LLVMStructSetBody(llvmType, mt, false);
		diStructReplace(state, /*#ref*/diType, irType, vars);
	}
}

/*!
 * Backend instance of a @link volta.ir.toplevel.Union ir.Union@endlink.
 *
 * @ingroup llvmbackend
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

	override void from(State state, ir.UnionLiteral ul, Value result)
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
			auto sz = volt.semantic.classify.size(state.target, t.irType);
			if (sz > lastSize) {
				lastExp = ul.exps[i];
				lastSize = sz;
			}
		}

		auto vals = new LLVMValueRef[](1);
		vals[0] = state.getConstant(lastExp);

		result.type = this;
		result.value = LLVMConstNamedStruct(llvmType, vals);
		result.isPointer = false;
	}

private:
	this(State state, ir.Union irType)
	{
		this.llvmType = LLVMStructCreateNamed(state.context, irType.mangledName);
		this.diType = diForwardDeclareAggregate(state, irType);
		this.utype = irType;
		super(state, irType, llvmType, diType);

		VariableSink sink;

		foreach (m; irType.members.nodes) {
			if (m.nodeType != ir.NodeType.Variable) {
				continue;
			}
			auto var = m.toVariableFast();
			if (var.storage != ir.Variable.Storage.Field) {
				continue;
			}
			sink.sink(var);
		}

		auto vars = sink.toArray();
		types = new Type[](vars.length);

		size_t lastSize;
		Type lastType;

		foreach (i, var; vars) {
			// @todo handle anon types.
			assert(var.name !is null);

			auto t = .fromIr(state, var.type);

			types[i] = t;
			indices[var.name] = cast(uint)i;

			auto sz = volt.semantic.classify.size(state.target, t.irType);
			if (sz > lastSize) {
				lastType = t;
				lastSize = sz;
			}
		}

		LLVMTypeRef[1] mt;
		mt[0] = lastType.llvmType;
		// Check over this logic if unions ever explodes.
		// mt[0] = LLVMArrayType(state.ubyteType.llvmType, cast(uint)irType.totalSize);
		LLVMStructSetBody(llvmType, mt[], false);
		diUnionReplace(state, /*#ref*/diType, this, vars);
	}
}

/*!
 * Looks up or creates the corresponding LLVMTypeRef
 * and Type for the given irType.
 *
 * @ingroup llvmbackend
 */
Type fromIr(State state, ir.Type irType)
{
	Type result;

	if (irType.mangledName is null) {
		auto m = addMangledName(irType);
		auto str = format("mangledName not set (%s).", m);
		warning(/*#ref*/irType.loc, str);
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

/*!
 * Dispatcher function to Type constructors.
 *
 * @ingroup llvmbackend
 */
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
	case Interface:
		auto _iface = cast(ir._Interface)irType;
		StructType.fromIr(state, _iface.layoutStruct);
		return state.getTypeNoCreate(_iface.mangledName);
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
		throw panic(/*#ref*/irType.loc, emsg);
	}
}

/*!
 * Populate the common types that hang off the state.
 *
 * @ingroup llvmbackend
 */
void buildCommonTypes(State state, bool V_P64)
{
	auto l = state.irMod.loc;
	auto voidTypeIr = buildVoid(/*#ref*/l);

	auto boolTypeIr = buildBool(/*#ref*/l);
	auto byteTypeIr = buildByte(/*#ref*/l);
	auto ubyteTypeIr = buildUbyte(/*#ref*/l);
	auto intTypeIr = buildInt(/*#ref*/l);
	auto uintTypeIr = buildUint(/*#ref*/l);
	auto ulongTypeIr = buildUlong(/*#ref*/l);

	auto voidPtrTypeIr = buildVoidPtr(/*#ref*/l);
	auto voidFunctionTypeIr = buildFunctionTypeSmart(/*#ref*/l, voidTypeIr);

	auto spingTypeIr = buildFunctionTypeSmart(
		/*#ref*/voidTypeIr.loc, voidTypeIr, voidPtrTypeIr);

	addMangledName(voidTypeIr);

	addMangledName(boolTypeIr);
	addMangledName(byteTypeIr);
	addMangledName(ubyteTypeIr);
	addMangledName(intTypeIr);
	addMangledName(uintTypeIr);
	addMangledName(ulongTypeIr);

	addMangledName(voidPtrTypeIr);
	addMangledName(voidFunctionTypeIr);
	addMangledName(spingTypeIr);

	state.voidType = cast(VoidType)state.fromIr(voidTypeIr);

	state.boolType = cast(PrimitiveType)state.fromIr(boolTypeIr);
	state.byteType = cast(PrimitiveType)state.fromIr(byteTypeIr);
	state.ubyteType = cast(PrimitiveType)state.fromIr(ubyteTypeIr);
	state.intType = cast(PrimitiveType)state.fromIr(intTypeIr);
	state.uintType = cast(PrimitiveType)state.fromIr(uintTypeIr);
	state.ulongType = cast(PrimitiveType)state.fromIr(ulongTypeIr);

	state.voidPtrType = cast(PointerType)state.fromIr(voidPtrTypeIr);
	state.voidFunctionType = cast(FunctionType)state.fromIr(voidFunctionTypeIr);
	state.springType = cast(FunctionType)state.fromIr(spingTypeIr);

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
	assert(state.springType !is null);
}

/*!
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
		pt.loc = asPt.loc;
		outType = pt;
		break;
	case PointerType:
		auto asPt = cast(ir.PointerType)type;
		auto pt = new ir.PointerType();
		pt.loc = asPt.loc;
		pt.base = scrubStorage(asPt.base);
		outType = pt;
		break;
	case ArrayType:
		auto asAt = cast(ir.ArrayType)type;
		auto at = new ir.ArrayType();
		at.loc = asAt.loc;
		at.base = scrubStorage(asAt.base);
		outType = at;
		break;
	case StaticArrayType:
		auto asSat = cast(ir.StaticArrayType)type;
		auto sat = new ir.StaticArrayType();
		sat.loc = asSat.loc;
		sat.base = scrubStorage(asSat.base);
		sat.length = asSat.length;
		outType = sat;
		break;
	case AAType:
		auto asAA = cast(ir.AAType)type;
		auto aa = new ir.AAType();
		aa.loc = asAA.loc;
		aa.value = scrubStorage(asAA.value);
		aa.key = scrubStorage(asAA.key);
		outType = aa;
		break;
	case FunctionType:
		auto asFt = cast(ir.FunctionType)type;
		auto ft = new ir.FunctionType(asFt);
		ft.loc = asFt.loc;
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
		auto dgt = new ir.DelegateType(asDg);
		dgt.loc = asDg.loc;
		dgt.ret = scrubStorage(dgt.ret);
		foreach (i, ref t; dgt.params) {
			t = scrubStorage(t);
		}
		// TODO a better fix for this.
		dgt.isConst = false;
		dgt.isScope = false;
		dgt.isImmutable = false;
		outType = dgt;
		break;
	case TypeReference:
		auto asTr = cast(ir.TypeReference)type;
		if (cast(ir.Aggregate)asTr.type is null) {
			outType = scrubStorage(asTr.type);
			break;
		}
		auto tr = new ir.TypeReference();
		tr.type = asTr.type;
		tr.loc = asTr.loc;
		tr.type = asTr.type;
		outType = tr;
		break;
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

/*!
 * Helper function for adding mangled name to ir types.
 */
string addMangledName(ir.Type irType)
{
	string m = volt.semantic.mangle.mangle(irType);
	irType.mangledName = m;
	return m;
}

/*!
 * Helper function to tell if a type is Void.
 */
bool isVoid(Type type)
{
	return cast(VoidType)type !is null;
}
