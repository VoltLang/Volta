// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.aggregate;

import volt.token.location;

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
                           int index, Type resultType, Value result)
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
                                   Value left, int index)
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
	static assert(ArrayType.ptrIndex == 0);
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
	static assert(DelegateType.voidPtrIndex == 0);
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

	foreach (int i, member; members) {
		auto dst = LLVMBuildStructGEP(state.builder, v, i, "");
		LLVMBuildStore(state.builder, member, dst);
	}
}
