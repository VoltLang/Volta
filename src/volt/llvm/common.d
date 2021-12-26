/*#D*/
// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Common code generation code.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.common;

import volta.ir.location;

import volta.util.util;
import ir = volta.ir;
import volt.interfaces;
import volt.llvm.interfaces;
import volt.semantic.classify;


/*!
 * Returns true if the C calling convention returns structs via arguments.
 */
bool shouldCUseStructRet(TargetInfo target, ir.Struct irStruct)
{
	size_t structSize = size(target, irStruct);

	final switch (target.platform) with (Platform) {
	case Metal:
	case Linux:
		final switch (target.arch) with (Arch) {
		case X86:
			return true;
		case X86_64:
			return structSize > 16;
		case ARMHF:
		case AArch64:
			// !?!?!
			return structSize > 16;
		}
	case OSX:
		final switch (target.arch) with (Arch) {
		case X86:
			return structSize != 4 && structSize != 8;
		case X86_64:
			return structSize > 16;
		case ARMHF: assert(false);
		case AArch64:
			// !?!?!
			return structSize > 16;
		}
	case MSVC:
	case MinGW:
		final switch (target.arch) with (Arch) {
		case X86:
		case X86_64:
			return structSize != 4 && structSize != 8;
		case ARMHF: assert(false);
		case AArch64: assert(false);
		}
	}

}

/*!
 * Turns a ArrayType Value into a Pointer Value. Value must be
 * of type ArrayType.
 */
void getPointerFromArray(State state, ref in Location loc, Value result)
{
	auto at = cast(ArrayType)result.type;
	assert(at !is null);

	getFieldFromAggregate(
		state, /*#ref*/loc, result, ArrayType.ptrIndex, at.ptrType, result);
}

/*!
 * Turns a StaticArrayType Value into a Pointer Value. Value must be
 * of type StaticArrayType.
 */
void getPointerFromStaticArray(State state, ref in Location loc, Value result)
{
	auto sat = cast(StaticArrayType)result.type;
	assert(sat !is null);
	assert(result.isPointer);

	result.value = LLVMBuildStructGEP(state.builder, result.value, 0, "");
	result.isPointer = false;
	result.type = sat.ptrType;
}

/*!
 * Turns a StaticArrayType Value into a Array Value. Value must be
 * of type StaticArrayType.
 */
void getArrayFromStaticArray(State state, ref in Location loc, Value result)
{
	auto sat = cast(StaticArrayType)result.type;
	assert(sat !is null);
	auto at = sat.arrayType;

	getPointerFromStaticArray(state, /*#ref*/loc, result);
	auto srcPtr = result.value;
	auto srcLen = LLVMConstInt(state.sizeType.llvmType, sat.length, false);

	makeArrayValue(state, loc, at, srcPtr, srcLen, result);
}

/*!
 * Return the field from a aggregate at the given index.
 *
 * Sets the type of result to the given type.
 */
void getFieldFromAggregate(State state, ref in Location loc, Value left,
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

/*!
 * Returns a member of aggregate type in value form.
 * Note only value form.
 */
LLVMValueRef getValueFromAggregate(State state, ref in Location loc,
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

void makeArrayValue(State state, Location loc, ArrayType at,
                    LLVMValueRef ptr, LLVMValueRef len,
                    Value result)
{
	auto v = LLVMGetUndef(at.llvmType);
	v = LLVMBuildInsertValue(state.builder, v, ptr,
		ArrayType.ptrIndex, "");
	v = LLVMBuildInsertValue(state.builder, v, len,
		ArrayType.lengthIndex, "");

	result.value = v;
	result.isPointer = false;
	result.type = at;
}

void makeDelegateValue(State state, ref in Location loc, DelegateType dt,
                       LLVMValueRef voidPtr, LLVMValueRef funcPtr,
                       Value result)
{
	auto v = LLVMGetUndef(dt.llvmType);
	v = LLVMBuildInsertValue(state.builder, v, funcPtr,
		DelegateType.funcIndex, "");
	v = LLVMBuildInsertValue(state.builder, v, voidPtr,
		DelegateType.voidPtrIndex, "");

	result.value = v;
	result.isPointer = false;
	result.type = dt;
}

/*!
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
	sl.loc = cl.loc;
	sl.type = copyTypeSmart(/*#ref*/_class.loc, _class.layoutStruct);
	auto eref = buildExpReference(/*#ref*/cl.loc, _class.vtableVariable, _class.vtableVariable.name);
	auto ppv = buildPtr(/*#ref*/cl.loc, buildVoidPtr(/*#ref*/cl.loc));
	ppv.mangledName = "ppv";
	sl.exps ~= buildCast(/*#ref*/cl.loc, ppv, buildAddrOf(/*#ref*/cl.loc, eref));
	sl.exps ~= cl.exps;

	st.from(state, sl, result);

	if (!cl.useBaseStorage) {
		result.isPointer = false;
		result.type = pt;
		result.value = state.makeAnonGlobalConstant(
			st.llvmType, result.value);
	}
}
/*!
 * @}
 */
