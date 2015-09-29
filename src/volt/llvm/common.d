// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.common;

import volt.token.location;

import volt.ir.util;
import volt.llvm.interfaces;


/**
 * Turns a ArrayType Value into a Pointer Value. Value must be
 * of type ArrayType.
 */
void getPointerFromArray(State state, Location loc, Value result)
{
	auto at = cast(ArrayType)result.type;
	assert(at !is null);

	getFieldFromAggregate(
		state, loc, result, ArrayType.ptrIndex, at.ptrType, result);
}

/**
 * Turns a StaticArrayType Value into a Pointer Value. Value must be
 * of type StaticArrayType.
 */
void getPointerFromStaticArray(State state, Location loc, Value result)
{
	auto sat = cast(StaticArrayType)result.type;
	assert(sat !is null);
	assert(result.isPointer);

	result.value = LLVMBuildStructGEP(state.builder, result.value, 0, "");
	result.isPointer = false;
	result.type = sat.ptrType;
}

/**
 * Turns a StaticArrayType Value into a Array Value. Value must be
 * of type StaticArrayType.
 */
void getArrayFromStaticArray(State state, Location loc, Value result)
{
	auto sat = cast(StaticArrayType)result.type;
	assert(sat !is null);
	auto at = sat.arrayType;

	getPointerFromStaticArray(state, loc, result);
	auto srcPtr = result.value;
	auto srcLen = LLVMConstInt(state.sizeType.llvmType, sat.length, false);

	makeArrayTemp(state, loc, at, srcPtr, srcLen, result);
}

/**
 * Return the field from a aggregate at the given index.
 *
 * Sets the type of result to the given type.
 */
void getFieldFromAggregate(State state, Location loc, Value left,
                           uint index, Type resultType, Value result)
{
	auto type = left.type;
	auto v = left.value;

	assert(cast(ArrayType)type !is null ||
	       cast(StructType)type !is null ||
	       cast(DelegateType)type !is null);

	if (left.isPointer) {
		v = LLVMBuildStructGEP(state.builder, v, index, "");
	} else {
		v = LLVMBuildExtractValue(state.builder, v, index, "");
	}

	result.value = v;
	result.type = resultType;
	result.isPointer = left.isPointer;
}

/**
 * Returns a member of aggregate type in value form.
 * Note only value form.
 */
LLVMValueRef getValueFromAggregate(State state, Location loc,
                                   Value left, uint index)
{
	auto type = left.type;
	auto v = left.value;

	assert(cast(ArrayType)type !is null ||
	       cast(StructType)type !is null ||
	       cast(DelegateType)type !is null);

	if (left.isPointer) {
		auto ptr = LLVMBuildStructGEP(state.builder, v, index, "");
		return LLVMBuildLoad(state.builder, ptr, "");
	} else {
		return LLVMBuildExtractValue(state.builder, v, index, "");
	}
}

/**
 * Creates a temporary delegate with alloca.
 */
void makeArrayTemp(State state, Location loc, ArrayType at,
                   LLVMValueRef ptr, LLVMValueRef len,
                   Value result)
{
	version (D_Version2) static assert(ArrayType.ptrIndex == 0);
	makeStructTemp(state, loc, at, "arrayTemp",
	               [ptr, len], result);
}

/**
 * Creates a temporary delegate with alloca.
 */
void makeDelegateTemp(State state, Location loc, DelegateType dt,
                      LLVMValueRef voidPtr, LLVMValueRef funcPtr,
                      Value result)
{
	version (D_Version2) static assert(DelegateType.voidPtrIndex == 0);
	makeStructTemp(state, loc, dt, "delegateTemp",
	               [voidPtr, funcPtr], result);
}

/**
 * Creates a temporary allocation from a struct based type.
 * StructType, DelegateType and ArrayType can use this function.
 */
void makeStructTemp(State state, Location loc,
                    Type type, string name,
                    LLVMValueRef[] members,
                    Value result)
{
	assert(cast(ArrayType)type !is null ||
	       cast(StructType)type !is null ||
	       cast(DelegateType)type !is null);

	auto v = LLVMBuildAlloca(state.builder, type.llvmType, name);
	result.value = v;
	result.isPointer = true;
	result.type = type;

	foreach (i, member; members) {
		auto dst = LLVMBuildStructGEP(state.builder, v, cast(uint)i, "");
		LLVMBuildStore(state.builder, member, dst);
	}
}

/**
 * Common handle functions for both inline and constants.
 *
 * All of the error checking should have been done in other passes and
 * unimplemented features is checked for in the called functions.
 * @{
 */
void handleConstant(State state, ir.Constant asConst, Value result)
{
	auto type = state.fromIr(asConst.type);
	type.from(state, asConst, result);
}

void handleArrayLiteral(State state, ir.ArrayLiteral al, Value result)
{
	auto type = state.fromIr(al.type);
	type.from(state, al, result);
}

void handleStructLiteral(State state, ir.StructLiteral sl, Value result)
{
	auto type = state.fromIr(sl.type);
	type.from(state, sl, result);
}

void handleUnionLiteral(State state, ir.UnionLiteral ul, Value result)
{
	auto type = state.fromIr(ul.type);
	type.from(state, ul, result);
}

void handleClassLiteral(State state, ir.ClassLiteral cl, Value result)
{
	auto tr = cast(ir.TypeReference)cl.type;
	assert(tr !is null);

	auto _class = cast(ir.Class)tr.type;
	assert(_class !is null);

	auto pt = cast(PointerType)state.fromIr(_class);
	assert(pt !is null);

	auto st = cast(StructType)pt.base;
	assert(st !is null);

	auto sl = new ir.StructLiteral();
	sl.location = cl.location;
	sl.type = copyTypeSmart(_class.location, _class.layoutStruct);
	auto eref = buildExpReference(cl.location, _class.vtableVariable, _class.vtableVariable.name);
	sl.exps ~= buildAddrOf(cl.location, eref);
	sl.exps ~= cl.exps;

	st.from(state, sl, result);

	if (!cl.useBaseStorage) {
		result.isPointer = false;
		result.type = pt;
		result.value = state.makeAnonGlobalConstant(
			st.llvmType, result.value);
	}
}
/**
 * @}
 */
