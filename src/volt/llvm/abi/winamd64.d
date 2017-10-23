/*#D*/
/*!
 * Windows AMD64 ABI Implementation.
 *
 * If an aggregate being passed by value is 8, 16, 32, or 64 bits in size,
 * then it is passed as an integer of that size.
 *
 * Otherwise, it is passed as a pointer to that struct.
 */
module volt.llvm.abi.winamd64;

import lib.llvm.core;

import ir = volt.ir.ir;

import volt.llvm.abi.base;
import volt.llvm.interfaces;

void winAmd64AbiCoerceParameters(State state, ir.FunctionType ft, ref LLVMTypeRef retType, ref LLVMTypeRef[] params)
{
	LLVMTypeRef[] types;
	foreach (i, param; params) {
		auto kind = LLVMGetTypeKind(param);
		if (kind == LLVMTypeKind.Struct) {
			auto newT = processStructParameter(state, ft, i, param);
			ft.abiData ~= cast(void*[])[newT];
			types ~= newT;
		} else {
			ft.abiData ~= cast(void*[])null;
			types ~= param;
		}
	}
	params = types;
}

void winAmd64AbiCoerceArguments(State state, ir.CallableType ct, ref LLVMValueRef[] args)
{
	for (size_t i = 0; i < args.length; ++i) {
		if (ct.abiData[i].length != 1) {
			continue;
		}
		// We need a pointer. If it is a value, alloca and store.
		if (LLVMGetTypeKind(LLVMTypeOf(args[i])) != LLVMTypeKind.Pointer) {
			auto _alloca = state.buildAlloca(LLVMTypeOf(args[i]), "");
			LLVMBuildStore(state.builder, args[i], _alloca);
			args[i] = _alloca;
		}
		if (ct.abiData[i].length == 1) {
			auto lt = cast(LLVMTypeRef[])ct.abiData[i];
			if (LLVMGetTypeKind(lt[0]) == LLVMTypeKind.Pointer) {
				auto base = LLVMGetElementType(lt[0]);
				auto _alloca = state.buildAlloca(base, "agg.tmp");
				buildMemcpy(state, _alloca, args[i], base);
				args[i] = _alloca;
			} else {
				auto bc = LLVMBuildBitCast(state.builder, args[i],
					LLVMPointerType(lt[0], 0), "");
				args[i] = LLVMBuildLoad(state.builder, bc, "");
			}
		}
	}
}

CoercedStatus winAmd64AbiPrologueParameter(State state, LLVMValueRef llvmFunc, ir.Function func,
	ir.CallableType ct, LLVMValueRef val, size_t index, ref size_t offset)
{
	if (ct.abiData[index+offset].length != 1) {
		return NotCoerced;
	}
	auto p = func.params[index];
	auto lts = cast(LLVMTypeRef[])ct.abiData[index+offset];
	if (LLVMGetTypeKind(lts[0]) != LLVMTypeKind.Pointer) {
		auto type = state.fromIr(p.type);
		auto a = state.getVariableValue(p, /*#out*/type);
		auto bc = LLVMBuildBitCast(state.builder, a, LLVMPointerType(lts[0], 0), "");
		LLVMBuildStore(state.builder, val, bc);
		return Coerced;
	} else {
		state.makeByValVariable(p, LLVMGetParam(llvmFunc, cast(uint)(index+offset)));
		return Coerced;
	}
}

private:

void buildMemcpy(State state, LLVMValueRef dst, LLVMValueRef src, LLVMTypeRef base)
{
	Type memcpyType;
	auto func = state.getFunctionValue(state.lp.llvmMemcpy64, /*#out*/memcpyType);
	LLVMValueRef[] args;
	auto voidPtr = LLVMPointerType(LLVMInt8TypeInContext(state.context), 0);
	args ~= LLVMBuildBitCast(state.builder, dst, voidPtr, "");
	args ~= LLVMBuildBitCast(state.builder, src, voidPtr, "");
	args ~= LLVMSizeOf(base);
	args ~= LLVMConstInt(LLVMInt32TypeInContext(state.context), 1, false);
	args ~= LLVMConstInt(LLVMInt1TypeInContext(state.context), 0, false);
	LLVMBuildCall(state.builder, func, args.ptr, cast(uint)args.length, "".ptr);
}

LLVMTypeRef processStructParameter(State state, ir.FunctionType ft, size_t i, LLVMTypeRef structType)
{
	ft.abiModified = true;
	auto sz = structSizeInBits(structType);
	switch (sz) {
	case 8, 16, 32, 64:
		return LLVMIntTypeInContext(state.context, cast(uint)sz);
	default:
		return LLVMPointerType(structType, 0);
	}
}

/* Get the struct size in bits. May return 0 if contains element we can't size.
 * Not great for general purposes, but we only care if it's 8, 16, 32, or 64
 * exactly.
 */
size_t structSizeInBits(LLVMTypeRef type)
{
	size_t accum;
	structSizeInBits(type, /*#ref*/accum);
	return accum;
}

void structSizeInBits(LLVMTypeRef type, ref size_t accum)
{
	auto elements = new LLVMTypeRef[](LLVMCountStructElementTypes(type));
	LLVMGetStructElementTypes(type, elements.ptr);
	foreach (element; elements) {
		typeSizeInBits(element, /*#ref*/accum);
	}
}

void typeSizeInBits(LLVMTypeRef element, ref size_t accum)
{
	LLVMTypeKind ekind = LLVMGetTypeKind(element);
	final switch(ekind) with (LLVMTypeKind) {
	case Void, Half, X86_FP80, FP128, PPC_FP128, Label,
		Function, Vector, Metadata, X86_MMX, Token:
		accum = 0;
		return;
	case Array:
		auto len = LLVMGetArrayLength(element);
		auto base = LLVMGetElementType(element);
		size_t subAccum;
		typeSizeInBits(base, /*#ref*/subAccum);
		accum += (subAccum * len);
		break;
	case Float:
		accum += 32;
		break;
	case Double:
		accum += 64;
		break;
	case Integer:
		auto width = LLVMGetIntTypeWidth(element);
		accum += width;
		break;
	case Pointer:
		accum += 64;
		break;
	case Struct:
		structSizeInBits(element, /*#ref*/accum);
		break;
	}
}
