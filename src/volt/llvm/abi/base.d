/*#D*/
// Copyright © 2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Perform ABI modifications to functions and function calls, if needed.
 *
 * This layer dispatches to the appropriate platform specific function.
 */
module volt.llvm.abi.base;

import lib.llvm.core;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.semantic.classify : calcAlignment;
import volt.llvm.interfaces;
import volt.llvm.type;
import volt.llvm.abi.sysvamd64;
import volt.llvm.abi.winamd64;

/*!
 * If the target platform and this function needs it, modify to match the ABI.
 *
 * If we're running on a target that needs to modify functions in someway,
 * and `ft` matches those functions, modify `params` as needed.
 */
void abiCoerceParameters(State state, ir.FunctionType ft, ref LLVMTypeRef retType, ref LLVMTypeRef[] params)
{
	if (ft.linkage != ir.Linkage.C) {
		return;
	}

	if (state.target.arch == Arch.X86) {
		return;  // TODO: 32 bit
	} else if (state.target.arch == Arch.X86_64) {
		if (state.target.platform == Platform.Linux || state.target.platform == Platform.OSX) {
			return sysvAmd64AbiCoerceParameters(state, ft, /*#ref*/retType, /*#ref*/params);
		} else if (state.target.platform == Platform.MinGW || state.target.platform == Platform.MSVC) {
			return winAmd64AbiCoerceParameters(state, ft, /*#ref*/retType, /*#ref*/params);
		}
	}
}

/*!
 * If the parameters for the given function were modified, modify the call to match.
 */
void abiCoerceArguments(State state, ir.CallableType ct, ref LLVMValueRef[] params)
{
	if (ct is null || !ct.abiModified) {
		return;
	}

	if (state.target.arch == Arch.X86) {
		return;  // TODO: 32 bit
	} else if (state.target.arch == Arch.X86_64) {
		if (state.target.platform == Platform.Linux || state.target.platform == Platform.OSX) {
			return sysvAmd64AbiCoerceArguments(state, ct, /*#ref*/params);
		} else if (state.target.platform == Platform.MinGW || state.target.platform == Platform.MSVC) {
			return winAmd64AbiCoerceArguments(state, ct, /*#ref*/params);
		}
	}
}

alias CoercedStatus = bool;
enum NotCoerced = false;
enum Coerced = true;

/*!
 * Coerce the prologue section of the function.
 *
 * The prologue is at the top, where parameters are assigned into locals.  
 * This function is a little less 'set and forget' than the other two
 * coerce functions; it needs to be called in the loop, and an index
 * variable needs to be used in your parameter lookups.  
 * The reason is that removing generated code is fragile (as that code
 * could change, and someone might not be aware that this function relies
 * on the output) and more complicated than modifying a list of LLVMValues
 * or LLVMTypes.
 *
 * This is intended to be called where the simple `LLVMBuildStore` would go
 * in the prologue generation.
 *
 * @Param state The State instance, to access the builder and context.
 * @Param llvmFunc The LLVM function that we are modifying. 
 * @Param func The IR function that we are modifying.
 * @Param ct The `CallableType` with `abiData` on it.
 * @Param val The `LLVMValueRef` retrieved from `LLVMGetParam`.
 * @Param index The index of the `for` loop -- which parameter we're looking
 * at, not counting `offset`.
 * @Param offset Start with a `size_t` initialised
 * to `0`, and add it to your `LLVMGetParam` call. (This is so we can insert
 * parameters without having to modify every list of parameters that exist
 * in the IR).
 * @Returns `true` if something was coerced and no further action should be
 * taken on this parameter. If `false`, caller should call the `LLVMBuildStore`
 * path that is usually taken.
 */
CoercedStatus abiCoercePrologueParameter(State state, LLVMValueRef llvmFunc, ir.Function func,
	ir.CallableType ct, LLVMValueRef val, size_t index, ref size_t offset)
{
	if (ct is null || !ct.abiModified) {
		return NotCoerced;
	}
	if (state.target.arch == Arch.X86) {
		return NotCoerced;  // TODO: 32 bit windows
	} else if (state.target.arch == Arch.X86_64) {
		if (state.target.platform == Platform.Linux || state.target.platform == Platform.OSX) {
			return sysvAmd64AbiCoercePrologueParameter(state, llvmFunc, func, ct, val, index, /*#ref*/offset);
		} else if (state.target.platform == Platform.MinGW || state.target.platform == Platform.MSVC) {
			return winAmd64AbiPrologueParameter(state, llvmFunc, func, ct, val, index, /*#ref*/offset);
		}
	}
	return NotCoerced;
}

LLVMValueRef buildGep(State state, LLVMValueRef ptr, ulong a, ulong b)
{
	auto indices = new LLVMValueRef[](2);
	auto _i32 = LLVMInt32TypeInContext(state.context);
	indices[0] = LLVMConstInt(_i32, a, false);
	indices[1] = LLVMConstInt(_i32, b, false);
	return LLVMBuildGEP(state.builder, ptr, indices.ptr, 2, "".ptr);
}
